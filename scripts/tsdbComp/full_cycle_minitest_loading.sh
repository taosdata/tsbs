#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution

scriptDir=$(dirname $(readlink -f $0))
source ${scriptDir}/common.sh
source ${scriptDir}/logger.sh

log_info "Start to load ${USE_CASE} data into ${FORMATAISA}, with BATCH_SIZE: ${BATCH_SIZE}, NUM_WORKER: ${NUM_WORKER}, SCALE: ${SCALE}"
# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
TDPath=${TDPath:-"/var/lib/taos/"}
InfPath=${InfPath-"/var/lib/influxdb/data/"}
TimePath="/var/lib/postgresql/14/main/base/"

# Step to generate data
LOG_INTERVAL=${LOG_INTERVAL:-"10s"}
# Max number of points to generate data. 0 means "use TS_START TS_END with LOG_INTERVAL"
MAX_DATA_POINTS=${MAX_DATA_POINTS:-"0"}
# Rand seed
SEED=${SEED:-"123"}

# Ensure DATA DIR available
mkdir -p ${BULK_DATA_DIR}
chmod a+rwx ${BULK_DATA_DIR}
clientHost=`hostname`
log_debug "clientHost:${clientHost}, DATABASE_HOST:${DATABASE_HOST}"

set -eo pipefail
# generate data
# - 1) data  generation
log_info "===============data generation================="
log_info "Generating data for ${USE_CASE} into ${FORMAT}, with scale ${SCALE}, seed ${SEED}, log interval ${LOG_INTERVAL}"
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
        echo "tsbs_generate_data not available. It is not specified explicitly and not found in \$PATH"
        exit 1
    fi
    log_debug "Generating execute commod: ${EXE_FILE_NAME_GENERATE_DATA} --format ${FORMAT} --use-case ${USE_CASE} --scale ${SCALE} --timestamp-start ${TS_START} --timestamp-end ${TS_END} --seed ${SEED} --log-interval ${LOG_INTERVAL} --max-data-points ${MAX_DATA_POINTS} | gzip > ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}"

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
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}
# TDneing Databases parameters
BUFFER=${BUFFER:-"256"}
PAGES=${PAGES:-"4096"}
WAL_LEVEL=${WAL_LEVEL:-"2"}

mkdir -p ${BULK_DATA_DIR_RES_LOAD} || echo "file exists"
cd ${scriptDir}


log_info "---------------  Clean  -----------------"
run_command "echo 1 > /proc/sys/vm/drop_caches
    systemctl restart postgresql
    sleep 1
"

# checkout  that io and cpu are free ,iowrite less than 500kB/s and cpu idl large than 99 when client and server are different
if [ ${clientHost} == ${DATABASE_HOST} ];then
    ioStatusPa=false
else
    ioStatusPa=true
fi


