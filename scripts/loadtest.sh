#!/bin/bash

set -e 
# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}

# Space-separated list of target DB formats to generate
FORMATS=${FORMATS:-"timescaledb influx"}

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

rm -rf ${BULK_DATA_DIR}/*
rm -rf ${BULK_DATA_DIR_RES_LOAD}/*


for FORMAT in ${FORMATS}; do
    for USE_CASE in ${USE_CASES}; do
        for SCALE in ${SCALES};do 
            for BATCH_SIZE in ${BATCH_SIZES};do 
                for NUM_WORKER in ${NUM_WORKERS};do
                    echo "" DATABASE_HOST=${DATABASE_HOST} SCALE=${SCALE} FORMAT=${FORMAT} USE_CASE=${USE_CASE} BATCH_SIZE=${BATCH_SIZE} NUM_WORKER=${NUM_WORKER} ./full_cycle_minitest_loading.sh
                   TS_START=${TS_START} \
                   TS_END=${TS_END} \
                   DATABASE_USER=${DATABASE_USER} \
                   DATABASE_HOST=${DATABASE_HOST} \
                   DATABASE_PWD=${DATABASE_PWD} \
                   SCALE=${SCALE} \
                   FORMAT=${FORMAT} \
                   USE_CASE=${USE_CASE} \
                   BATCH_SIZE=${BATCH_SIZE}  \
                   NUM_WORKER=${NUM_WORKER} \
                   BULK_DATA_DIR=${BULK_DATA_DIR} \
                   BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} ./full_cycle_minitest_loading.sh
                done
            done
        done
    done
done

