#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution

scriptDir=$(dirname $(readlink -f $0))

# - 1) data  generation
echo "===============data generation================="
echo "${FORMAT},${SCALE},${USE_CASE}"
EXE_FILE_NAME_GENERATE_DATA=$(which tsbs_generate_data)
if [[ -z "${EXE_FILE_NAME_GENERATE_DATA}" ]]; then
    echo "tsbs_generate_data not available. It is not specified explicitly and not found in \$PATH"
    exit 1
fi
# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
TDPath="/var/lib/taos/"
InfPath="/var/lib/influxdb/"
TimePath="/var/lib/postgresql/14/main/base/"

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
DATABASE_PORT_INF=${DATABASE_PORT_INF:-8086}
DATABASE_TAOS_PWD=${DATABASE_TAOS_PWD:-taosdata}
DATABASE_TAOS_PORT=${DATABASE_TAOS_PORT:-6030}
NUM_WORKER=${NUM_WORKER:-"16"} 
BATCH_SIZE=${BATCH_SIZE:-"10000"} 
CHUNK_TIME=${CHUNK_TIME:-"12h"}
SERVER_PASSWORD=${SERVER_PASSWORD:-123456}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}
mkdir -p ${BULK_DATA_DIR_RES_LOAD} || echo "file exists"
cd ${scriptDir}

echo "---------------  Clean  -----------------"
sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST << eeooff
rm -rf ${TDPath}/*
rm -rf ${InfPath}/*
echo 1 > /proc/sys/vm/drop_caches
systemctl restart taosd 
systemctl restart influxd
systemctl restart postgresql
sleep 1
exit
eeooff


# use different load scripts of db to load data , add supported databases 
if [ "${FORMAT}" == "timescaledb" ];then
    disk_usage_before=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${TimePath} | cut -f 1 " `
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo "cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD} --chunk-time=${CHUNK_TIME} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD}  --chunk-time=${CHUNK_TIME} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    disk_usage_after=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${TimePath}| cut -f 1 " `
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
elif [  ${FORMAT} == "influx" ];then
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo "cat  ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip |  tsbs_load_influx  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT_INF}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME} | gunzip |   tsbs_load_influx  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT_INF}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    disk_usage=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${InfPath}/data | cut -f 1 " `
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
elif [  ${FORMAT} == "TDengine" ];then
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo " cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |  tsbs_load_tdengine  --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |   tsbs_load_tdengine \
    --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} --pass=${DATABASE_TAOS_PWD} --port=${DATABASE_TAOS_PORT}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    systemctl stop taosd
    disk_usage=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${TDPath}/vnode | cut -f 1 " `
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv    
else
    echo "it don't support format"
fi  


