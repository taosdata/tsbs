# TDengine CPU ARM one-click benchmark

This is a small orchestration layer over the existing TSBS programs. It invokes
`tsbs_generate_data`, `tsbs_generate_queries`, `tsbs_load_tdenginestmt2` and
`tsbs_run_queries_tdengine`; it does not use the legacy `tsdbComp` installer or
comparison orchestrator. No InfluxDB installation or source build is required.

## Prepare a Linux ARM64 host once

Requirements: Python 3.9+, Go (validated with 1.25.6), C compiler, Git, GNU time,
at least 40 GiB free disk, and a **TDengine Enterprise Linux ARM64** server
package. The expected version is configurable (default: 3.4.3.7).
Keep the host free of other benchmarks; the client and database share this host.

Copy `config.example.sh` to an untracked `config.sh` and set the benchmark root,
package URL, expected version, installed server executable, host and port.
Commands below are run from the TSBS repository root, on the benchmark server:

```bash
cp scripts/cpu-arm-oneclick/config.example.sh scripts/cpu-arm-oneclick/config.sh
# Edit config.sh for your package URL, version, paths and endpoint.
# Install once, or when intentionally changing the database version:
bash scripts/cpu-arm-oneclick/setup.sh --config scripts/cpu-arm-oneclick/config.sh
bash scripts/cpu-arm-oneclick/build.sh --config scripts/cpu-arm-oneclick/config.sh
bash scripts/cpu-arm-oneclick/run.sh --config scripts/cpu-arm-oneclick/config.sh
```

`setup.sh` downloads the HTTP/HTTPS `.tar.gz` URL from `TSBS_TDENGINE_URL`,
verifies `TSBS_TDENGINE_SHA256` if configured, extracts the ARM64 server package,
and runs **`./install.sh -e no` from the package directory**. It uses the package's
normal installation/update behavior, without adding installation flags or running
its own replacement installer. Run this explicit preparation command as root on
the designated test host. Installer output is saved to
`<root>/package-install.log`; a failed installer stops preparation.

Downloads are cached under `<root>/packages/<URL-SHA256>/`. Reusing a URL checks
the cached archive hash and avoids downloading it again; setup still runs the
installer each time it is explicitly invoked. If a publisher replaces the content
at the same URL, preserve and remove that URL's cache before rerunning setup.
Prefer versioned URLs and a publisher-provided SHA-256. URLs are not printed or
stored in report metadata because signed links can contain credentials.

After installation, setup checks that `TSBS_TAOSD_BIN` matches the downloaded
server binary and creates `<root>/lib` links to the **installed** client drivers.
The default installed executable is `/usr/local/taos/bin/taosd`; if the installer
uses a previous custom installation path, set `TSBS_TAOSD_BIN` to that path.
`build.sh` supports both installed `include/` and extracted-package `inc/` headers.
It rebuilds the TSBS binaries against the selected client library.

The installer can update system installation files and manage existing services.
Setup refuses to run while this root's recorded benchmark server is alive; it
never stops that process itself. Stop the verified benchmark PID deliberately
before upgrading. `run.sh` does **not** install or upgrade anything, so everyday
reruns only execute the benchmark.

The working root layout must contain:

```text
<root>/bin/                 # TSBS binaries built by build.sh
<root>/lib/                 # libtaos.so and associated driver libraries
<root>/config/taos.cfg      # isolated server/client config matching host and port
<root>/packages/            # downloaded archives and cache receipts (URL mode)
```

For an already extracted local package, skip `setup.sh`, set `TSBS_TAOSD_BIN`
to its `bin/taosd`, and create `<root>/lib` with links to its client drivers, including
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

### Changing the tested version

For example, testing 3.4.3.8 uses the same scripts and workload:

```bash
# In your private config.sh (replace the example URL with the actual package):
export TSBS_TDENGINE_URL='https://downloads.example.com/tdengine-enterprise-3.4.3.8-linux-arm64.tar.gz'
export TSBS_EXPECTED_VERSION=3.4.3.8
export TSBS_TDENGINE_SHA256='' # Prefer the publisher's actual SHA-256.
export TSBS_TAOSD_BIN=/usr/local/taos/bin/taosd
```

Run `setup.sh`, `build.sh`, then `run.sh` with this config. Setup itself is outside
all benchmark timing. Existing `config/taos.cfg` and isolated data/log/temp paths
still need to be prepared as described above; downloading the package does not
create the benchmark configuration. The version must match `server_version()`
exactly, and the server must identify as enterprise. Reports show the actual
connected server version and include package/server hashes.

The installer follows the normal system upgrade path; separate benchmark roots
do not create parallel system installations. For version comparisons, schedule
versions sequentially, retain previous evidence, and use equivalent initial data
and service settings. Reuse the same verified input cache when the goal is to
change only the server version.

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
