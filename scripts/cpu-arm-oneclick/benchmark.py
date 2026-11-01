"""TDengine-only CPU benchmark for the prepared Linux ARM64 environment (Python 3.9+)."""
import argparse
import datetime
import fcntl
import hashlib
import html
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import threading
import time

from native import B, HOST, PORT, td_query
from source_stats import METRICS, source_stats

TYPES=['single-groupby-1-1-1','single-groupby-1-1-12','single-groupby-1-8-1',
       'single-groupby-5-1-1','single-groupby-5-1-12','single-groupby-5-8-1',
       'cpu-max-all-1','cpu-max-all-8','double-groupby-1','double-groupby-5',
       'double-groupby-all','high-cpu-1','high-cpu-all','groupby-orderby-limit','lastpoint']
CACHE=B/'cpu-oneclick-cache'
BIN=Path(os.environ.get('TSBS_BIN_DIR',str(B/'bin'))).resolve()

def dump(path,value):
    temp=path.with_suffix(path.suffix+'.tmp')
    temp.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
    temp.replace(path)

def sha(path):
    digest=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(4*1024*1024),b''):digest.update(chunk)
    return digest.hexdigest()

def owned(pidfile,args):
    if not pidfile.exists():return None
    pid=int(pidfile.read_text())
    try:
        if Path('/proc/%d/stat'%pid).read_text().split()[2]=='Z':return None
        exe=os.readlink('/proc/%d/exe'%pid)
        cmd=Path('/proc/%d/cmdline'%pid).read_bytes().split(b'\0')
    except FileNotFoundError:return None
    if exe!=args[0] or not all(arg.encode() in cmd for arg in args):
        raise RuntimeError('PID identity mismatch: '+str(pidfile))
    return pid

def source_revision():
    try:
        return subprocess.check_output(['git','-C',str(Path(__file__).resolve().parents[2]),'rev-parse','HEAD'],text=True,stderr=subprocess.DEVNULL).strip()
    except (OSError,subprocess.CalledProcessError):
        return 'unknown (no git metadata)'

def validate_server_version(version,expected):
    versions=re.findall(r'(?<![\d.])\d+\.\d+\.\d+\.\d+(?!\d|\.\d)',str(version))
    if expected not in versions or 'enterprise' not in str(version).lower():
        raise RuntimeError('Unexpected server version: '+str(version))

def prepare_service(root,summary):
    server=Path(os.environ.get('TSBS_TAOSD_BIN',str(B/'source/tdengine-tsdb-enterprise-3.4.3.7/bin/taosd'))).resolve()
    args=[str(server),'-c',str(B/'config')]
    pid=owned(B/'taosd.pid',args)
    if not pid:
        with (root/'server-console.log').open('ab') as log:
            proc=subprocess.Popen(args,stdout=log,stderr=log,stdin=subprocess.DEVNULL,start_new_session=True)
        (B/'taosd.pid').write_text(str(proc.pid));pid=proc.pid
    deadline=time.monotonic()+600
    while True:
        if not owned(B/'taosd.pid',args):raise RuntimeError('TDengine exited')
        try:
            nodes=td_query('','show dnodes')
            if nodes and all(n['status']=='ready' for n in nodes):break
        except RuntimeError:pass
        if time.monotonic()>deadline:raise RuntimeError('dnode readiness timeout')
        time.sleep(1)
    version=td_query('','select server_version()')
    expected=os.environ.get('TSBS_EXPECTED_VERSION','3.4.3.7')
    validate_server_version(version,expected)
    summary['environment']=dict(machine=platform.machine(),page_bytes=os.sysconf('SC_PAGE_SIZE'),
        server_version=version,expected_version=expected,server_sha256=sha(server),dnodes=nodes,
        package_preparation=json.loads((B/'package-preparation.json').read_text()) if (B/'package-preparation.json').exists() else None,
        binary_sha256={name:sha(BIN/name) for name in ['tsbs_generate_data','tsbs_generate_queries','tsbs_load_tdenginestmt2','tsbs_run_queries_tdengine']},
        taos_config=(B/'config/taos.cfg').read_text(),
        handoff_script_sha256={p.name:sha(p) for p in Path(__file__).resolve().parent.iterdir() if p.suffix in {'.py','.sh'}},
        tsbs_source_revision=source_revision())
    return pid

