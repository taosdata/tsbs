#!/bin/bash

set -e 
scriptDir=$(dirname $(readlink -f $0))
cd ${scriptDir}
source ${scriptDir}/common.sh
source ${scriptDir}/logger.sh

# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}
# Load parameters - common
DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_PWD=${DATABASE_PWD:-password}

# Ensure DATA DIR available
mkdir -p ${BULK_DATA_DIR}
chmod a+rwx ${BULK_DATA_DIR}

datadir_space=`du ${BULK_DATA_DIR} -s |awk '{print $1}'  `
log_debug ${BULK_DATA_DIR} "disk usage is" ${datadir_space}
if [ ${datadir_space} -lt 30000  ];then
    log_warning "Data directory space is insufficient! Current available space: ${datadir_space}. Cleaning up data directory: ${BULK_DATA_DIR}"
    rm -rf ${BULK_DATA_DIR}/*
else
    log_debug "Data directory has enough space. It starts to load data"
fi

rm -rf ${BULK_DATA_DIR_RES_LOAD}/*
# Define an associative array for SCALE to TS_END and CHUNK_TIME mapping
declare -A scale_map=(
    [100]="2016-01-03T00:00:00Z 6h generate 1 month data"
    [4000]="2016-01-03T00:00:00Z 6h generate 4 days data"
    [100000]="2016-01-01T03:00:00Z 15m generate 3 hours data"
    [1000000]="2016-01-01T00:03:00Z 15s generate 3 min data"
    [10000000]="2016-01-01T00:03:00Z 15s generate 3 min data"
)
for FORMAT in ${FORMATS}; do
    for SCALE in ${SCALES};do
        if [[ ${CASE_TYPE} != "userdefined" ]]; then
            log_debug "SCALE: ${SCALE}"
            if [[ -n "${scale_map[$SCALE]}" ]]; then
                IFS=' ' read -r TS_END CHUNK_TIME MESSAGE <<< "${scale_map[$SCALE]}"
                log_debug "${MESSAGE}"
            else
                TS_END=${TS_END:-"2016-01-02T00:00:00Z"}
                log_debug "generate input data"
                CHUNK_TIME="12h"
            fi
        else
            TS_END=${TS_END:-"2016-01-02T00:00:00Z"}
            log_debug "generate input data"
            CHUNK_TIME="12h"
        fi
        log_debug "TS_END=${TS_END}  CHUNK_TIME=${CHUNK_TIME}"

        if [ ${USE_CASE} == "iot" ];then
            VGROUPS="12"
        fi
        for BATCH_SIZE in ${BATCH_SIZES};do 
            for NUM_WORKER in ${NUM_WORKERS};do
                log_debug " TS_START=${TS_START}  TS_END=${TS_END}   DATABASE_USER=${DATABASE_USER} DATABASE_HOST=${DATABASE_HOST}  DATABASE_PWD=${DATABASE_PWD} DATABASE_NAME=${DATABASE_NAME} SCALE=${SCALE} FORMAT=${FORMAT} USE_CASE=${USE_CASE} BATCH_SIZE=${BATCH_SIZE}  NUM_WORKER=${NUM_WORKER} CHUNK_TIME=${CHUNK_TIME} SERVER_PASSWORD=${SERVER_PASSWORD}  BULK_DATA_DIR=${BULK_DATA_DIR}  BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} WALFSYNCPERIOD=${WALFSYNCPERIOD} VGROUPS=${VGROUPS} ./full_cycle_minitest_loading.sh " 
                TS_START=${TS_START} \
                TS_END=${TS_END} \
                DATABASE_USER=${DATABASE_USER} \
                DATABASE_HOST=${DATABASE_HOST} \
                DATABASE_PWD=${DATABASE_PWD} \
                DATABASE_NAME=${DATABASE_NAME} \
                SCALE=${SCALE} \
                FORMAT=${FORMAT} \
                USE_CASE=${USE_CASE} \
                BATCH_SIZE=${BATCH_SIZE}  \
                NUM_WORKER=${NUM_WORKER} \
                CHUNK_TIME=${CHUNK_TIME} \
                SERVER_PASSWORD=${SERVER_PASSWORD} \
                BULK_DATA_DIR=${BULK_DATA_DIR} \
                CASE_TYPE=${CASE_TYPE} \
                BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
                WALFSYNCPERIOD=${WALFSYNCPERIOD} \
                VGROUPS=${VGROUPS} \
                TRIGGER=${TRIGGER} ./full_cycle_minitest_loading.sh
                sleep 60s
            done
        done
    done
done