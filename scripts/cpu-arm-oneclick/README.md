# TDengine CPU ARM one-click benchmark

This is a small orchestration layer over the existing TSBS programs. It invokes
`tsbs_generate_data`, `tsbs_generate_queries`, `tsbs_load_tdenginestmt2` and
`tsbs_run_queries_tdengine`; it does not use the legacy `tsdbComp` installer or
comparison orchestrator. No InfluxDB installation or source build is required.

## Prepare a Linux ARM64 host once

Requirements: Python 3.9+, Go (validated with 1.25.6), C compiler, Git, GNU time,
at least 40 GiB free disk, and an already extracted **TDengine Enterprise
3.4.3.7 ARM64** package. This script neither downloads nor installs the database.
Keep the host free of other benchmarks; the client and database share this host.

Copy `config.example.sh` to an untracked `config.sh` and set the benchmark root,
server executable, host and port. Commands below are run from the TSBS repository
root, on the benchmark server:

```bash
cp scripts/cpu-arm-oneclick/config.example.sh scripts/cpu-arm-oneclick/config.sh
# Edit config.sh for your paths and endpoint.
bash scripts/cpu-arm-oneclick/build.sh --config scripts/cpu-arm-oneclick/config.sh
bash scripts/cpu-arm-oneclick/run.sh --config scripts/cpu-arm-oneclick/config.sh
```

The working root layout must contain:

```text
<root>/bin/                 # TSBS binaries built by build.sh
<root>/lib/                 # libtaos.so and associated driver libraries
<root>/config/taos.cfg      # isolated server/client config matching host and port
<root>/source/<package>/    # extracted official ARM64 package (taosd and inc/)
```

Create `<root>/lib` with links to the extracted package's client drivers, including
`libtaos.so` and `libtaosnative.so` where the release provides them. Configure
`taos.cfg` with isolated data/log/temp directories, `fqdn`, `firstEp` and
`serverPort` for this instance. A running server must have a PID file at
`<root>/taosd.pid` whose executable and arguments match `TSBS_TAOSD_BIN -c
<root>/config`; an unknown process is never terminated or adopted. If no owned
server is running, the runner starts one and records its PID. It waits for dnodes
to become ready and verifies the server version. TDengine remains running at the
end. The example assumes the package's default root/taosdata database account;
SSH login credentials are not stored or managed by these scripts.

For a colleague, the normal handoff is this checkout plus the host's private
`config.sh`. With SSH access, run the same command remotely, e.g.:

```bash
ssh user@benchmark-host 'cd /path/to/tsbs && bash scripts/cpu-arm-oneclick/run.sh --config scripts/cpu-arm-oneclick/config.sh'
```

Database installation packages, binaries, datasets, host configs and generated
reports are runtime artifacts; **do not commit them**. `config.sh` is ignored.

## Fixed workload

| Phase | Data | Execution |
| --- | --- | --- |
| Write | 100,000 devices × 100 points × 10 metrics = 10M rows | Three independent new databases; 8 workers, batch 1,000 |
| Query | 4,000 devices × 2,880 points = 11.52M rows, 24h / 30s | One new database; all 15 CPU types, 10 samples/type, 1 worker |

Seed=123, UTC, `GODEBUG=randseednop=0`, uncompressed STMT2 binary input.
The database uses vgroups=8, replica=1, WAL=2, fsync=3,000ms and keep=36500d.

The main write metric is the median of three **internal ingestion throughput**
measurements. Startup, worker initialization, database and precreated child-table
DDL are excluded; scanning, batching, transmission and response waits are
included. External wall time is separately reported. Asynchronous fsync does not
establish synchronous persistence of every acknowledged row.

Queries include SQL execution, full result retrieval and decoding, with no prewarm
or explicit cache eviction. The 10 samples are fixed-seed generated queries,
not necessarily 10 identical SQL statements. `groupby-orderby-limit` preserves
the existing adapter's earliest-five-buckets behavior.

## Cache, reruns and results

The first run generates data, independently decodes it, separates child-table DDL
from insert records, checks the separated data, generates query samples, and saves
SHA-256 hashes. Preparation time is recorded separately from ingestion throughput.
Later runs verify all cached file hashes and reuse the inputs. To regenerate,
preserve the old cache automatically and create a new one:

```bash
bash scripts/cpu-arm-oneclick/run.sh --config scripts/cpu-arm-oneclick/config.sh --regenerate
```

An exclusive lock prevents simultaneous runs from this entry point. Every run
creates unique databases and a unique `<root>/results/td-cpu-...` directory.
It never deletes existing databases or evicts the OS cache. Each run adds four
databases; monitor disk usage before scheduling repeated tests. The runner raises
the process file-descriptor limit; the account must permit this increase.

A successful run ends with `RESULT .../REPORT.html passed`. Failures return a
nonzero exit code and preserve logs with a failed report. A failed run is not
resumed automatically: running the command again uses new databases.
`<root>/results/latest-td-cpu.txt` contains the latest result directory.
Copy `REPORT.html` from that directory for sharing; it embeds summary JSON,
parameters, hashes, decoded SQL, validation records, logs and resource samples.
It works offline without JavaScript or sidecar files.

All four loads are checked against source row counts, device counts, timestamp
bounds and sums of all 10 metrics. All 150 query executions must succeed.
Outside timing, the runner independently checks the first single-device minute
aggregation, first high-CPU filter, and the latest point of all 4,000 devices
against source data. Other query results are not independently recomputed.

On one 64-core Kunpeng / 126 GiB / NVMe host, the initial preparation-to-report
run took about 7 minutes, and a cached repeat about 2 minutes. These are observed
turnaround times rather than performance guarantees. No sustained-load or
cross-product conclusion follows from this short single-host test.