# use different load scripts of db to load data , add supported databases 
if [ "${FORMAT}" == "timescaledb" ];then
    DATABASE_PORT=${timescaledb_port:-5432}
    PGPASSWORD=${DATABASE_PWD} psql -U postgres -h $DATABASE_HOST  -d postgres -c "drop database IF EXISTS  ${DATABASE_NAME} "
    if [ -d "${TimePath}" ]; then
        disk_usage_before=$(set_command "du -s ${TimePath} --exclude="pgsql_tmp" | cut -f 1 " )
    else
        disk_usage_before=0
    fi
    log_debug "disk usage before load :$disk_usage_before "
    log_info "Starting to load ${USE_CASE} data into ${FORMAT} with scale ${SCALE}, workers ${NUM_WORKER}, and batch size ${BATCH_SIZE}"

    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    log_debug "Execute commond: cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD} --chunk-time=${CHUNK_TIME} --hash-workers=false > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD}  --chunk-time=${CHUNK_TIME} --hash-workers=false > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    if [ "${USE_CASE}" == "cpu-only" ] || [ "${USE_CASE}" == "iot" ];then
        PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME} -h ${DATABASE_HOST} -c "SELECT chunk_name, is_compressed FROM timescaledb_information.chunks WHERE is_compressed = true" > tempCompress.txt
        tempCompressNum=`more tempCompress.txt |grep rows |awk -F ' ' '{print $1}'`
        log_debug "${FORMAT} tempCompressNum: ${tempCompressNum}"
        if [ "${tempCompressNum}" == "(0" ] ;then
            if [ "${USE_CASE}" == "cpu-only" ]; then
                PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "ALTER TABLE cpu SET (timescaledb.compress, timescaledb.compress_orderby = 'time DESC,usage_user',  timescaledb.compress_segmentby = 'tags_id');"
                PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "SELECT add_compression_policy('cpu', INTERVAL '12 hours');"
            elif [ "${USE_CASE}" == "iot" ];then
                PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "ALTER TABLE diagnostics SET (timescaledb.compress, timescaledb.compress_orderby = 'time DESC,fuel_state',  timescaledb.compress_segmentby = 'tags_id');"
                PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "ALTER TABLE readings SET (timescaledb.compress, timescaledb.compress_orderby = 'time DESC,latitude',  timescaledb.compress_segmentby = 'tags_id');"
                PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "SELECT add_compression_policy('diagnostics', INTERVAL '12 hours');"              
                PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "SELECT add_compression_policy('readings', INTERVAL '12 hours');"     
                # PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "call run_job(1000) ;"                     
                # PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "call run_job(1001) ;"     
            fi
        else
            log_warning "it has already been enabled native compression on TimescaleDB,"
        fi

        log_info "${FORMAT} ${USE_CASE} data is being compressed,it will print the debug information for the compression process"
        while true
        do   
            tempCompressNum=$(PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME} -h ${DATABASE_HOST} -c "SELECT chunk_name, is_compressed FROM timescaledb_information.chunks WHERE is_compressed = true" |grep row |awk  '{print $1}')
            
            disk_usage_after=$(set_command "du -s ${TimePath} --exclude="pgsql_tmp"| cut -f 1 " )
            timesdiffSec=$(( $(date +%s -d ${TS_END}) - $(date +%s -d ${TS_START}) ))
            if  [[ ${CASE_TYPE} == "userdefined" ]] || [[ ${CASE_TYPE} == "cputest" ]] ;then
                timesHours=`echo "scale=2;${timesdiffSec}/60/60/12"|bc`
                timesHours=`ceil $timesHours`
            elif [[ ${USE_CASE} == "iot" ]];then
                timesHours="24"
            else
                timesHours="12"
            fi
            tempCompressNum=`echo ${tempCompressNum} | sed 's/(//g' `
            log_debug "Compression count: ${tempCompressNum}, disk usage after load: ${disk_usage_after}, expected compressed data Block count :${timesHours}"
            if [ "${tempCompressNum}" -ge "${timesHours}" ];then
                break
            fi
        done
    fi
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    log_info  "${FORMAT} ${USE_CASE} data compression has been completed"
    disk_usage_after=$(set_command "du -s ${TimePath} --exclude="pgsql_tmp"| cut -f 1 " )
    log_debug "disk usage before load :$disk_usage_before and disk usage after load: ${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage},0 >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
    PGPASSWORD=${DATABASE_PWD} psql -U postgres -h $DATABASE_HOST  -d postgres -c "drop database IF EXISTS  ${DATABASE_NAME} "
    sleep 60
elif [  ${FORMAT} == "influx" ] || [  ${FORMAT} == "influx3" ]; then
    if [  ${FORMAT} == "influx" ]; then
        DATABASE_PORT=${influx_port:-8086}
        run_command "rm -rf ${InfPath}/*
        systemctl restart influxd
        sleep 1"
    elif [  ${FORMAT} == "influx3" ]; then
        DATABASE_PORT=${influx3_port:-8181}
    fi
    if [ -d "${InfPath}" ]; then
        disk_usage_before=`set_command "du -s ${InfPath} | cut -f 1 " `
    else
        disk_usage_before=0
    fi
    load_command="tsbs_load_${FORMAT}"
    log_debug "COMMAND:${load_command} BATCH_SIZE:${BATCH_SIZE} USE_CASE:${USE_CASE} FORMAT:${FORMAT} NUM_WORKER:${NUM_WORKER} SCALE:${SCALE}"
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    log_debug "cat  ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip |  ${load_command}  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT} --hash-workers=true  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME} | gunzip |  ${load_command}  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT} --hash-workers=true  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    log_debug "test"
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    log_debug "influxdb data is being compressed"
    # checkout  that io and cpu are free ,iowrite less than 500kB/s and cpu idl large than 99 when client and server are different

    while ${ioStatusPa}
    do
        set_command "dool -tdc --output /usr/local/src/teststatus.log 5 7"
        sshpass -p ${SERVER_PASSWORD}  scp root@$DATABASE_HOST:/usr/local/src/teststatus.log  .
        iotempstatus=` tail -6 teststatus.log|awk -F ',' '{print $3}'  |awk '{sum += $1} END {printf "%3.3f\n",sum/NR}'`
        cputempstatus=` tail -6 teststatus.log|awk -F ',' '{print $6}' |awk '{sum += $1} END {printf "%3.3f\n",sum/NR}'`
        log_debug "${iotempstatus},${cputempstatus}"
        if [[ `echo "$iotempstatus<500000" |bc` -eq 1 ]] && [[ `echo "$cputempstatus>99" |bc` -eq 1 ]] ; then  
            log_debug "io and cpu are free"
            ioStatusPa=false
            break
        else 
            log_debug "io and cpu are busy"
            ioStatusPa=true
        fi
    done
    log_debug "influxdb data  compression has been completed"
    set_command "rm -rf /usr/local/src/teststatus.log"
    disk_usage_after=`set_command "du -s ${InfPath} | cut -f 1 " `
    log_debug "disk_usage_before: ${disk_usage_before}, disk_usage_after: ${disk_usage_after}"
    disk_usage=$((disk_usage_after - disk_usage_before))
    log_debug "${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage},0"
    log_debug "target file: ${BULK_DATA_DIR_RES_LOAD}/load_input.csv"
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage},0 >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
    if [  ${FORMAT} == "influx" ]; then
        run_command "rm -rf ${InfPath}/*
        systemctl restart influxd
        sleep 1"
    fi
