#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution

scriptDir=$(dirname $(readlink -f $0))
source ${scriptDir}/common.sh
source ${scriptDir}/logger.sh

# Step to generate data
LOG_INTERVAL=${LOG_INTERVAL:-"10s"}
# Max number of points to generate data. 0 means "use TS_START TS_END with LOG_INTERVAL"
MAX_DATA_POINTS=${MAX_DATA_POINTS:-"0"}
# Rand seed
SEED=${SEED:-"123"}
# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
# TDneing Databases: Vgroups
VGROUPS=${VGROUPS:-"6"}
BUFFER=${BUFFER:-"512"}
PAGES=${PAGES:-"4096"}
# Load parameters - common
DATABASE_PWD=${DATABASE_PWD:-password}
DATABASE_TAOS_PWD=${DATABASE_TAOS_PWD:-taosdata}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}
TRIGGER=${trigger:-"1"} 

log_info "start to load ${USE_CASE} data into ${FORMATAISA}, with BATCH_SIZE: ${BATCH_SIZE}, NUM_WORKER: ${NUM_WORKER}, SCALE: ${SCALE}"
# - 1) data  generation
log_info "===============data generation================="
log_info "Generating data for ${USE_CASE} into ${FORMAT}, with scale ${SCALE}, seed ${SEED}, log interval ${LOG_INTERVAL}"
# Ensure DATA DIR available
mkdir -p ${BULK_DATA_DIR}
chmod a+rwx ${BULK_DATA_DIR}
clientHost=`hostname`

set -eo pipefail
# generate data
INSERT_DATA_FILE_NAME="data_${FORMAT}_${USE_CASE}_scale${SCALE}_${TS_START}_${TS_END}_interval${LOG_INTERVAL}_${SEED}.dat.gz"
if [ -f "${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}" ]; then
    log_warning "WARNING: file ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME} already exists, skip generating new data"
else
    cleanup() {
        rm -f ${INSERT_DATA_FILE_NAME}
        exit 1
    }
    trap cleanup EXIT

    EXE_FILE_NAME_GENERATE_DATA=$(which tsbs_generate_data)
    if [[ -z "${EXE_FILE_NAME_GENERATE_DATA}" ]]; then
        log_error "tsbs_generate_data not available. It is not specified explicitly and not found in \$PATH"
        exit 1
    fi
    log_info "Generating ${INSERT_DATA_FILE_NAME}:"
    log_debug "${EXE_FILE_NAME_GENERATE_DATA} \
        --format ${FORMAT} \
        --use-case ${USE_CASE} \
        --scale ${SCALE} \
        --timestamp-start ${TS_START} \
        --timestamp-end ${TS_END} \
        --seed ${SEED} \
        --log-interval ${LOG_INTERVAL} \
        --max-data-points ${MAX_DATA_POINTS} \
     | gzip > ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}"
    ${EXE_FILE_NAME_GENERATE_DATA} \
        --format ${FORMAT} \
        --use-case ${USE_CASE} \
        --scale ${SCALE} \
        --timestamp-start ${TS_START} \
        --timestamp-end ${TS_END} \
        --seed ${SEED} \
        --log-interval ${LOG_INTERVAL} \
        --max-data-points ${MAX_DATA_POINTS} \
     | gzip > ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}
    trap - EXIT
fi

# - 2) data loading/insertion
log_info "===============data loading/insertion================="
mkdir -p ${BULK_DATA_DIR_RES_LOAD} || log_warning "file exists"
cd ${scriptDir}

log_info "---------------  Clean  -----------------"
run_command "echo 1 > /proc/sys/vm/drop_caches"

if [[ `echo $CHUNK_TIME|grep h` != "" ]];then
    tempChunk=$(echo $CHUNK_TIME|grep h | sed -e 's/h$//')
    chunkTimeInter=`echo "scale=3;${tempChunk}*3600"|bc`
    compressChunkTime="$(echo $CHUNK_TIME|grep h | sed -e 's/h$//') hours"
elif [[ `echo $CHUNK_TIME|grep m` != "" ]];then
    tempChunk=$(echo $CHUNK_TIME|grep m | sed -e 's/m$//')
    chunkTimeInter=`echo "scale=3;${tempChunk}*60"|bc`
    compressChunkTime="$(echo $CHUNK_TIME|grep m | sed -e 's/m$//') minutes"
