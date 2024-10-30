#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution
set -e 
scriptDir=$(dirname $(readlink -f $0))

# it have been generated data when execute this scripts

# - 1) query generation
echo "===============query generation================="
EXE_FILE_NAME_GENERATE_QUE=${EXE_FILE_NAME_GENERATE_QUE:-$(which tsbs_generate_queries)}
if [[ -z "${EXE_FILE_NAME_GENERATE_QUE}" ]]; then
    echo "tsbs_generate_queries not available. It is not specified explicitly and not found in \$PATH"
    exit 1
fi

EXE_FILE_VERSION=`md5sum $EXE_FILE_NAME_GENERATE_QUE | awk '{ print $1 }'`
# Queries folder
BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR:-"/tmp/bulk_queries"}

FORMATAISA=${FORMATAISA:-"timescaledb"}


# Form of data to generate
USE_JSON=${USE_JSON:-false}
USE_TAGS=${USE_TAGS:-true}
USE_TIME_BUCKET=${USE_TIME_BUCKET:-true}

# Space-separated list of target DB formats to generate
FORMAT=${FORMAT:-"timescaledb"}

# All available for generation query types (sorted alphabetically)
# QUERY_TYPES_ALL="cpu-max-all-1"

# What query types to generate
QUERY_TYPE=${QUERY_TYPE:-"cpu-max-all-1"}

# Number of hosts to generate data about
SCALE=${SCALE:-"100"}

# Number of queries to generate
QUERIES=${QUERIES:-"1000"}

# Rand seed
SEED=${SEED:-"123"}

# Start and stop time for generated timeseries
TS_START=${TS_START:-"2016-01-01T00:00:00Z"}
TS_END=${TS_END:-"2016-01-02T00:00:01Z"}

# What set of data to generate: devops (multiple data), cpu-only (cpu-usage data)
USE_CASE=${USE_CASE:-"cpu-only"}

# Ensure DATA DIR available
mkdir -p ${BULK_DATA_QUERY_DIR}
chmod a+rwx ${BULK_DATA_QUERY_DIR}

set -eo pipefail

# Loop over all requested queries types and generate data
DATA_FILE_NAME="queries_${FORMAT}_${USE_CASE}_${QUERY_TYPE}_queries${QUERIES}_scale${SCALE}_seed${SEED}_${TS_START}_${TS_END}_${USE_CASE}.dat.gz"
if [ -f "${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME}" ]; then
    echo "WARNING: file ${DATA_FILE_NAME} already exists, skip generating new data"
else
    cleanup() {
        rm -f ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME}
        exit 1
    }
    trap cleanup EXIT

    echo "Generating ${DATA_FILE_NAME}:"
    ${EXE_FILE_NAME_GENERATE_QUE} \
        --format ${FORMAT} \
        --queries ${QUERIES} \
        --query-type ${QUERY_TYPE} \
        --scale ${SCALE} \
        --seed ${SEED} \
        --timestamp-start ${TS_START} \
        --timestamp-end ${TS_END} \
        --use-case ${USE_CASE} \
        --timescale-use-json=${USE_JSON} \
        --timescale-use-tags=${USE_TAGS} \
        --timescale-use-time-bucket=${USE_TIME_BUCKET} \
        --clickhouse-use-tags=${USE_TAGS} \
    | gzip  > ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME}

    trap - EXIT
fi

# - 2) query execution
echo "===============query running================="

# Ensure runner is available
EXE_FILE_NAME_RUN_TSCD=${EXE_FILE_NAME_RUN_TSCD:-$(which tsbs_run_queries_timescaledb)}
if [[ -z "$EXE_FILE_NAME_RUN_TSCD" ]]; then
    echo "tsbs_run_queries_timescaledb not available. It is not specified explicitly and not found in \$PATH"
    exit 1
fi

EXE_FILE_NAME_RUN_INF=${EXE_FILE_NAME_RUN_INF:-$(which tsbs_run_queries_influx)}
if [[ -z "$EXE_FILE_NAME_RUN_INF" ]]; then
    echo "tsbs_run_queries_influx not available. It is not specified explicitly and not found in \$PATH"
    exit 1
