#!/bin/bash

set -e 
# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}

# Load parameters - common
DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_NAME=${DATABASE_NAME:-benchmark}
DATABASE_HOST=${DATABASE_HOST:-test217}
DATABASE_PWD=${DATABASE_PWD:-password}
NUM_WORKERS=${NUM_WORKERS:-"24"} 
BATCH_SIZES=${load_batch_size} 
SERVER_PASSWORD=${SERVER_PASSWORD:-123456}
CASE_TYPE=${CASE_TYPE:-"cputest"} 
WALFSYNCPERIOD=${WALFSYNCPERIOD:-"0"}
TRIGGER=${TRIGGER:-"8"} 
VGROUPS=${VGROUPS:-"24"}


# Ensure DATA DIR available
mkdir -p ${BULK_DATA_DIR}
chmod a+rwx ${BULK_DATA_DIR}

datadir_space=`du ${BULK_DATA_DIR} -s |awk '{print $1}'  `
echo ${BULK_DATA_DIR} "disk usage is" ${datadir_space}
if [ ${datadir_space} -lt 30000  ];then
    rm -rf ${BULK_DATA_DIR}/*
else
    echo "data dir is not empty, it starts to load data"
fi

rm -rf ${BULK_DATA_DIR_RES_LOAD}/*

for USE_CASE in ${USE_CASES}; do
    for FORMAT in ${FORMATS}; do
        for SCALE in ${SCALES};do
            if  [[ ${CASE_TYPE} != "userdefined" ]];then
                echo ${SCALE}
                if [  ${SCALE} -eq 100 ];then
                    TS_END="2016-01-03T00:00:00Z"
                    CHUNK_TIME="6h"
                    echo "generate 1 month data"
                elif [ ${SCALE} -eq 4000 ];then
                    TS_END="2016-01-03T00:00:00Z"
                    CHUNK_TIME="6h"
                    echo "generate 4 days data"
                elif [ ${SCALE} -eq 100000 ] ;then
                    TS_END="2016-01-01T03:00:00Z"
                    CHUNK_TIME="15m"
                    echo "generate 3 hours data"
                elif [ ${SCALE} -eq 1000000 ] ||  [ ${SCALE} -eq 10000000 ];then
                    TS_END="2016-01-01T00:03:00Z"
                    CHUNK_TIME="15s"
                    echo "generate 3 min data"
                else
                    TS_END=${TS_END:-"2016-01-02T00:00:00Z"}
                    echo "generate input data"
                    CHUNK_TIME="12h"
                fi
            else
                TS_END=${TS_END:-"2016-01-02T00:00:00Z"}
                echo "generate input data"
                CHUNK_TIME="12h"
            fi
            if [ ${USE_CASE} == "iot" ];then
                VGROUPS="12"
            fi
            for BATCH_SIZE in ${BATCH_SIZES};do 
                for NUM_WORKER in ${NUM_WORKERS};do
                    echo `date +%Y_%m%d_%H%M%S`
                    echo " TS_START=${TS_START}  TS_END=${TS_END}   DATABASE_USER=${DATABASE_USER} DATABASE_HOST=${DATABASE_HOST}  DATABASE_PWD=${DATABASE_PWD} DATABASE_NAME=${DATABASE_NAME} SCALE=${SCALE} FORMAT=${FORMAT} USE_CASE=${USE_CASE} BATCH_SIZE=${BATCH_SIZE}  NUM_WORKER=${NUM_WORKER} CHUNK_TIME=${CHUNK_TIME} SERVER_PASSWORD=${SERVER_PASSWORD}  BULK_DATA_DIR=${BULK_DATA_DIR}  BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} WALFSYNCPERIOD=${WALFSYNCPERIOD} VGROUPS=${VGROUPS} ./full_cycle_minitest_loading.sh " 
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
done



