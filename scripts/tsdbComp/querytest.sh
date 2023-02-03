#!/bin/bash

set -e 

# Data folder
BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR:-"/tmp/bulk_queries/"}
BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES:-"/tmp/bulk_result_query/"}

BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}

# cleat data
rm -rf ${BULK_DATA_QUERY_DIR}/*
rm -rf ${BULK_DATA_DIR_RUN_RES}/*


# common paramaters
DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_NAME=${DATABASE_NAME:-benchmark}
DATABASE_HOST=${DATABASE_HOST:-test217}
DATABASE_PORT=${DATABASE_PORT:-5432}
DATABASE_PWD=${DATABASE_PWD:-password}
DATABASE_INF_PORT=${DATABASE_INF_PORT:-8086}


# Space-separated list of target DB formats to generate
FORMATS=${FORMATS:-"timescaledb influx"}

# Load paramaters
SCALE=${SCALE:-"100"}
SEED=${SEED:-"123"}
NUM_WORKER_LOAD=${NUM_WORKER_LOAD:-"12"} 
BATCH_SIZE=${BATCH_SIZE:-"50000"} 

#reset loading data
RESTLOAD=${RESTLOAD:-"true"}

# # All available for generation query types (sorted alphabetically)
#  QUERY_TYPES_ALL=${QUERY_TYPES_ALL:-"\
#  single-groupby-1-1-1 \
#  single-groupby-1-1-12 \
#  single-groupby-1-8-1 \
#  single-groupby-5-1-1 \
#  single-groupby-5-1-12 \
#  single-groupby-5-8-1 \
#  cpu-max-all-1 \
#  cpu-max-all-8 \
#  double-groupby-1 \
#  double-groupby-5 \
#  double-groupby-all \
#  high-cpu-1 \
#  high-cpu-all \
#  groupby-orderby-limit \
#  lastpoint "}



# QUERY_TYPES_ALL=${QUERY_TYPES_ALL:-"\
#  single-groupby-1-1-1 \
#  single-groupby-1-1-12 \
#  single-groupby-1-8-1 \
#  single-groupby-5-1-1 \
#  single-groupby-5-1-12 \
#  single-groupby-5-8-1 \
#  cpu-max-all-1 \
#  cpu-max-all-8 "}

QUERY_TYPES_ALL=${QUERY_TYPES_ALL:-"\
single-groupby-1-8-1 \
single-groupby-5-8-1 \
single-groupby-5-1-12  "}


#QUERY_TYPES_ALL=${QUERY_TYPES_ALL:-"\
#lastpoint "}

QUERY_TYPES_IOT_ALL=${QUERY_TYPES_IOT_ALL:-"\
daily-activity \
breakdown-frequency \
avg-vs-projected-fuel-consumption \
avg-daily-driving-duration \
avg-load \
last-loc \
low-fuel \
high-load \
stationary-trucks \
long-driving-sessions \
long-daily-sessions "}     


# QUERY_TYPES_IOT_ALL=${QUERY_TYPES_IOT_ALL:-"\
# last-loc"}     

#last-loc \
#low-fuel \
#high-load \

# avg-daily-driving-session \

# Number of queries to generate
QUERIES=${QUERIES:-"100"}

# Start and stop time for generated timeseries
TS_START=${TS_START:-"2016-01-01T00:00:00Z"}
QUERY_TS_END=${QUERY_TS_END:-"2016-01-02T00:00:01Z"}
LOAD_TS_END=${LOAD_TS_END:-"2016-01-02T00:00:00Z"}

# What set of data to generate: devops (multiple data), cpu-only (cpu-usage data)
# USE_CASES=${USE_CASES:-"cpu-only devops iot"}
USE_CASES=${USE_CASES:-"devops"}

# How many concurrent worker would run queries - match num of cores, or default to 16
NUM_WORKERS=${NUM_WORKERS:-"24"} 
QUERY_DEBUG=${QUERY_DEBUG:-"false"} 
CHUNK_TIME=${CHUNK_TIME:-"12h"}



# testcase : 
for FORMAT in ${FORMATS}; do
    if [[  ${FORMAT} == "timescaledb10" ]];then
        CHUNK_TIME="74.4h"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[  ${FORMAT} == "timescaledb100" ]];then
        CHUNK_TIME="446m"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[  ${FORMAT} == "timescaledb1k" ]];then
        CHUNK_TIME="45m"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[ ${FORMAT} == "timescaledb1w" ]];then
        CHUNK_TIME="4m"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[ ${FORMAT} == "timescaledb10w" ]];then
        CHUNK_TIME="27s"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[ ${FORMAT} == "timescaledb36" ]];then
        CHUNK_TIME="5m"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[ ${FORMAT} == "timescaledb12" ]];then
        CHUNK_TIME="15m"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[ ${FORMAT} == "timescaledb8" ]];then
        CHUNK_TIME="23m"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[ ${FORMAT} == "timescaledb6" ]];then
        CHUNK_TIME="30m"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    elif [[ ${FORMAT} == "timescaledb4" ]];then
        CHUNK_TIME="45m"
        FORMATAISA=${FORMAT}
        FORMAT="timescaledb"
    fi
    
    FORMATAISA=${FORMATAISA:-"timescaledb"}
    for USE_CASE in ${USE_CASES}; do
        for SCALE in ${SCALES};do 
            if [ ${RESTLOAD} == "true" ] ;then
                echo ${SCALE}
                echo " DATABASE_HOST=${DATABASE_HOST} SCALE=${SCALE} FORMAT=${FORMAT} USE_CASE=${USE_CASE} BATCH_SIZE=${BATCH_SIZE}  NUM_WORKER=${NUM_WORKER_LOAD} BULK_DATA_DIR=${BULK_DATA_DIR} TS_END=${LOAD_TS_END} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} DATABASE_NAME=${DATABASE_NAME} CHUNK_TIME=${CHUNK_TIME} SERVER_PASSWORD=${SERVER_PASSWORD}   FORMATAISA=${FORMATAISA} ./full_cycle_minitest_query_loading.sh "
                DATABASE_HOST=${DATABASE_HOST} SCALE=${SCALE} FORMAT=${FORMAT} USE_CASE=${USE_CASE} BATCH_SIZE=${BATCH_SIZE}  NUM_WORKER=${NUM_WORKER_LOAD} BULK_DATA_DIR=${BULK_DATA_DIR} TS_END=${LOAD_TS_END} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} DATABASE_NAME=${DATABASE_NAME} CHUNK_TIME=${CHUNK_TIME} SERVER_PASSWORD=${SERVER_PASSWORD}  FORMATAISA=${FORMATAISA}   ./full_cycle_minitest_query_loading.sh
            else
                echo "data has been loaded in all database"
            fi
            # if [ ${FORMAT}== "TDengine" ];then
            #     taos -d benchmarkcpu -h test209 -s "show benchmarkcpu.vgroups;"
            #     taos -d benchmarkcpu -h test209 -s "compact vnodes in (3);"
            #     sleep 10
            #     taos -d benchmarkcpu -h test209 -s "show benchmarkcpu.vgroups;"
            # fi
            echo `date +%Y_%m%d_%H%M%S`
            sleep 10s
            if [ ${USE_CASE} != "iot" ] ;then
                QUERY_TYPES=${QUERY_TYPES_ALL}
            else
                QUERY_TYPES=${QUERY_TYPES_IOT_ALL}
            fi
            #  restart taosd

            if [  ${FORMAT} == "TDengine" ];then
                echo `date +%Y_%m%d_%H%M%S`":restart taosd and checck taosd status "
                sshpass -p ${SERVER_PASSWORD}  ssh  root@$DATABASE_HOST "systemctl restart taosd && systemctl status taosd --no-pager  && sleep 5 && exit "
                sleep 5
            fi

            for QUERY_TYPE in ${QUERY_TYPES}; do
                for NUM_WORKER in ${NUM_WORKERS}; do
                    echo " DATABASE_HOST=${DATABASE_HOST} BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR} BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES}  TS_START=${TS_START}  TS_END=${QUERY_TS_END} QUERIES=${QUERIES} FORMAT=${FORMAT} USE_CASE=${USE_CASE} QUERY_TYPE=${QUERY_TYPE} SCALE=${SCALE} FORMATAISA=${FORMATAISA}  NUM_WORKER=${NUM_WORKER} ./full_cycle_minitest_query.sh "
                    DATABASE_HOST=${DATABASE_HOST} \
                    BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR} \
                    BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
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
    done
done
        


