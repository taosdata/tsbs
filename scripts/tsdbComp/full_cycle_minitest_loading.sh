#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution

scriptDir=$(dirname $(readlink -f $0))

# - 1) data  generation
echo "===============data generation================="
echo "${FORMAT},${SCALE},${USE_CASE}"
EXE_FILE_NAME_GENERATE_DATA=$(which tsbs_generate_data)
if [[ -z "${EXE_FILE_NAME_GENERATE_DATA}" ]]; then
    echo "tsbs_generate_data not available. It is not specified explicitly and not found in \$PATH"
    exit 1
fi
# Data folder
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data"}
TDPath="/var/lib/taos/"
InfPath="/var/lib/influxdb/"
TimePath="/var/lib/postgresql/14/main/base/"

# Space-separated list of target DB formats to generate
FORMAT=${FORMAT:-"timescaledb"}

# Number of hosts to generate data about
SCALE=${SCALE:-"100"}

# Rand seed
SEED=${SEED:-"123"}

# Start and stop time for generated timeseries
TS_START=${TS_START:-"2016-01-01T00:00:00Z"}
TS_END=${TS_END:-"2016-01-02T00:00:00Z"}

# What set of data to generate: devops (multiple data), cpu-only (cpu-usage data)
USE_CASE=${USE_CASE:-"devops"}

# Step to generate data
LOG_INTERVAL=${LOG_INTERVAL:-"10s"}

# Max number of points to generate data. 0 means "use TS_START TS_END with LOG_INTERVAL"
MAX_DATA_POINTS=${MAX_DATA_POINTS:-"0"}



# Ensure DATA DIR available
mkdir -p ${BULK_DATA_DIR}
chmod a+rwx ${BULK_DATA_DIR}

function ceil(){
  floor=`echo "scale=0;$1/1"|bc -l ` # 向下取整
  add=`awk -v num1=$floor -v num2=$1 'BEGIN{print(num1<num2)?"1":"0"}'`
  echo `expr $floor  + $add`
}

set -eo pipefail
# generate data
INSERT_DATA_FILE_NAME="data_${FORMAT}_${USE_CASE}_scale${SCALE}_${TS_START}_${TS_END}_interval${LOG_INTERVAL}_${SEED}.dat.gz"
if [ -f "${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}" ]; then
    echo "WARNING: file ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME} already exists, skip generating new data"
else
    cleanup() {
        rm -f ${INSERT_DATA_FILE_NAME}
        exit 1
    }
    trap cleanup EXIT

    echo "Generating ${INSERT_DATA_FILE_NAME}:"
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
echo "===============data loading/insertion================="

# Load parameters - common
DATABASE_USER=${DATABASE_USER:-postgres}
DATABASE_NAME=${DATABASE_NAME:-benchmark}
DATABASE_HOST=${DATABASE_HOST:-localhost}
DATABASE_PORT=${DATABASE_PORT:-5432}
DATABASE_PWD=${DATABASE_PWD:-password}
DATABASE_PORT_INF=${DATABASE_PORT_INF:-8086}
DATABASE_TAOS_PWD=${DATABASE_TAOS_PWD:-taosdata}
DATABASE_TAOS_PORT=${DATABASE_TAOS_PORT:-6030}
NUM_WORKER=${NUM_WORKER:-"16"} 
BATCH_SIZE=${BATCH_SIZE:-"10000"} 
CHUNK_TIME=${CHUNK_TIME:-"12h"}
SERVER_PASSWORD=${SERVER_PASSWORD:-123456}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load"}
CASE_TYPE=${CASE_TYPE:-"cputest"} 

# TDneing Databases parameters
VGROUPS=${VGROUPS:-"24"}
BUFFER=${BUFFER:-"256"}
PAGES=${PAGES:-"4096"}
TRIGGER=${TRIGGER:-"8"} 
WALFSYNCPERIOD=${WALFSYNCPERIOD:-"3000"}
WAL_LEVEL=${WAL_LEVEL:-"2"}

mkdir -p ${BULK_DATA_DIR_RES_LOAD} || echo "file exists"
cd ${scriptDir}

echo "---------------  Clean  -----------------"
sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST << eeooff
echo 1 > /proc/sys/vm/drop_caches
systemctl restart influxd
systemctl restart postgresql
sleep 1
exit
eeooff


