#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--config" && $# -eq 2 ]]; then
    source "$2"
else
    echo 'Usage: bash setup.sh --config config.sh' >&2
    exit 2
fi
: "${TSBS_BENCH_ROOT:?Set TSBS_BENCH_ROOT in config.sh}"
: "${TSBS_TDENGINE_URL:?Set TSBS_TDENGINE_URL in config.sh}"
export TSBS_BENCH_ROOT TSBS_TDENGINE_URL
exec python3 -u "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/setup_package.py"
