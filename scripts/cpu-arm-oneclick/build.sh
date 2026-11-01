#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--config" ]]; then
    if [[ $# -ne 2 ]]; then echo 'Usage: bash build.sh --config config.sh' >&2; exit 2; fi
    source "$2"
fi
: "${TSBS_BENCH_ROOT:?Set TSBS_BENCH_ROOT or pass --config config.sh}"
: "${TSBS_TAOSD_BIN:?Set TSBS_TAOSD_BIN to the extracted ARM64 taosd executable}"
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
package_root=$(cd -- "$(dirname -- "$TSBS_TAOSD_BIN")/.." && pwd)
taos_include="$package_root/inc"
if [[ ! -d "$taos_include" ]]; then taos_include="$package_root/include"; fi
[[ -f "$taos_include/taos.h" ]] || { echo "Missing taos.h: $taos_include" >&2; exit 1; }
export CGO_CFLAGS="${CGO_CFLAGS:-} -I$taos_include"
export CGO_LDFLAGS="${CGO_LDFLAGS:-} -L$TSBS_BENCH_ROOT/lib"
export LD_LIBRARY_PATH="$TSBS_BENCH_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
bin_dir="${TSBS_BIN_DIR:-$TSBS_BENCH_ROOT/bin}"
mkdir -p "$bin_dir"
cd "$repo_root"
for target in tsbs_generate_data tsbs_generate_queries tsbs_load_tdenginestmt2 tsbs_run_queries_tdengine; do
    go build -o "$bin_dir/$target" "./cmd/$target"
done
go build -o "$bin_dir/decode_queries" ./scripts/cpu-arm-oneclick/tools/decode_queries.go