# use different load scripts of db to load data , add supported databases 
if [ "${FORMAT}" == "timescaledb" ];then
    PGPASSWORD=${DATABASE_PWD} psql -U postgres -h $DATABASE_HOST  -d postgres -c "drop database IF EXISTS  ${DATABASE_NAME} "
    disk_usage_before=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${TimePath} --exclude="pgsql_tmp" | cut -f 1 " `
    echo $disk_usage_before
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo `date +%Y_%m%d_%H%M%S`":start to insert data in timescaldeb"
    echo "cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD} --chunk-time=${CHUNK_TIME} --hash-workers=false > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD}  --chunk-time=${CHUNK_TIME} --hash-workers=false > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    if [ "${USE_CASE}" == "cpu-only" ];then
        PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME} -h ${DATABASE_HOST} -c "SELECT chunk_name, is_compressed FROM timescaledb_information.chunks WHERE is_compressed = true" > tempCompress.txt
        tempCompressNum=`more tempCompress.txt |grep rows |awk -F ' ' '{print $1}'`
        echo "${tempCompressNum}"
        if [ "${tempCompressNum}" == "(0" ] ;then
            PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "ALTER TABLE cpu SET (timescaledb.compress, timescaledb.compress_orderby = 'time DESC,usage_user',  timescaledb.compress_segmentby = 'tags_id');"
            PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "SELECT add_compression_policy('cpu', INTERVAL '12 hours');"
        else
            echo "it has already been enabled native compression on TimescaleDB,"
        fi
    fi
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    echo `date +%Y_%m%d_%H%M%S`":timescaledb data is being compressed"
    if [ "${USE_CASE}" == "cpu-only" ];then
        while true
        do   
            tempCompressNum=$(PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME} -h ${DATABASE_HOST} -c "SELECT chunk_name, is_compressed FROM timescaledb_information.chunks WHERE is_compressed = true" |grep row |awk  '{print $1}')
            disk_usage_after=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${TimePath} --exclude="pgsql_tmp"| cut -f 1 " `
            timesdiffSec=$(( $(date +%s -d ${TS_END}) - $(date +%s -d ${TS_START}) ))
            if  [[ ${CASE_TYPE} == "userdefined" ]] || [[ ${CASE_TYPE} == "cputest" ]] ;then
                timesHours=`echo "scale=2;${timesdiffSec}/60/60/12"|bc`
                timesHours=`ceil $timesHours`
            else
                timesHours="12"
            fi
            echo ${tempCompressNum}
            echo ${disk_usage_after}
            if [ "${tempCompressNum}" == "(${timesHours}" ];then
                break
            fi
        done
    fi
    echo `date +%Y_%m%d_%H%M%S`"timescaledb data compression has been completed"
    disk_usage_after=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${TimePath} --exclude="pgsql_tmp"| cut -f 1 " `
    echo "${disk_usage_before} ${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage},0 >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
    PGPASSWORD=${DATABASE_PWD} psql -U postgres -h $DATABASE_HOST  -d postgres -c "drop database IF EXISTS  ${DATABASE_NAME} "
    sleep 60