elif [[ `echo $CHUNK_TIME|grep s` != "" ]];then
    chunkTimeInter=$(echo $CHUNK_TIME|grep s | sed -e 's/s$//')
    compressChunkTime="$(echo $CHUNK_TIME|grep s | sed -e 's/s$//') seconds"
elif [[ `echo $CHUNK_TIME|grep d` != "" ]];then
    tempChunk=$(echo $CHUNK_TIME|grep d | sed -e 's/d$//')
    chunkTimeInter=`echo "scale=3;${tempChunk}*3600*24"|bc`
    compressChunkTime="$(echo $CHUNK_TIME|grep d | sed -e 's/d$//') days"
fi


# use different load scripts of db to load data , add supported databases 
if [[ "${SCALE}" == "100" ]];then
    VGROUPS="1"
elif  [[ "${SCALE}" == "4000" ]];then
    VGROUPS="6"
fi

if [[ "${FORMAT}" =~ "timescaledb" ]];then
    TimePath=${timescaledb_data_dir-"/var/lib/postgresql/14/main/base/"}
    run_command "
    systemctl restart postgresql
    sleep 1"

    sleep 1
    PGPASSWORD=${DATABASE_PWD} psql -U postgres -h $DATABASE_HOST  -d postgres -c "drop database IF EXISTS  ${DATABASE_NAME} "
    if [ -d "${TimePath}" ]; then
        disk_usage_before=`set_command "du -s ${TimePath} --exclude="pgsql_tmp" | cut -f 1 " `
    else
        disk_usage_before=0
    fi
   
    log_debug "Starting to load ${USE_CASE} data into ${FORMAT}, with BATCH_SIZE: ${BATCH_SIZE}, NUM_WORKER: ${NUM_WORKER}, SCALE: ${SCALE}"
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    log_debug "cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD} --chunk-time=${CHUNK_TIME} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD}  --chunk-time=${CHUNK_TIME} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    if [ "${USE_CASE}" == "cpu-only" ];then
        PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME} -h ${DATABASE_HOST} -c "SELECT chunk_name, is_compressed FROM timescaledb_information.chunks WHERE is_compressed = true" > tempCompress.txt
        tempCompressNum=`more tempCompress.txt |grep rows |awk -F ' ' '{print $1}'`
        log_debug "${FORMAT} tempCompressNum: ${tempCompressNum}"
        if [ "${tempCompressNum}" == "(0" ] ;then
            PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "ALTER TABLE cpu SET (timescaledb.compress, timescaledb.compress_orderby = 'time DESC,usage_user',  timescaledb.compress_segmentby = 'tags_id');"
            # hostname in  tags  can't be set and it reports ERROR:  unrecognized parameter namespace "timescaledb".
            # PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "ALTER TABLE tags SET (timescaledb.compress, timescaledb.compress_segmentby = 'hostname');"  
            log_debug "$(date +%Y_%m%d_%H%M%S):start to add compression policy"
            log_debug "compressed SQL: SELECT add_compression_policy('cpu', INTERVAL '${compressChunkTime}')"
            PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "SELECT add_compression_policy('cpu', INTERVAL '${compressChunkTime}' );"
        else
            log_warning "it has already been enabled native compression on TimescaleDB,"
        fi
        while true
        do   
            tempCompressNum=$(PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME} -h ${DATABASE_HOST} -c "SELECT chunk_name, is_compressed FROM timescaledb_information.chunks WHERE is_compressed = true" |grep row |awk  '{print $1}')
            disk_usage_after=`set_command "du -s ${TimePath} --exclude="pgsql_tmp"| cut -f 1 " `
        
            timesdiffSec=$(( $(date +%s -d ${TS_END}) - $(date +%s -d ${TS_START}) ))
            # echo "chunkTimeSeconds:${chunkTimeInter}"
            timesHours=`echo "scale=3;${timesdiffSec}/${chunkTimeInter}"|bc`
            timesHours1=`ceil $timesHours`
            timesHours2=`floor $timesHours`
            log_debug "Compression count: ${tempCompressNum}, disk usage after load: ${disk_usage_after}, expected compressed data Block count :${timesHours},${timesHours1},${timesHours2}"
            if [[ "${tempCompressNum}" == "(${timesHours1}" ]] || [[ "${tempCompressNum}" == "(${timesHours2}" ]] ;then
                log_debug "com${timesHours},${tempCompressNum}"
                log_debug "$(date +%Y_%m%d_%H%M%S): complete  compression"
                break
            fi
        done
    fi
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    disk_usage_after=`set_command "du -s ${TimePath} --exclude="pgsql_tmp"| cut -f 1 " `
    log_debug "${disk_usage_before} ${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    log_debug "${FORMATAISA},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage}"
    echo ${FORMATAISA},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