def prepare_data(run,regenerate):
    if (CACHE/'manifest.json').exists() and not regenerate:
        manifest=json.loads((CACHE/'manifest.json').read_text())
        print('VERIFY cached inputs',flush=True)
        for name,digest in manifest['sha256'].items():
            if sha(CACHE/name)!=digest:raise RuntimeError('Cached input hash mismatch: '+name)
        return manifest
    if CACHE.exists():
        CACHE.rename(B/('cpu-oneclick-cache-preserved-'+str(time.time_ns())))
    CACHE.mkdir()
    manifest=dict(seed=123,datasets={},sha256={})
    for label,scale,interval,end,rows in [('write',100000,'10s','2016-01-01T00:16:40Z',10000000),
                                         ('query',4000,'30s','2016-01-02T00:00:00Z',11520000)]:
        print('GENERATE',label,flush=True)
        original=CACHE/(label+'.stmt2')
        rec=run([str(BIN/'tsbs_generate_data'),'--use-case=cpu-only','--format=TDengineStmt2',
                 '--scale='+str(scale),'--seed=123','--log-interval='+interval,
                 '--timestamp-start=2016-01-01T00:00:00Z','--timestamp-end='+end],label+'-generate',output=original)
        started=time.monotonic();stats=source_stats(original)
        if stats['rows']!=rows or stats['devices']!=scale:raise RuntimeError('source dimensions differ')
        ddls=[]
        with original.open('rb') as source,(CACHE/(label+'-insert-only.stmt2')).open('wb') as target:
            header=source.read(6)
            if header[:2]!=b'\x01\x01':raise RuntimeError('invalid source header')
            target.write(header)
            while True:
                prefix=source.read(1)
                if not prefix:break
                size=prefix[0]
                if size&128:
                    prefix+=source.read(1);size=(size&127)|(prefix[1]<<7)
                record=source.read(size)
                if len(record)!=size:raise RuntimeError('truncated source')
                if record[0]==1:ddls.append(record[6:].decode())
                elif record[0]==2:target.write(prefix+record)
                else:raise RuntimeError('unexpected source record')
        if len(ddls)!=scale:raise RuntimeError('child table count differs')
        (CACHE/(label+'-tables.sql')).write_text(';\n'.join('create table'+''.join(ddls[i:i+500]) for i in range(0,len(ddls),500))+';\n')
        if source_stats(CACHE/(label+'-insert-only.stmt2'))!=stats:raise RuntimeError('DDL split changed input data')
        manifest['datasets'][label]=dict(source=stats,generation_seconds=rec['wall_seconds'],validation_and_split_seconds=time.monotonic()-started)
    for qt in TYPES:
        run([str(BIN/'tsbs_generate_queries'),'--use-case=cpu-only','--format=TDengine','--scale=4000',
             '--seed=123','--queries=10','--query-type='+qt,'--timestamp-start=2016-01-01T00:00:00Z',
             '--timestamp-end=2016-01-02T00:00:00Z'],qt+'-generate',output=CACHE/(qt+'.gob'))
        with (CACHE/(qt+'.gob')).open('rb') as source:
            decoded=subprocess.check_output([str(BIN/'decode_queries')],stdin=source)
        if len(decoded.splitlines())!=10:raise RuntimeError('query sample count differs')
        (CACHE/(qt+'-sql.jsonl')).write_bytes(decoded)
    for path in CACHE.iterdir():manifest['sha256'][path.name]=sha(path)
    dump(CACHE/'manifest.json',manifest)
    return manifest

def report(root,summary):
    writes=[x for x in summary['loads'] if x['label']=='write']
    rows=[]
    for x in writes:rows.append(f"<tr><td>{x['name']}</td><td>{x['internal_seconds']:.3f}</td><td>{x['metrics_per_second']:,.2f}</td><td>{x['metrics_per_second']/10:,.2f}</td><td>{x['wall_seconds']:.3f}</td></tr>")
    query_rows=[]
    for q in summary['queries']:
        query_rows.append('<tr><td>'+html.escape(q['type'])+'</td>'+''.join('<td>'+str(q[k])+'</td>' for k in ['count','min_ms','median_ms','mean_ms','max_ms'])+'</tr>')
    rate=statistics.median(x['metrics_per_second'] for x in writes) if writes else 0
    actual_version=summary.get('environment',{}).get('server_version','未连接服务器')
    page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>TDengine CPU ARM 实测报告</title>
