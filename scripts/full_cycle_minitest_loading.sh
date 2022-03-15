#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution

scriptDir=$(dirname $(readlink -f $0))

# - 1) data  generation
echo "===============data generation================="
EXE_FILE_NAME_GENERATE_DATA=$(which tsbs_generate_data)
if [[ -z "${EXE_FILE_NAME_GENERATE_DATA}" ]]; then
    echo "tsbs_generate_data not available. It is not specified explicitly and not found in \$PATH"
    exit 1
fi
# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}

# Space-separated list of target DB formats to generate
FORMAT=${FORMAT:-"timescaledb"}

# Number of hosts to generate data about
SCALE=${SCALE:-"100"}

# Rand seed
SEED=${SEED:-"123"}

# Start and stop time for generated timeseries
TS_START=${TS_START:-"2016-01-01T00:00:00Z"}
TS_END=${TS_END:-"2016-01-02T00:00:00Z"}

# What set of data to generate: devops (multiple data), cpu-only (cpu-usage data)
USE_CASE=${USE_CASE:-"devops"}

# Step to generate data
LOG_INTERVAL=${LOG_INTERVAL:-"10s"}

# Max number of points to generate data. 0 means "use TS_START TS_END with LOG_INTERVAL"
MAX_DATA_POINTS=${MAX_DATA_POINTS:-"0"}

# Ensure DATA DIR available
mkdir -p ${BULK_DATA_DIR}
chmod a+rwx ${BULK_DATA_DIR}

set -eo pipefail

# generate data
INSERT_DATA_FILE_NAME="data_${FORMAT}_${USE_CASE}_scale${SCALE}_${TS_START}_${TS_END}_interval${LOG_INTERVAL}_${SEED}.dat.gz"
if [ -f "${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}" ]; then
    echo "WARNING: file ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME} already exists, skip generating new data"
else
    cleanup() {
        rm -f ${INSERT_DATA_FILE_NAME}
        exit 1
    }
    trap cleanup EXIT

    echo "Generating ${INSERT_DATA_FILE_NAME}:"
    ${EXE_FILE_NAME_GENERATE_DATA} \
        --format ${FORMAT} \
        --use-case ${USE_CASE} \
        --scale ${SCALE} \
        --timestamp-start ${TS_START} \
        --timestamp-end ${TS_END} \
        --seed ${SEED} \
        --log-interval ${LOG_INTERVAL} \
        --max-data-points ${MAX_DATA_POINTS} \
    | gzip > ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}
    trap - EXIT
fi

# - 2) data loading/insertion
echo "===============data loading/insertion================="

# Load parameters - common
DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_NAME=${DATABASE_NAME:-benchmark}
DATABASE_HOST=${DATABASE_HOST:-localhost}
DATABASE_PORT=${DATABASE_PORT:-5432}
DATABASE_PWD=${DATABASE_PWD:-password}
NUM_WORKER=${NUM_WORKER:-"16"} 
BATCH_SIZE=${BATCH_SIZE:-"10000"} 

BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}
mkdir -p ${BULK_DATA_DIR_RES_LOAD} || echo "file exists"
cd ${scriptDir}

# use different load scripts of db to load data , add supported databases 
if [ "${FORMAT}" == "timescaledb" ];then
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":{USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo " DATA_FILE_NAME=\"${INSERT_DATA_FILE_NAME}\" NUM_WORKERS=${NUM_WORKER}  BATCH_SIZE=${BATCH_SIZE}  ./load/load_timescaledb.sh > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME} "
    DATA_FILE_NAME="${INSERT_DATA_FILE_NAME}" NUM_WORKERS=${NUM_WORKER}  BATCH_SIZE=${BATCH_SIZE}  ./load/load_timescaledb.sh > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
elif [  ${FORMAT} == "influx" ];then
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":{USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo " DATA_FILE_NAME=\"${INSERT_DATA_FILE_NAME}\" NUM_WORKERS=${NUM_WORKER}  BATCH_SIZE=${BATCH_SIZE}   ./load/load_influx.sh >  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME} "
    DATA_FILE_NAME="${INSERT_DATA_FILE_NAME}" NUM_WORKERS=${NUM_WORKER}  BATCH_SIZE=${BATCH_SIZE} ./load/load_influx.sh >  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
else
    echo "it don't support format"
fi  