elif [  ${FORMAT} == "TDengine" ] || [  ${FORMAT} == "TDengineStmt2" ]; then
    run_command "
    echo `date +%Y_%m%d_%H%M%S`\":start to stop taosd and remove data ${TDPath}\"
    systemctl stop taosd
    rm -rf ${TDPath}/*
    echo `date +%Y_%m%d_%H%M%S`\":finish  remove data ${TDPath} \"
    echo `date +%Y_%m%d_%H%M%S`\":restart taosd \"
    systemctl start taosd
    echo `date +%Y_%m%d_%H%M%S`\":check status of taosd \"
    systemctl status taosd
    echo `date +%Y_%m%d_%H%M%S`\":restart successfully\"
    sleep 2"

    DATABASE_PORT=${tdengine_port:-6030}
    DATABASE_TAOS_PWD=${DATABASE_TAOS_PWD:-taosdata}
    if [  ${FORMAT} == "TDengine" ]; then
        load_commond="tsbs_load_tdengine"
    elif [ ${FORMAT} == "TDengineStmt2"  ]; then
        load_commond="tsbs_load_tdenginestmt2"
    fi
    if [ -d "${TDPath}" ]; then
        disk_usage_before=`set_command "du -s ${TDPath}/vnode | cut -f 1 " `
    else
        disk_usage_before=0
    fi
    log_debug "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    if [ ${SCALE} -ge 100000 ];then
        TRIGGER="8"
        if [ ${SCALE} -ge 1000000 ] ;then
            TRIGGER="16"
        fi
    fi
    log_debug " cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |  ${load_commond}  --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} --port=${DATABASE_PORT} --vgroups=${VGROUPS}  --buffer=${BUFFER} --pages=${PAGES} --hash-workers=true --stt_trigger=${TRIGGER} --wal_level=${WAL_LEVEL} --wal_fsync_period=${WALFSYNCPERIOD}> ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |   ${load_commond} \
    --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} --pass=${DATABASE_TAOS_PWD} --port=${DATABASE_PORT}  --vgroups=${VGROUPS}  --buffer=${BUFFER} --pages=${PAGES}  --hash-workers=true  --stt_trigger=${TRIGGER} --wal_level=${WAL_LEVEL} --wal_fsync_period=${WALFSYNCPERIOD} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    log_debug "TDengine data is being written to disk "

    taos -h  ${DATABASE_HOST} -s  "flush database ${DATABASE_NAME}"
    set_command "systemctl restart taosd " 
    # checkout  that io and cpu are free ,iowrite less than 500kB/s and cpu idl large than 99 when client and server are different
    while ${ioStatusPa}
    do
        set_command "dool -tdc --output /usr/local/src/teststatus.log 5 7"
        sshpass -p ${SERVER_PASSWORD}  scp root@$DATABASE_HOST:/usr/local/src/teststatus.log  .
        iotempstatus=` tail -6 teststatus.log|awk -F ',' '{print $3}'  |awk '{sum += $1} END {printf "%3.3f\n",sum/NR}'`
        cputempstatus=` tail -6 teststatus.log|awk -F ',' '{print $6}' |awk '{sum += $1} END {printf "%3.3f\n",sum/NR}'`
        log_debug "${iotempstatus},${cputempstatus}"
        if [[ `echo "$iotempstatus<500000" |bc` -eq 1 ]] && [[ `echo "$cputempstatus>99" |bc` -eq 1 ]] ; then  
            log_debug "io and cpu are free"
            ioStatusPa=false
            break
        else 
            log_debug "io and cpu are busy"
            ioStatusPa=true
        fi
       
    done
    log_debug "TDengine data writing to disk has been completed "
    set_command "rm -rf /usr/local/src/teststatus.log"
    disk_usage_after=`set_command "du -s ${TDPath}/vnode | cut -f 1 " `
    log_debug "${disk_usage_before},${disk_usage_after}"
    wal_uasge=`set_command "du ${TDPath}/vnode/*/wal/  -cs|tail -1  | cut -f 1  " `
    disk_usage_nowal=`expr ${disk_usage_after} - ${disk_usage_before} - ${wal_uasge}`
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    log_debug "${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage},${disk_usage_nowal}"
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage},${disk_usage_nowal} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv    
else
    log_error "The format is not supported"
fi  


