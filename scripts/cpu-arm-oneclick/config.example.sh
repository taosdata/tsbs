# Copy to config.sh outside version control and set paths for your test host.
export TSBS_BENCH_ROOT=/srv/tsbs-cpu
export TSBS_HOST=127.0.0.1
export TSBS_PORT=6130
export TSBS_EXPECTED_VERSION=3.4.3.7

# Option A: download and install with setup.sh (HTTP/HTTPS .tar.xz or .tar.gz package).
# Use the complete enterprise server package for Linux ARM64.
export TSBS_TDENGINE_URL=''
# Optional but recommended: SHA-256 supplied by your package publisher.
export TSBS_TDENGINE_SHA256=''
# Installed path after ./install.sh -e no (adjust if the host uses another path).
export TSBS_TAOSD_BIN=/usr/local/taos/bin/taosd

# Option B: skip setup.sh and use an already extracted package, as before.
# Prepare <root>/lib links yourself in this mode.
# export TSBS_TAOSD_BIN="$TSBS_BENCH_ROOT/source/tdengine-tsdb-enterprise-3.4.3.7/bin/taosd"
