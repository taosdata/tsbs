#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--config" ]]; then
    if [[ $# -lt 2 ]]; then echo 'Missing config path' >&2; exit 2; fi
    source "$2"
    shift 2
fi
: "${TSBS_BENCH_ROOT:?Set TSBS_BENCH_ROOT or pass --config path/to/config.sh}"
export TSBS_BENCH_ROOT
export TSBS_HOST="${TSBS_HOST:-127.0.0.1}"
export TSBS_PORT="${TSBS_PORT:-6130}"
export LD_LIBRARY_PATH="$TSBS_BENCH_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export GODEBUG=randseednop=0
export TZ=UTC
ulimit -n 1048576
exec python3 -u "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/benchmark.py" "$@"
