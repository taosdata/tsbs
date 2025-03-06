#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution
scriptDir=$(dirname $(readlink -f $0))
source ${scriptDir}/common.sh
source ${scriptDir}/logger.sh

# it have been generated data when execute this scripts
# - 1) query generation
log_info "===============query generation================="
# Queries folder
BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR:-"/tmp/bulk_queries"}
# Form of data to generate
USE_JSON=${USE_JSON:-false}
USE_TAGS=${USE_TAGS:-true}
USE_TIME_BUCKET=${USE_TIME_BUCKET:-true}
# Rand seed
SEED=${SEED:-"123"}
# Ensure DATA DIR available
mkdir -p ${BULK_DATA_QUERY_DIR}
chmod a+rwx ${BULK_DATA_QUERY_DIR}

set -eo pipefail
# Loop over all requested queries types and generate data
DATA_FILE_NAME="queries_${FORMAT}_${USE_CASE}_${QUERY_TYPE}_queries${QUERIES}_scale${SCALE}_seed${SEED}_${TS_START}_${TS_END}_${USE_CASE}.dat.gz"
if [ -f "${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME}" ]; then
    log_warning "WARNING: file ${DATA_FILE_NAME} already exists, skip generating new data"
else
    cleanup() {
        rm -f ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME}
        exit 1
    }
    trap cleanup EXIT

    EXE_FILE_NAME_GENERATE_QUE=${EXE_FILE_NAME_GENERATE_QUE:-$(which tsbs_generate_queries)}
    if [[ -z "${EXE_FILE_NAME_GENERATE_QUE}" ]]; then
        echo "tsbs_generate_queries not available. It is not specified explicitly and not found in \$PATH"
        exit 1
    fi
    log_debug "Generating ${EXE_FILE_NAME_GENERATE_QUE} \
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
    | gzip  > ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME}"
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
log_info "===============query running================="
# Queryresult Path
BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES:-"/tmp/bulk_result_query"}
# Ensure DATA DIR available
mkdir -p ${BULK_DATA_DIR_RUN_RES}
chmod a+rwx ${BULK_DATA_DIR_RUN_RES}

DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_PWD=${DATABASE_PWD:-password}
DATABASE_TAOS_PWD=${DATABASE_TAOS_PWD:-taosdata}

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

if [ ${QUERY_DEBUG} == "true" ];then
    debugflag=1
    printResponse="true"
else
    debugflag=0
    printResponse="false"
fi
log_debug "${debugflag} ${printResponse}"
log_info "Running ${DATA_FILE_NAME}"

if [[ "${FORMAT}" =~ "timescaledb" ]]; then

    EXE_FILE_NAME_RUN_TSCD=${EXE_FILE_NAME_RUN_TSCD:-$(which tsbs_run_queries_timescaledb)}
    if [[ -z "$EXE_FILE_NAME_RUN_TSCD" ]]; then
        log_error "tsbs_run_queries_timescaledb not available. It is not specified explicitly and not found in \$PATH"
        exit 1
    fi
    RESULT_NAME="${FORMAT}_${USE_CASE}_${QUERY_TYPE}_scale${SCALE}_worker${NUM_WORKER}_data.txt"
    OUT_FULL_FILE_NAME="${BULK_DATA_DIR_RUN_RES}/result_query_${RESULT_NAME}"
    log_info "Start to execute ${FORMAT} query, query type: ${QUERY_TYPE}"
    log_debug "Execute commond: cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} | ${GUNZIP} | ${EXE_FILE_NAME_RUN_TSCD}  --hosts ${DATABASE_HOST} --user  ${DATABASE_USER}   --pass ${DATABASE_PWD}  --db-name ${DATABASE_NAME} --max-queries ${MAX_QUERIES} --workers ${NUM_WORKER}  --debug=${debugflag} --print-responses=${printResponse} |tee ${OUT_FULL_FILE_NAME} "
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
        log_info "Execution of ${FORMAT} query type ${QUERY_TYPE} finished"
