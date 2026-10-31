import struct
METRICS=['usage_user', 'usage_system', 'usage_idle', 'usage_nice', 'usage_iowait', 'usage_irq', 'usage_softirq', 'usage_steal', 'usage_guest', 'usage_guest_nice']
def source_stats(path):
    """Decode STMT2 CPU record layout independently of database loading."""
    counts, sums, tsmin, tsmax = {}, [0]*10, None, None
    with path.open('rb', buffering=4*1024*1024) as f:
        header=f.read(6)
        if header[:2] != b'\x01\x01':
            raise ValueError('unexpected STMT2 CPU header')
        while True:
            raw=f.read(1)
            if not raw: break
            size=raw[0]
            if size & 128: size=(size & 127) | (f.read(1)[0] << 7)
            record=f.read(size)
            if len(record)!=size: raise ValueError('truncated input')
            if record[0]==1: continue
            if size!=97 or record[:2]!=b'\x02\x00' or record[7:9]!=b'\x00\x00':
                raise ValueError('unexpected CPU record: '+record[:12].hex())
            idx=struct.unpack_from('<I',record,2)[0]
            vals=struct.unpack_from('<11q',record,9)
            counts[idx]=counts.get(idx,0)+1
            tsmin=vals[0] if tsmin is None else min(tsmin,vals[0])
            tsmax=vals[0] if tsmax is None else max(tsmax,vals[0])
            for j,v in enumerate(vals[1:]): sums[j]+=v
    return dict(rows=sum(counts.values()), devices=len(counts), min_points=min(counts.values()),
                max_points=max(counts.values()), min_ts=tsmin, max_ts=tsmax,
                sums=dict(zip(METRICS,sums)))