elif [  ${FORMAT} == "influx" ] || [  ${FORMAT} == "influx3" ]; then
    load_command="tsbs_load_${FORMAT}"
    if [  ${FORMAT} == "influx" ]; then
        run_command "
        systemctl restart influxd
        sleep 1" 
        InfPath=${influx_data_dir-"/var/lib/influxdb/"}
        InfPath=$InfPath/data
        DATABASE_PORT=${influx_port:-8086}
    elif [  ${FORMAT} == "influx3" ]; then
        InfPath=${influx3_data_dir-"/var/lib/influxdb3/"}
        InfLogPath=${InfPath}/influxdb3.log
        InfPath=$InfPath/tsbs_test_data
        DATABASE_PORT=${influx3_port:-8181}
        set -v
        run_command "
        pkill -9 influxdb3 || true
        mkdir -p ${InfPath}
        rm -rf ${InfPath}/*
        nohup ~/.influxdb/influxdb3 serve --node-id=local01 --object-store=file --data-dir ${InfPath} --http-bind=0.0.0.0:${DATABASE_PORT} >> ${InfLogPath} 2>&1 &
        "
        set +v
        # check if influxdb3 is running
        if ! run_command "check_influxdb3_status ${DATABASE_PORT}"; then
            log_error "influxdb3 failed to start"
            exit 1
        fi
    fi
    log_debug "COMMAND:${load_command} USE_CASE:${USE_CASE} FORMAT:${FORMAT} SCALE:${SCALE} InfPath:${InfPath} DATABASE_PORT:${DATABASE_PORT}" 
    if [ -d "${InfPath}" ]; then
        disk_usage_before=`set_command "du -s ${InfPath} | cut -f 1 " `
    else
        disk_usage_before=0
    fi

    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    log_debug "cat  ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip |  ${load_command}  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME} | gunzip |   ${load_command}  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    disk_usage_after=`set_command "du -s ${InfPath} | cut -f 1 " `
    log_debug "${disk_usage_before},${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    log_debug "${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage}"
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
elif [  ${FORMAT} == "TDengine" ] || [  ${FORMAT} == "TDengineStmt2" ]; then
    TDPath=${tdengine_data_dir:-"/var/lib/taos/"}
    DATABASE_PORT=${tdengine_port:-6030}
    log_debug "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "SCALE":${SCALE} "DATABASE_PORT":${DATABASE_PORT}
    if [  ${FORMAT} == "TDengine" ]; then
        load_commond="tsbs_load_tdengine"
    elif [ ${FORMAT} == "TDengineStmt2"  ]; then
        load_commond="tsbs_load_tdenginestmt2"
    fi
    
    run_command "
    echo `date +%Y_%m%d_%H%M%S`\": reset limit\"
    systemctl reset-failed taosd.service
    sleep 5
    echo `date +%Y_%m%d_%H%M%S`\":restart taosd \"
    systemctl restart taosd
    sleep 5
    echo `date +%Y_%m%d_%H%M%S`\":check status of taosd \"
    systemctl status taosd
    echo `date +%Y_%m%d_%H%M%S`\":restart successfully\" "
    
    if [ -d "${TDPath}" ]; then
        disk_usage_before=`set_command "du -s ${TDPath}/vnode | cut -f 1 " `
    else
        disk_usage_before=0
    fi

    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    log_debug " cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |  ${load_commond}  --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE}  --vgroups=${VGROUPS}  --buffer=${BUFFER} --pages=${PAGES} --hash-workers=true --stt_trigger=${TRIGGER}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |   ${load_commond} \
    --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} --pass=${DATABASE_TAOS_PWD} --port=${DATABASE_PORT}  --vgroups=${VGROUPS}  --buffer=${BUFFER} --pages=${PAGES} --hash-workers=true  --stt_trigger=${TRIGGER}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    taos -h $DATABASE_HOST -s "alter database ${DATABASE_NAME} cachemodel 'last_row'  cachesize 200 ;"
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    taos -h  ${DATABASE_HOST} -s  "flush database ${DATABASE_NAME};"
    disk_usage_after=`set_command "du -s ${TDPath}/vnode | cut -f 1 " `
    log_debug "${disk_usage_before},${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    log_debug "${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage}"
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv    
else
    log_error "The format is not supported"
fi  


