#!/bin/bash

set -e 
# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}

# Space-separated list of target DB formats to generate
FORMATS=${FORMATS:-"timescaledb influx TDengine"}

# Number of hosts to generate data about
SCALES=${SCALES:-"100"}

# Rand seed
SEED=${SEED:-"123"}

# Start and stop time for generated timeseries
TS_START=${TS_START:-"2016-01-01T00:00:00Z"}
TS_END=${TS_END:-"2016-01-02T00:00:00Z"}

# What set of data to generate: devops (multiple data), cpu-only (cpu-usage data)
# USE_CASES=${USE_CASES:-"cpu-only devops iot"}
USE_CASES=${USE_CASES:-"cpu-only devops iot"}

# Step to generate data
LOG_INTERVAL=${LOG_INTERVAL:-"10s"}

# Max number of points to generate data. 0 means "use TS_START TS_END with LOG_INTERVAL"
MAX_DATA_POINTS=${MAX_DATA_POINTS:-"0"}

# Load parameters - common
DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_NAME=${DATABASE_NAME:-benchmark}
DATABASE_HOST=${DATABASE_HOST:-test217}
DATABASE_PWD=${DATABASE_PWD:-password}
NUM_WORKERS=${NUM_WORKERS:-"24"} 
BATCH_SIZES=${BATCH_SIZES:-"10000"} 
SERVER_PASSWORD=${SERVER_PASSWORD:-123456}
CASE_TYPE=${CASE_TYPE:-"cputest"} 
WALFSYNCPERIOD=${WALFSYNCPERIOD:-"0"}
TRIGGER=${TRIGGER:-"8"} 
VGROUPS=${VGROUPS:-"24"}

# worklen=`echo  ${NUM_WORKERS}| awk  '{print NF}' `
# batchlen=`echo  ${BATCH_SIZES}| awk  '{print NF}' `
# scalelen=`echo  ${SCALES}| awk  '{print NF}' `

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
                    TS_END="2016-02-01T00:00:00Z"
                    CHUNK_TIME="62h"
                    echo "generate 1 month data"
                elif [ ${SCALE} -eq 4000 ];then
                    TS_END="2016-01-05T00:00:00Z"
                    CHUNK_TIME="8h"
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



