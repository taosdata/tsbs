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
    log_debug "Data directory space is insufficient! Current available space: ${datadir_space}. Cleaning up data directory: ${BULK_DATA_DIR}"
    rm -rf ${BULK_DATA_DIR}/*
else
    log_debug "Data directory has enough space. It starts to load data"
fi

rm -rf ${BULK_DATA_DIR_RES_LOAD}/*
# Define an associative array for SCALE to TS_END and CHUNK_TIME mapping
eval "declare -A scale_map=${TIME_SCALE_STR#*=}"
for FORMAT in ${FORMATS}; do
    for SCALE in ${SCALES};do
        if [[ ${CASE_TYPE} != "userdefined" ]]; then
            log_debug "SCALE: ${SCALE}"
            if [[ -n "${scale_map[$SCALE]}" ]]; then
                IFS=' ' read -r TS_START TS_END LOG_INTERVAL <<< "${scale_map[$SCALE]}"
            fi
            TS_START=${TS_START:-"2016-01-01T00:00:00Z"}
            TS_END=${TS_END:-"2016-01-01T00:03:00Z"}
            LOG_INTERVAL=${LOG_INTERVAL:-"10s"}
        else
            TS_START="2016-01-01T00:00:00Z"
            TS_END=${TS_END:-"2016-01-02T00:00:00Z"}
            LOG_INTERVAL="10s"
        fi
        CHUNK_TIME=$(calculate_chunk_time "$TS_START" "$TS_END")
        log_debug "TS_START=${TS_START} TS_END=${TS_END}  LOG_INTERVAL=${LOG_INTERVAL} CHUNK_TIME=${CHUNK_TIME}"

        if [ ${USE_CASE} == "iot" ];then
            VGROUPS="12"
        fi
        for BATCH_SIZE in ${BATCH_SIZES};do 
            for NUM_WORKER in ${NUM_WORKERS};do
                for i in `seq 1 ${HORIZONTAL_SCALING_FACTOR}`;do
                    log_debug "TS_START=${TS_START}  TS_END=${TS_END}  \
                        DATABASE_HOST=${DATABASE_HOST}  SERVER_PASSWORD=${SERVER_PASSWORD} \
                        DATABASE_USER=${DATABASE_USER}  DATABASE_PWD=${DATABASE_PWD} DATABASE_NAME=${DATABASE_NAME} \
                        SCALE=${SCALE} FORMAT=${FORMAT} USE_CASE=${USE_CASE} BATCH_SIZE=${BATCH_SIZE}  NUM_WORKER=${NUM_WORKER} CHUNK_TIME=${CHUNK_TIME} \
                        BULK_DATA_DIR=${BULK_DATA_DIR}  BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
                        WALFSYNCPERIOD=${WALFSYNCPERIOD} VGROUPS=${VGROUPS}" 

                    export TS_START=${TS_START} 
                    export TS_END=${TS_END} 
                    export DATABASE_USER=${DATABASE_USER} 
                    export DATABASE_HOST=${DATABASE_HOST} 
                    export DATABASE_PWD=${DATABASE_PWD} 
                    export DATABASE_NAME=${DATABASE_NAME} 
                    export SCALE=${SCALE} 
                    export FORMAT=${FORMAT} 
                    export USE_CASE=${USE_CASE} 
                    export BATCH_SIZE=${BATCH_SIZE}  
                    export NUM_WORKER=${NUM_WORKER} 
                    export CHUNK_TIME=${CHUNK_TIME} 
                    export LOG_INTERVAL=${LOG_INTERVAL} 
                    export SERVER_PASSWORD=${SERVER_PASSWORD} 
                    export BULK_DATA_DIR=${BULK_DATA_DIR} 
                    export CASE_TYPE=${CASE_TYPE} 
                    export BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} 
                    export WALFSYNCPERIOD=${WALFSYNCPERIOD} 
                    export VGROUPS=${VGROUPS} 
                    export TRIGGER=${TRIGGER} 
                    ./full_cycle_minitest_loading.sh
                    #sleep 60s
                    TS_END="$(double_ts_end $TS_END)"
                    CHUNK_TIME=$(calculate_chunk_time "$TS_START" "$TS_END")
                done
            done
        done
    done
done