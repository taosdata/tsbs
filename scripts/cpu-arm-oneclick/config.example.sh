# Copy to config.sh outside version control and set paths for your test host.
export TSBS_BENCH_ROOT=/srv/tsbs-cpu
export TSBS_HOST=127.0.0.1
export TSBS_PORT=6130
# Official ARM64 package extracted here; it is not downloaded by this script.
export TSBS_TAOSD_BIN="$TSBS_BENCH_ROOT/source/tdengine-tsdb-enterprise-3.4.3.7/bin/taosd"