fi



EXE_FILE_NAME_RUN_TD=${EXE_FILE_NAME_RUN_TD:-$(which tsbs_run_queries_tdengine)}
if [[ -z "$EXE_FILE_NAME_RUN_TD" ]]; then
    echo "tsbs_run_queries_influx not available. It is not specified explicitly and not found in \$PATH"
    exit 1
fi



# Queryresult Path
BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES:-"/tmp/bulk_result_query"}
# Ensure DATA DIR available
mkdir -p ${BULK_DATA_DIR_RUN_RES}
chmod a+rwx ${BULK_DATA_DIR_RUN_RES}


DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_NAME=${DATABASE_NAME:-benchmark}
DATABASE_HOST=${DATABASE_HOST:-localhost}
DATABASE_PORT=${DATABASE_PORT:-5432}
DATABASE_PWD=${DATABASE_PWD:-password}
DATABASE_INF_PORT=${DATABASE_INF_PORT:-8086}
DATABASE_TAOS_PWD=${DATABASE_TAOS_PWD:-taosdata}
DATABASE_TAOS_PORT=${DATABASE_TAOS_PORT:-6030}
NUM_WORKER=${NUM_WORKER:-"16"} 
QUERY_DEBUG=${QUERY_DEBUG:-"false"} 

# How many queries would be run
MAX_QUERIES=${MAX_QUERIES:-"0"}

# How many concurrent worker would run queries - match num of cores, or default to 4
# NUM_WORKER=${NUM_WORKER:-$(grep -c ^processor /proc/cpuinfo 2> /dev/null || echo 4)}

# modify data type
EXTENSION="${DATA_FILE_NAME##*.}"
if [ "${EXTENSION}" == "gz" ]; then
    GUNZIP="gunzip"
else
    GUNZIP="cat"
fi

echo ""
if [ ${QUERY_DEBUG} == "true" ];then
    debugflag=1
    printResponse="true"
else
    debugflag=0
    printResponse="false"
fi
echo "${debugflag} ${printResponse}"
echo "Running ${DATA_FILE_NAME}"
if [[ "${FORMAT}" =~ "timescaledb" ]]; then
    RESULT_NAME="${FORMAT}_${USE_CASE}_${QUERY_TYPE}_scale${SCALE}_worker${NUM_WORKER}_data.txt"
    OUT_FULL_FILE_NAME="${BULK_DATA_DIR_RUN_RES}/result_query_${RESULT_NAME}"
    echo "start to execute timescaledb query:"`date +%Y_%m%d_%H%M%S`
    echo " cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} | ${GUNZIP} | ${EXE_FILE_NAME_RUN_TSCD}  --hosts ${DATABASE_HOST} --user  ${DATABASE_USER}   --pass ${DATABASE_PWD}  --db-name ${DATABASE_NAME} --max-queries ${MAX_QUERIES} --workers ${NUM_WORKER}  --debug=${debugflag} --print-responses=${printResponse} |tee ${OUT_FULL_FILE_NAME} "
    cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} \
        | ${GUNZIP} \
        | ${EXE_FILE_NAME_RUN_TSCD} \
            --hosts ${DATABASE_HOST} \
            --user  ${DATABASE_USER} \
            --pass ${DATABASE_PWD} \
            --db-name ${DATABASE_NAME} \
            --max-queries ${MAX_QUERIES} \
            --workers ${NUM_WORKER} \
            --debug=${debugflag}\
            --print-responses=${printResponse}\
        | tee ${OUT_FULL_FILE_NAME}
        wctime=`cat  ${OUT_FULL_FILE_NAME}|grep "mean:"|awk '{print $6}' | head -1  |sed "s/ms,//g" `
        qps=`cat  ${OUT_FULL_FILE_NAME}|grep Run |awk '{print $12}' `
        echo ${FORMATAISA},${USE_CASE},${QUERY_TYPE},${SCALE},${QUERIES},${NUM_WORKER},${wctime},${qps} >> ${BULK_DATA_DIR_RUN_RES}/query_input.csv
        echo " timescaledb query finish:"`date +%Y_%m%d_%H%M%S`
