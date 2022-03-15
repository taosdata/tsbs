
# Color setting
RED='\033[0;31m'
GREEN='\033[1;32m'
GREEN_DARK='\033[0;32m'
GREEN_UNDERLINE='\033[4;32m'
NC='\033[0m'

# generate  10min_4000_data

#timescaledb/influxdb  iot/ cpu-only/ devops
# FORMATS="timescaledb  influx" USE_CASES="cpu-only  devops iot " SCALE=4000 SEED=123 \
# TS_START="2016-01-01T00:00:00Z" \
# TS_END="2016-01-01T00:10:01Z" \
# LOG_INTERVAL="10s" \
# BULK_DATA_DIR="/tmp/bulk_data" scripts/generate_data.sh

# use defaulte values;
scripts/generate_data.sh


# Space-separated list of target DB formats to generate:timescaledb influx  TDengine(unsupported)
FORMATS=${FORMATS:-"timescaledb influx"}
# What set of data to generate: devops (multiple data), cpu-only (cpu-usage data)
USE_CASES=${USE_CASES:-"cpu-only devops iot"} 

NUM_WORKERSS=${NUM_WORKERSS:-"1 8 16"} 
BATCH_SIZES=${BATCH_SIZES:-"1000  50000"} 
mkdir data_temp
for FORMAT in ${FORMATS}; do
    echo ${FORMAT}
    if [ "${FORMAT}" == "timescaledb" ];then
        for USE_CASE in ${USE_CASES};do
            for NUM_WORKERS in ${NUM_WORKERSS};do
            echo ${NUM_WORKERS} 
                for BATCH_SIZE in ${BATCH_SIZES};do
                    echo ${BATCH_SIZE} 
                    SYMLINK_NAME="${FORMAT}-${USE_CASE}-data.gz"
                    RESULT_NAME="${FORMAT}-${USE_CASE}-worker${NUM_WORKERS}-batch${BATCH_SIZE}-data.gz"
                    DATA_FILE_NAME="${SYMLINK_NAME}" NUM_WORKERS=${NUM_WORKERS}  BATCH_SIZE=${BATCH_SIZES}  scripts/load/load_timescaledb.sh > ./data_temp/${RESULT_NAME}.txt 
                    echo ""
                    tsdb_metrics=`cat  a.txt|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
                    tsdb_rows=`cat  a.txt|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
                    echo ""
                done
            done
        done
    elif [  ${FORMAT} == "influx" ];then
        for USE_CASE in ${USE_CASES};do
            for NUM_WORKERS in ${NUM_WORKERSS};do
            echo ${NUM_WORKERS} 
                for BATCH_SIZE in ${BATCH_SIZES};do
                    echo ${BATCH_SIZE} 
                    SYMLINK_NAME="${FORMAT}-${USE_CASE}-data.gz"
                    RESULT_NAME="${FORMAT}-${USE_CASE}-worker${NUM_WORKERS}-batch${BATCH_SIZE}-data.gz"
                    DATA_FILE_NAME="${SYMLINK_NAME}" NUM_WORKERS=${NUM_WORKERS}  BATCH_SIZE=${BATCH_SIZES}  scripts/load/load_influx.sh >  ./data_temp/${RESULT_NAME}.txt 
                    echo ""
                    tsdb_metrics=`cat  a.txt|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
                    tsdb_rows=`cat  a.txt|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
                    echo ""
                done
            done
        done
    else
        echo "it don't support formate"
    fi  
done    