<style>body{{margin:0;background:#f3f6fa;color:#19334a;font:16px/1.8 system-ui}}main{{max-width:1100px;margin:auto;padding:24px}}section,header{{padding:24px;background:white;border-radius:12px;margin:20px 0}}header{{background:#17324f;color:white}}.scroll{{overflow:auto}}table{{border-collapse:collapse;width:100%;white-space:nowrap}}td,th{{padding:10px;border-bottom:1px solid #ddd;text-align:right}}td:first-child,th:first-child{{text-align:left}}pre{{font:12px/1.5 monospace;white-space:pre-wrap;overflow-wrap:anywhere;max-height:500px;overflow:auto}}summary{{cursor:pointer;overflow-wrap:anywhere}}.big{{font-size:30px;font-weight:bold}}@media(max-width:600px){{main{{padding:12px}}section,header{{padding:16px}}}}</style><main>
<header><h1>TDengine CPU ARM 实测报告</h1><p>实际版本：{html.escape(str(actual_version))}</p><p>{html.escape(root.name)} · 状态：{summary['status']}</p></header>
<section><div class="big">{rate:,.2f} 指标值/秒</div><p>三轮内部吞吐中位数，{rate/10:,.2f} 行/秒。</p><p>写入：100,000 设备 × 100 点 × 10 指标，每轮 1,000 万行。8 workers / batch 1,000 / vgroups 8 / replica 1 / WAL=2 / fsync=3,000ms。</p><p>内部计时排除启动、worker 初始化、建库建表，包含扫描、组批、传输与响应等待。异步 fsync 成功响应不等于逐条同步落盘。外部总墙钟另列。</p></section>
<section class="scroll"><h2>写入结果</h2><table><tr><th>轮次</th><th>内部秒</th><th>指标值/秒</th><th>行/秒</th><th>外部秒</th></tr>{''.join(rows)}</table></section>
<section class="scroll"><h2>查询结果（ms）</h2><p>scale=4,000，共 1,152 万行；15 类各 10 条，1 worker，不预热、不清缓存。10 条为 seed=123 生成的固定查询样本，可能是不同设备/窗口。含执行、完整取回及客户端解码。</p><table><tr><th>场景</th><th>成功条数</th><th>最小</th><th>中位</th><th>平均</th><th>最大</th></tr>{''.join(query_rows)}</table></section>
<section><h2>校验与限制</h2><p>四次加载均检查行数、设备数、时间范围及全部 10 指标总和。查询验证 150 条执行成功，并在计时外按源文件独立核验首条单设备聚合、首条高 CPU 过滤及全部设备 lastpoint；其余查询未逐条独立重算。每次使用唯一新库；原有数据库保持。单机自然缓存短测，不代表持续写入上限。查询 groupby-orderby-limit 沿用框架最早 5 桶语义。</p><h2>内嵌证据</h2>'''
    for path in sorted(root.iterdir()):
        if path.suffix in {'.json','.jsonl','.log','.time'}:
            page+='<details><summary>'+html.escape(path.name)+'</summary><pre>'+html.escape(path.read_text())+'</pre></details>'
    page+='</section></main></html>'
    (root/'REPORT.html').write_text(page)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--regenerate',action='store_true',help='preserve old cache and generate/validate new input')
    args=parser.parse_args()
    B.mkdir(exist_ok=True)
    lock=(B/'cpu-oneclick.lock').open('w')
    try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:raise SystemExit('Another one-click benchmark is active')
    if platform.machine()!='aarch64':raise SystemExit('This handoff targets the ARM64 Linux benchmark host')
    for name in ['tsbs_generate_data','tsbs_generate_queries','decode_queries','tsbs_load_tdenginestmt2','tsbs_run_queries_tdengine']:
        if not (BIN/name).is_file():raise SystemExit('Missing prerequisite: '+str(BIN/name))
    if os.statvfs(str(B)).f_bavail*os.statvfs(str(B)).f_frsize<40*1024**3:raise SystemExit('Require at least 40 GiB free')
    stamp=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).strftime('%Y%m%d_%H%M%S')+'_'+str(os.getpid())
    root=B/'results'/('td-cpu-'+stamp);root.mkdir(parents=True)
    (B/'results/latest-td-cpu.txt').write_text(str(root)+'\n')
    summary=dict(status='running',root=str(root),started_epoch=time.time(),loads=[],queries=[],validations=[],
                 timing='internal ingestion excludes startup/worker init/database and table creation')
    stop=threading.Event();thread=None
    def save():dump(root/'summary.json',summary)
    def run(argv,name,output=None,timeout=1800):
        print('RUN',name,flush=True);started=time.time()
        with (root/(name+'.log')).open('wb') as log:
            if output:
                with output.open('wb') as out:proc=subprocess.run(argv,stdout=out,stderr=log,timeout=timeout,cwd=root)
            else:proc=subprocess.run(['/usr/bin/time','-v','-o',str(root/(name+'.time'))]+argv,stdout=log,stderr=log,timeout=timeout,cwd=root)
        rec=dict(name=name,argv=argv,start_epoch=started,end_epoch=time.time(),wall_seconds=time.time()-started,exit_code=proc.returncode)
        if proc.returncode:raise RuntimeError(name+' failed: '+(root/(name+'.log')).read_text()[-1500:])
        return rec
    def validate(db,label,manifest):
        ex=manifest['datasets'][label]['source']
        sql='select count(*) as n,count(distinct hostname) as devices,min(ts) as tmin,max(ts) as tmax,'+','.join('sum('+m+') as s'+str(i) for i,m in enumerate(METRICS))+' from cpu'
        actual=td_query(db,sql)[0]
        passed=actual['n']==ex['rows'] and actual['devices']==ex['devices'] and actual['tmin']==ex['min_ts'] and actual['tmax']==ex['max_ts'] and all(actual['s'+str(i)]==ex['sums'][m] for i,m in enumerate(METRICS))
        summary['validations'].append(dict(database=db,passed=passed,actual=actual,expected=ex));save()
        if not passed:raise RuntimeError('Loaded data validation failed '+db)
    def load(label,index,manifest):
        db='oc_'+stamp+'_'+label+str(index)
        argv=[str(BIN/'tsbs_load_tdenginestmt2'),'--db-name='+db,'--file='+str(CACHE/(label+'-insert-only.stmt2')),
              '--host='+HOST,'--port='+str(PORT),'--workers=8','--batch-size=1000','--vgroups=8','--wal_level=2',
              '--wal_fsync_period=3000','--db_parameters=keep 36500d','--precreate-sql-file='+str(CACHE/(label+'-tables.sql')),'--do-abort-on-exist=true']
        rec=run(argv,label+'-'+str(index));rec.update(label=label,database=db)
        text=(root/(rec['name']+'.log')).read_text()
        match=re.search(r'loaded (\d+) metrics in ([\d.]+)sec with \d+ workers \(mean rate ([\d.]+) metrics/sec\)',text)
        if not match:raise RuntimeError('Missing internal load summary')
        rec.update(metrics=int(match[1]),internal_seconds=float(match[2]),metrics_per_second=float(match[3]))
        if rec['metrics']!=manifest['datasets'][label]['source']['rows']*10:raise RuntimeError('processed count differs')
        summary['loads'].append(rec);save();validate(db,label,manifest)
        dump(root/(db+'-schema.json'),td_query(db,'show create database '+db))
        td_query('','flush database '+db)
        return db
    try:
        save();pid=prepare_service(root,summary);save()
        def sample():
            with (root/'resources.jsonl').open('w') as stream:
                while not stop.is_set():
                    rec=dict(t=time.time())
                    for key,path in [('meminfo','/proc/meminfo'),('cpu','/proc/stat'),('disks','/proc/diskstats'),('server_status','/proc/%d/status'%pid),('server_io','/proc/%d/io'%pid)]:
                        try:rec[key]=Path(path).read_text()
                        except FileNotFoundError:rec[key]='process exited'
                    stream.write(json.dumps(rec)+'\n');stream.flush();stop.wait(2)
        thread=threading.Thread(target=sample,daemon=True);thread.start()
        started=time.time();manifest=prepare_data(run,args.regenerate)
        summary['preparation_wall_seconds']=time.time()-started;dump(root/'input-manifest.json',manifest)
        for i in range(1,4):load('write',i,manifest)
        db=load('query',1,manifest);summary['query_database']=db;save()
        for qt in TYPES:
            (root/(qt+'-sql.jsonl')).write_bytes((CACHE/(qt+'-sql.jsonl')).read_bytes())
            rec=run([str(BIN/'tsbs_run_queries_tdengine'),'--db-name='+db,'--host='+HOST,'--port='+str(PORT),
                     '--file='+str(CACHE/(qt+'.gob')),'--workers=1','--max-queries=10','--prewarm-queries=false',
                     '--print-interval=0','--results-file='+str(root/(qt+'-result.json'))],qt+'-query',timeout=900)
            text=(root/(rec['name']+'.log')).read_text()
            if not re.search('Run complete after 10 queries',text):raise RuntimeError('Query count mismatch')
            values=re.search(r'min:\s*([\d.]+)ms, med:\s*([\d.]+)ms, mean:\s*([\d.]+)ms, max:\s*([\d.]+)ms',text)
            if not values:raise RuntimeError('Query latency summary missing')
            rec.update(type=qt,count=10,min_ms=float(values[1]),median_ms=float(values[2]),mean_ms=float(values[3]),max_ms=float(values[4]))
            summary['queries'].append(rec);save()
        print('VERIFY independent source query samples',flush=True)
        from postcheck import check
        summary['query_source_checks']=check(CACHE,db)
        if not all(c['passed'] for c in summary['query_source_checks']):raise RuntimeError('Independent source checks failed')
        summary['status']='passed'
    except BaseException as exc:
        summary.update(status='failed',error=str(exc));raise
    finally:
        summary['finished_epoch']=time.time();stop.set()
        if thread:thread.join(timeout=5)
        save();report(root,summary)
        print('RESULT',root/'REPORT.html',summary['status'],flush=True)

if __name__=='__main__':main()