elif [  ${FORMAT} == "influx" ]; then
    RESULT_NAME="${FORMAT}_${USE_CASE}_${QUERY_TYPE}_scale${SCALE}_worker${NUM_WORKER}_data.txt"
    OUT_FULL_FILE_NAME="${BULK_DATA_DIR_RUN_RES}/result_query_${RESULT_NAME}"
    echo "start to execute influx query:"`date +%Y_%m%d_%H%M%S`
    echo "cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME}  | ${GUNZIP} | ${EXE_FILE_NAME_RUN_INF}  --max-queries ${MAX_QUERIES} --workers ${NUM_WORKERS} --urls=http://${DATABASE_HOST}:${DATABASE_INF_PORT} | tee ${OUT_FULL_FILE_NAME}"
    cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} \
        | ${GUNZIP} \
        | ${EXE_FILE_NAME_RUN_INF} \
            --db-name ${DATABASE_NAME} \
            --max-queries ${MAX_QUERIES} \
            --workers ${NUM_WORKER} \
            --urls=http://${DATABASE_HOST}:${DATABASE_INF_PORT} \
            --debug=${debugflag}\
            --print-responses=${printResponse}\
        | tee ${OUT_FULL_FILE_NAME}
        wctime=`cat  ${OUT_FULL_FILE_NAME}|grep "mean:"|awk '{print $6}' | head -1  |sed "s/ms,//g" `
        qps=`cat  ${OUT_FULL_FILE_NAME}|grep Run |awk '{print $12}' `
        echo ${FORMAT},${USE_CASE},${QUERY_TYPE},${SCALE},${QUERIES},${NUM_WORKER},${wctime},${qps} >> ${BULK_DATA_DIR_RUN_RES}/query_input.csv
        echo " influx query finish:"`date +%Y_%m%d_%H%M%S`
elif [  ${FORMAT} == "TDengine" ] || [  ${FORMAT} == "TDengineStmt2" ]; then
    RESULT_NAME="${FORMAT}_${USE_CASE}_${QUERY_TYPE}_scale${SCALE}_worker${NUM_WORKER}_data.txt"
    OUT_FULL_FILE_NAME="${BULK_DATA_DIR_RUN_RES}/result_query_${RESULT_NAME}"
    echo "start to execute TDengine query:"`date +%Y_%m%d_%H%M%S`
    echo " cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} | ${GUNZIP} | ${EXE_FILE_NAME_RUN_TD} --db-name ${DATABASE_NAME} --host ${DATABASE_HOST}  --pass ${DATABASE_TAOS_PWD} --port ${DATABASE_TAOS_PORT} --max-queries ${MAX_QUERIES}  --workers ${NUM_WORKER} | tee ${OUT_FULL_FILE_NAME}"
    cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} \
        | ${GUNZIP} \
        | ${EXE_FILE_NAME_RUN_TD} \
            --db-name ${DATABASE_NAME} \
            --host ${DATABASE_HOST} \
            --pass ${DATABASE_TAOS_PWD} \
            --port ${DATABASE_TAOS_PORT} \
            --max-queries ${MAX_QUERIES} \
            --workers ${NUM_WORKER} \
            --debug=${debugflag}\
            --print-responses=${printResponse}\
        | tee ${OUT_FULL_FILE_NAME}
        wctime=`cat  ${OUT_FULL_FILE_NAME}|grep "mean:"|awk '{print $6}' | head -1  |sed "s/ms,//g"`
        qps=`cat  ${OUT_FULL_FILE_NAME}|grep Run |awk '{print $12}' `
        echo ${FORMAT},${USE_CASE},${QUERY_TYPE},${SCALE},${QUERIES},${NUM_WORKER},${wctime},${qps} >> ${BULK_DATA_DIR_RUN_RES}/query_input.csv
        echo " TDengine query finish:"`date +%Y_%m%d_%H%M%S`
else
    echo "it don't support format"
fi  