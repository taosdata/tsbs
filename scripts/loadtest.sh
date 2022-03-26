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

worklen=`echo  ${NUM_WORKERS}| awk  '{print NF}' `
batchlen=`echo  ${BATCH_SIZES}| awk  '{print NF}' `
scalelen=`echo  ${SCALES}| awk  '{print NF}' `


# rm -rf ${BULK_DATA_DIR}/*
rm -rf ${BULK_DATA_DIR_RES_LOAD}/*

for USE_CASE in ${USE_CASES}; do
    for FORMAT in ${FORMATS}; do
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

# generate png report
# loadResultAnaly.py has three parameter,
# 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
if [ ${worklen} != 1 ];then 
    echo "python3 loadResultAnaly.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv NUM_WORKER ${BULK_DATA_DIR_RES_LOAD}/test_load_${USE_CASE}_${BATCH_SIZES}.png"
    python3 loadResultAnaly.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv NUM_WORKER ${BULK_DATA_DIR_RES_LOAD}/test_load_${USE_CASE}_${BATCH_SIZES}.png
elif [ ${batchlen} != 1 ];then 
    echo "python3 loadResultAnaly.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv BATCH_SIZE ${BULK_DATA_DIR_RES_LOAD}/test_load_${USE_CASE}_${SCALES}.png"
    python3 loadResultAnaly.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv BATCH_SIZE ${BULK_DATA_DIR_RES_LOAD}/test_load_${USE_CASE}_${SCALES}.png
elif [ ${scalelen} != 1 ];then 
    echo "python3 loadResultAnaly.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_${USE_CASE}_${NUM_WORKERS}.png"
    python3 loadResultAnaly.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_${USE_CASE}_${NUM_WORKERS}.png  
fi  



