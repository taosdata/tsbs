import json
import re
import struct
from native import td_query

def check(P,DB):
    queries={qt:json.loads((P/(qt+'-sql.jsonl')).read_text().splitlines()[0])['sql']
             for qt in ['single-groupby-1-1-1','high-cpu-1','lastpoint']}
    def params(sql):
        return tuple(map(int,re.search(r'FROM host_(\d+) WHERE.*?ts >= (\d+) AND ts < (\d+)',sql).groups()))
    host,start,end=params(queries['single-groupby-1-1-1'])
    highhost,hs,he=params(queries['high-cpu-1'])
    buckets={};high=[];last={}
    with (P/'query.stmt2').open('rb',buffering=4*1024*1024) as f:
        f.read(6)
        while True:
            b=f.read(1)
            if not b:break
            n=b[0]
            if n & 128:n=(n & 127) | (f.read(1)[0]<<7)
            row=f.read(n)
            if row[0]!=2:continue
            idx=struct.unpack_from('<I',row,2)[0]-1
            values=struct.unpack_from('<11q',row,9)
            ts=values[0]
            if idx not in last or ts>last[idx][0]:last[idx]=values
            if idx==host and start<=ts<end:
                bucket=(ts//60000)*60000
                buckets[bucket]=max(buckets.get(bucket,-1),values[1])
            if idx==highhost and hs<=ts<he and values[1]>90:high.append(values)
    checks=[]
    rows=td_query(DB,queries['single-groupby-1-1-1'])
    checks.append(dict(type='single-groupby-1-1-1',passed={r['ts']:r['max(usage_user)'] for r in rows}==buckets,
                       expected_rows=len(buckets),actual_rows=len(rows)))
    rows=td_query(DB,queries['high-cpu-1'])
    checks.append(dict(type='high-cpu-1',passed=len(rows)==len(high)==0,
                       expected_rows=len(high),actual_rows=len(rows),note='first query is genuinely empty in source'))
    rows=td_query(DB,queries['lastpoint'])
    metrics=['usage_user','usage_system','usage_idle','usage_nice','usage_iowait','usage_irq','usage_softirq','usage_steal','usage_guest','usage_guest_nice']
    actual={int(r['tbname'].split('_')[-1]):tuple([r['last_row(ts)']]+[r['last_row('+m+')'] for m in metrics]) for r in rows}
    checks.append(dict(type='lastpoint',passed=actual==last,expected_rows=len(last),actual_rows=len(rows)))
    return checks
