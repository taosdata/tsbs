#!/bin/bash
scriptDir=$(dirname $(readlink -f $0))
source ${scriptDir}/common.sh
source ${scriptDir}/logger.sh


# Data folder
BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR:-"/tmp/bulk_queries/"}
BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES:-"/tmp/bulk_result_query/"}

BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}

# cleat data
rm -rf ${BULK_DATA_QUERY_DIR}/*
rm -rf ${BULK_DATA_DIR_RUN_RES}/*
# common paramaters
CHUNK_TIME=${CHUNK_TIME:-"12h"}

# Define an associative array for FORMAT to CHUNK_TIME mapping
declare -A chunk_time_map=(
    ["timescaledb10"]="74.4h"
    ["timescaledb100"]="446m"
    ["timescaledb1k"]="45m"
    ["timescaledb1w"]="4m"
    ["timescaledb10w"]="27s"
    ["timescaledb36"]="5m"
    ["timescaledb12"]="15m"
    ["timescaledb8"]="23m"
    ["timescaledb6"]="30m"
    ["timescaledb4"]="45m"
)
# testcase : 
for FORMAT in ${FORMATS}; do
    if [[ -n "${chunk_time_map[$FORMAT]}" ]]; then
        CHUNK_TIME="${chunk_time_map[$FORMAT]}"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    fi
    
    FORMATAISA=${FORMATAISA:-"timescaledb"}
    log_debug "FORMAT=${FORMAT} FORMATAISA=${FORMATAISA} CHUNK_TIME=${CHUNK_TIME}"
    if [ ${RELOADDATA} == "true" ] ;then
        log_debug " DATABASE_HOST=${DATABASE_HOST} SCALE=${SCALE} FORMAT=${FORMAT} USE_CASE=${USE_CASE} BATCH_SIZE=${BATCH_SIZE}  NUM_WORKER=${NUM_WORKER_LOAD} BULK_DATA_DIR=${BULK_DATA_DIR} TS_END=${LOAD_TS_END} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} DATABASE_NAME=${DATABASE_NAME} CHUNK_TIME=${CHUNK_TIME} SERVER_PASSWORD=${SERVER_PASSWORD}   FORMATAISA=${FORMATAISA} VGROUPS=${VGROUPS}  ./full_cycle_minitest_query_loading.sh "
        DATABASE_HOST=${DATABASE_HOST} SCALE=${SCALE} FORMAT=${FORMAT} USE_CASE=${USE_CASE} BATCH_SIZE=${BATCH_SIZE}  NUM_WORKER=${NUM_WORKER_LOAD} BULK_DATA_DIR=${BULK_DATA_DIR} TS_END=${LOAD_TS_END} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} DATABASE_NAME=${DATABASE_NAME} CHUNK_TIME=${CHUNK_TIME} SERVER_PASSWORD=${SERVER_PASSWORD}  FORMATAISA=${FORMATAISA}  VGROUPS=${VGROUPS}   ./full_cycle_minitest_query_loading.sh
    else
        log_info "Skip loading data"
    fi

    sleep 10s
    if [ ${USE_CASE} != "iot" ] && [ ${USE_CASE} != "iottest" ];then
        QUERY_TYPES=${QUERY_TYPES_ALL}
    else
        QUERY_TYPES=${QUERY_TYPES_IOT_ALL}
    fi

    if [  ${FORMAT} == "TDengine" ] || [  ${FORMAT} == "TDengineStmt2" ];then
        FORMAT=${FORMAT:-"TDengine"}
    fi
    
    for QUERY_TYPE in ${QUERY_TYPES}; do
        for NUM_WORKER in ${NUM_WORKERS}; do
            log_debug " DATABASE_HOST=${DATABASE_HOST} BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR} BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES}  TS_START=${TS_START}  TS_END=${QUERY_TS_END} QUERIES=${QUERIES} FORMAT=${FORMAT} USE_CASE=${USE_CASE} QUERY_TYPE=${QUERY_TYPE} SCALE=${SCALE} FORMATAISA=${FORMATAISA}  NUM_WORKER=${NUM_WORKER} ./full_cycle_minitest_query.sh "
            DATABASE_HOST=${DATABASE_HOST} \
            BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR} \
            BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
            DATABASE_NAME=${DATABASE_NAME} \
            TS_START=${TS_START} \
            TS_END=${QUERY_TS_END} \
            QUERIES=${QUERIES} \
            FORMAT=${FORMAT} \
            USE_CASE=${USE_CASE} \
            QUERY_TYPE=${QUERY_TYPE} \
            QUERY_DEBUG=${QUERY_DEBUG} \
            SCALE=${SCALE} \
            FORMATAISA=${FORMATAISA} \
            NUM_WORKER=${NUM_WORKER} ./full_cycle_minitest_query.sh 
        done
    done
done
        