elif [  ${FORMAT} == "influx" ] || [  ${FORMAT} == "influx3" ]; then
    EXE_FILE_NAME_RUN_INF=${EXE_FILE_NAME_RUN_INF:-$(which tsbs_run_queries_influx3)}
    if [[ -z "$EXE_FILE_NAME_RUN_INF" ]]; then
        log_error "tsbs_run_queries_influx3 not available. It is not specified explicitly and not found in \$PATH"
        exit 1
    fi

    set +e  # Disable exit on error

    query_command="tsbs_run_queries_${FORMAT}"
    if [  ${FORMAT} == "influx" ]; then
        DATABASE_PORT=${influx_port:-8086}
    elif [  ${FORMAT} == "influx3" ]; then
        DATABASE_PORT=${influx3_port:-8181}
    fi
    RESULT_NAME="${FORMAT}_${USE_CASE}_${QUERY_TYPE}_scale${SCALE}_worker${NUM_WORKER}_data.txt"
    OUT_FULL_FILE_NAME="${BULK_DATA_DIR_RUN_RES}/result_query_${RESULT_NAME}"
    log_info "Start to execute ${FORMAT} query, query type: ${QUERY_TYPE}"
    log_debug "Execute commond:  ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME}  | ${GUNZIP} | ${query_command}  --max-queries ${MAX_QUERIES} --workers ${NUM_WORKERS} --urls=http://${DATABASE_HOST}:${DATABASE_PORT} | tee ${OUT_FULL_FILE_NAME}"
    cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} \
        | ${GUNZIP} \
        | ${query_command} \
            --db-name ${DATABASE_NAME} \
            --max-queries ${MAX_QUERIES} \
            --workers ${NUM_WORKER} \
            --urls=http://${DATABASE_HOST}:${DATABASE_PORT} \
            --debug=${debugflag}\
            --print-responses=${printResponse}\
        | tee ${OUT_FULL_FILE_NAME}
        if [ $? -ne 0 ]; then
            log_error "Error: influx query failed,query type:${QUERY_TYPE},scale:${SCALE},worker:${NUM_WORKER}"
            wctime=0
            qps=0
            echo ${FORMAT},${USE_CASE},${QUERY_TYPE},${SCALE},${QUERIES},${NUM_WORKER},${wctime},${qps} >> ${BULK_DATA_DIR_RUN_RES}/query_input.csv
        else
            wctime=`cat  ${OUT_FULL_FILE_NAME}|grep "mean:"|awk '{print $6}' | head -1  |sed "s/ms,//g" `
            qps=`cat  ${OUT_FULL_FILE_NAME}|grep Run |awk '{print $12}' `
            echo ${FORMAT},${USE_CASE},${QUERY_TYPE},${SCALE},${QUERIES},${NUM_WORKER},${wctime},${qps} >> ${BULK_DATA_DIR_RUN_RES}/query_input.csv
        fi
        set -e  # Re-enable exit on error
        log_info "Execution of ${FORMAT} query type ${QUERY_TYPE} finished"

elif [  ${FORMAT} == "TDengine" ] ; then
    EXE_FILE_NAME_RUN_TD=${EXE_FILE_NAME_RUN_TD:-$(which tsbs_run_queries_tdengine)}
    if [[ -z "$EXE_FILE_NAME_RUN_TD" ]]; then
        log_error "tsbs_run_queries_tdengine not available. It is not specified explicitly and not found in \$PATH"
        exit 1
    fi
    DATABASE_PORT=${tdengine_port:-6030}
    RESULT_NAME="${FORMAT}_${USE_CASE}_${QUERY_TYPE}_scale${SCALE}_worker${NUM_WORKER}_data.txt"
    OUT_FULL_FILE_NAME="${BULK_DATA_DIR_RUN_RES}/result_query_${RESULT_NAME}"
    log_info "Start to execute ${FORMAT} query, USE_CASE: ${USE_CASE}, query type: ${QUERY_TYPE}, scale: ${SCALE} "
    log_debug "execute commond:  cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} \
        | ${GUNZIP} \
        | ${EXE_FILE_NAME_RUN_TD} \
        --db-name ${DATABASE_NAME} --host ${DATABASE_HOST}  --pass ${DATABASE_TAOS_PWD} --port ${DATABASE_PORT} \
        --max-queries ${MAX_QUERIES}  --workers ${NUM_WORKER} --debug=${debugflag} --print-responses=${printResponse} \
        | tee ${OUT_FULL_FILE_NAME}"
    cat ${BULK_DATA_QUERY_DIR}/${DATA_FILE_NAME} \
        | ${GUNZIP} \
        | ${EXE_FILE_NAME_RUN_TD} \
            --db-name ${DATABASE_NAME} \
            --host ${DATABASE_HOST} \
            --pass ${DATABASE_TAOS_PWD} \
            --port ${DATABASE_PORT} \
            --max-queries ${MAX_QUERIES} \
            --workers ${NUM_WORKER} \
            --debug=${debugflag}\
            --print-responses=${printResponse}\
        | tee ${OUT_FULL_FILE_NAME}
    wctime=`cat  ${OUT_FULL_FILE_NAME}|grep "mean:"|awk '{print $6}' | head -1  |sed "s/ms,//g"`
    qps=`cat  ${OUT_FULL_FILE_NAME}|grep Run |awk '{print $12}' `
    echo ${FORMAT},${USE_CASE},${QUERY_TYPE},${SCALE},${QUERIES},${NUM_WORKER},${wctime},${qps} >> ${BULK_DATA_DIR_RUN_RES}/query_input.csv
    log_info "Execution of ${FORMAT} query type ${QUERY_TYPE} finished"
else
    echo "it don't support format"
fi  