elif [  ${FORMAT} == "influx" ];then
    sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST << eeooff
    rm -rf ${InfPath}/*
    systemctl restart influxd
    sleep 1
    exit
eeooff
    disk_usage_before=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${InfPath}/data | cut -f 1 " `
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo `date +%Y_%m%d_%H%M%S`
    echo "cat  ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip |  tsbs_load_influx  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT_INF} --hash-workers=true  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME} | gunzip |   tsbs_load_influx  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT_INF} --hash-workers=true  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    # checkout  that io and cpu are free ,iowrite less than 500kB/s and cpu idl large than 99
    ioStatusPa=true
    while ${ioStatusPa}
    do
        sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "dool -tdc --output /usr/local/src/teststatus.log 5 7"
        sshpass -p ${SERVER_PASSWORD}  scp root@$DATABASE_HOST:/usr/local/src/teststatus.log  .
        iotempstatus=` tail -6 teststatus.log|awk -F ',' '{print $3}'  |awk '{sum += $1} END {printf "%3.3f\n",sum/NR}'`
        cputempstatus=` tail -6 teststatus.log|awk -F ',' '{print $6}' |awk '{sum += $1} END {printf "%3.3f\n",sum/NR}'`
        echo "${iotempstatus},${cputempstatus}"
        if [[ `echo "$iotempstatus<500000" |bc` -eq 1 ]] && [[ `echo "$cputempstatus>99" |bc` -eq 1 ]] ; then  
            echo "io and cpu are free"
            ioStatusPa=false
            break
        else 
            echo "io and cpu are busy"
            ioStatusPa=true
        fi
    done
    sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "rm -rf /usr/local/src/teststatus.log"
    # if [ ${SCALE} -le 100000 ];then
    #     sleep 200
    # elif [  ${SCALE} -eq 1000000 ];then
    #     sleep 600
    # elif [  ${SCALE} -eq 10000000 ];then
    #     sleep 4200    
    # fi
    disk_usage_after=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${InfPath}/data | cut -f 1 " `
    echo "${disk_usage_before},${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage},0 >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
    sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST << eeooff
    rm -rf ${InfPath}/*
    systemctl restart influxd
    sleep 1
    exit
eeooff
elif [  ${FORMAT} == "TDengine" ];then
    sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST << eeooff
    echo `date +%Y_%m%d_%H%M%S`":start to stop taosd and remove data ${TDPath} "
    systemctl stop taosd
    rm -rf ${TDPath}/*
    echo `date +%Y_%m%d_%H%M%S`":finish  remove data ${TDPath} "
    echo `date +%Y_%m%d_%H%M%S`":restart taosd "
    systemctl start taosd
    echo `date +%Y_%m%d_%H%M%S`":check status of taosd "
    systemctl status taosd
    echo `date +%Y_%m%d_%H%M%S`":restart successfully"
    sleep 2
    exit
eeooff
    echo "caculte data size"
    disk_usage_before=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${TDPath}/vnode | cut -f 1 " `
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo `date +%Y_%m%d_%H%M%S`":start to load TDengine Data "
    echo " cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |  tsbs_load_tdengine  --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} --vgroups=${VGROUPS}  --buffer=${BUFFER} --pages=${PAGES} --hash-workers=true --stt_trigger=${TRIGGER} --wal_level=${WAL_LEVEL} --wal_fsync_period=${WALFSYNCPERIOD}> ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |   tsbs_load_tdengine \
    --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} --pass=${DATABASE_TAOS_PWD} --port=${DATABASE_TAOS_PORT}  --vgroups=${VGROUPS}  --buffer=${BUFFER} --pages=${PAGES}  --hash-workers=true  --stt_trigger=${TRIGGER} --wal_level=${WAL_LEVEL} --wal_fsync_period=${WALFSYNCPERIOD} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    taos -h  ${DATABASE_HOST} -s  "flush database ${DATABASE_NAME}"
    sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "systemctl restart taosd " 
    # checkout  that io and cpu are free ,iowrite less than 500kB/s and cpu idl large than 99
    ioStatusPa=true
    while ${ioStatusPa}
    do
        sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "dool -tdc --output /usr/local/src/teststatus.log 5 7"
        sshpass -p ${SERVER_PASSWORD}  scp root@$DATABASE_HOST:/usr/local/src/teststatus.log  .
        iotempstatus=` tail -6 teststatus.log|awk -F ',' '{print $3}'  |awk '{sum += $1} END {printf "%3.3f\n",sum/NR}'`
        cputempstatus=` tail -6 teststatus.log|awk -F ',' '{print $6}' |awk '{sum += $1} END {printf "%3.3f\n",sum/NR}'`
        echo "${iotempstatus},${cputempstatus}"
        if [[ `echo "$iotempstatus<500000" |bc` -eq 1 ]] && [[ `echo "$cputempstatus>99" |bc` -eq 1 ]] ; then  
            echo "io and cpu are free"
            ioStatusPa=false
            break
        else 
            echo "io and cpu are busy"
            ioStatusPa=true
        fi
       
    done
    sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "rm -rf /usr/local/src/teststatus.log"
    disk_usage_after=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du -s ${TDPath}/vnode | cut -f 1 " `
    echo "${disk_usage_before},${disk_usage_after}"
    wal_uasge=`sshpass -p ${SERVER_PASSWORD}  ssh root@$DATABASE_HOST "du ${TDPath}/vnode/*/wal/  -cs|tail -1  | cut -f 1  " `
    disk_usage_nowal=`expr ${disk_usage_after} - ${disk_usage_before} - ${wal_uasge}`
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    # pid=`ps aux|grep taosd|grep -v  grep |awk '{print $2}'`
    # echo ${pid}
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage},${disk_usage_nowal} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv    
else
    echo "it don't support format"
fi  


