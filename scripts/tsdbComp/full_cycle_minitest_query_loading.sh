#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution

scriptDir=$(dirname $(readlink -f $0))

FORMATAISA=${FORMATAISA:-"timescaledb"}


# - 1) data  generation
echo "===============data generation================="
echo "${FORMAT},${FORMATAISA},${SCALE},${USE_CASE}"
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

# TDneing Databases: Vgroups
VGROUPS=${VGROUPS:-"6"}
BUFFER=${BUFFER:-"512"}
PAGES=${PAGES:-"4096"}

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
clientHost=`hostname`

set -eo pipefail

function ceil(){
  floor=`echo "scale=0;$1/1"|bc -l ` # 向下取整
  add=`awk -v num1=$floor -v num2=$1 'BEGIN{print(num1<num2)?"1":"0"}'`
  echo `expr $floor  + $add`
}

function floor(){
  floor=`echo "scale=0;$1/1"|bc -l ` # 向下取整
  echo `expr $floor`
}

echo "clientHost:${clientHost}, DATABASE_HOST:${DATABASE_HOST}"

function run_command() {
    local command="$1"
    if [ "$clientHost" == "${DATABASE_HOST}"  ]; then
        # 本地执行
        eval "$command"
    else
        # 远程执行
        sshpass -p ${SERVER_PASSWORD} ssh root@$DATABASE_HOST << eeooff
            $command
            exit
eeooff
    fi
}

function set_command() {
    local command=$1
    local result
    if [ "$clientHost" == "${DATABASE_HOST}"  ]; then
        # 本地执行
        result=$(eval "$command")
    else
        # 远程执行
         result=`sshpass -p ${SERVER_PASSWORD} ssh root@$DATABASE_HOST "$command"`
    fi
    echo "$result"
}
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
TRIGGER=${TRIGGER:-"1"} 


mkdir -p ${BULK_DATA_DIR_RES_LOAD} || echo "file exists"
cd ${scriptDir}

echo "---------------  Clean  -----------------"
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
run_command "
    systemctl restart postgresql
    sleep 1"

    sleep 1
    PGPASSWORD=${DATABASE_PWD} psql -U postgres -h $DATABASE_HOST  -d postgres -c "drop database IF EXISTS  ${DATABASE_NAME} "
    disk_usage_before=`set_command "du -s ${TimePath} --exclude="pgsql_tmp" | cut -f 1 " `
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo "$(date +%Y_%m%d_%H%M%S):start to load "
    echo "cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD} --chunk-time=${CHUNK_TIME} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip | tsbs_load_timescaledb  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME}  --host=${DATABASE_HOST}  --pass=${DATABASE_PWD}  --chunk-time=${CHUNK_TIME} > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    if [ "${USE_CASE}" == "cpu-only" ];then
        PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME} -h ${DATABASE_HOST} -c "SELECT chunk_name, is_compressed FROM timescaledb_information.chunks WHERE is_compressed = true" > tempCompress.txt
        tempCompressNum=`more tempCompress.txt |grep rows |awk -F ' ' '{print $1}'`
        echo "${tempCompressNum}"
        if [ "${tempCompressNum}" == "(0" ] ;then
            PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "ALTER TABLE cpu SET (timescaledb.compress, timescaledb.compress_orderby = 'time DESC,usage_user',  timescaledb.compress_segmentby = 'tags_id');"
            # hostname in  tags  can't be set and it reports ERROR:  unrecognized parameter namespace "timescaledb".
            # PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "ALTER TABLE tags SET (timescaledb.compress, timescaledb.compress_segmentby = 'hostname');"  
            echo "$(date +%Y_%m%d_%H%M%S):start to add compression policy"
            echo "compressed SQL: SELECT add_compression_policy('cpu', INTERVAL '${compressChunkTime}')"
            PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME}  -h ${DATABASE_HOST} -c  "SELECT add_compression_policy('cpu', INTERVAL '${compressChunkTime}' );"

        else
            echo "it has already been enabled native compression on TimescaleDB,"
        fi
    fi
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    if [ "${USE_CASE}" == "cpu-only" ];then
        while true
        do   
            tempCompressNum=$(PGPASSWORD=password psql -U postgres -d ${DATABASE_NAME} -h ${DATABASE_HOST} -c "SELECT chunk_name, is_compressed FROM timescaledb_information.chunks WHERE is_compressed = true" |grep row |awk  '{print $1}')
            disk_usage_after=`set_command "du -s ${TimePath} --exclude="pgsql_tmp"| cut -f 1 " `
            echo "${tempCompressNum},${disk_usage_after}"
            timesdiffSec=$(( $(date +%s -d ${TS_END}) - $(date +%s -d ${TS_START}) ))
            # echo "chunkTimeSeconds:${chunkTimeInter}"
            timesHours=`echo "scale=3;${timesdiffSec}/${chunkTimeInter}"|bc`
            timesHours1=`ceil $timesHours`
            timesHours2=`floor $timesHours`
            echo ${timesHours1}, ${timesHours2}
            if [[ "${tempCompressNum}" == "(${timesHours1}" ]] || [[ "${tempCompressNum}" == "(${timesHours2}" ]] ;then
                echo "${timesHours},${tempCompressNum}"
                echo "$(date +%Y_%m%d_%H%M%S): complete  compression"
                break
            fi
        done
    fi
    disk_usage_after=`set_command "du -s ${TimePath} --exclude="pgsql_tmp"| cut -f 1 " `
    echo "${disk_usage_before} ${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    echo ${FORMATAISA},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
elif [  ${FORMAT} == "influx" ];then
    run_command "
    systemctl restart influxd
    sleep 1"

    disk_usage_before=`set_command "du -s ${InfPath}/data | cut -f 1 " `
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo `date +%Y_%m%d_%H%M%S`
    echo "cat  ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}| gunzip |  tsbs_load_influx  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT_INF}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME} | gunzip |   tsbs_load_influx  --workers=${NUM_WORKER}  --batch-size=${BATCH_SIZE} --db-name=${DATABASE_NAME} --urls=http://${DATABASE_HOST}:${DATABASE_PORT_INF}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    disk_usage_after=`set_command "du -s ${InfPath}/data | cut -f 1 " `
    echo "${disk_usage_before},${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv
elif [  ${FORMAT} == "TDengine" ];then
    run_command "
    echo `date +%Y_%m%d_%H%M%S`\":restart taosd \"
    systemctl restart taosd
    sleep 5
    echo `date +%Y_%m%d_%H%M%S`\":check status of taosd \"
    systemctl status taosd
    echo `date +%Y_%m%d_%H%M%S`\":restart successfully\" "
    
    disk_usage_before=`set_command "du -s ${TDPath}/vnode | cut -f 1 " `
    echo "BATCH_SIZE":${BATCH_SIZE} "USE_CASE":${USE_CASE} "FORMAT":${FORMAT}  "NUM_WORKER":${NUM_WORKER}  "SCALE":${SCALE} "VGROUPS":${VGROUPS}
    RESULT_NAME="${FORMAT}_${USE_CASE}_scale${SCALE}_worker${NUM_WORKER}_batch${BATCH_SIZE}_data.txt"
    echo `date +%Y_%m%d_%H%M%S`
    echo " cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |  tsbs_load_tdengine  --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE}  --vgroups=${VGROUPS}  --buffer=${BUFFER} --pages=${PAGES} --hash-workers=true --stt_trigger=${TRIGGER}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}"
    cat ${BULK_DATA_DIR}/${INSERT_DATA_FILE_NAME}  | gunzip |   tsbs_load_tdengine \
    --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} --pass=${DATABASE_TAOS_PWD} --port=${DATABASE_TAOS_PORT}  --vgroups=${VGROUPS}  --buffer=${BUFFER} --pages=${PAGES} --hash-workers=true  --stt_trigger=${TRIGGER}  > ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}
    taos -h $DATABASE_HOST -s "alter database ${DATABASE_NAME} cachemodel 'last_row'  cachesize 200 ;"
    speed_metrics=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |head -1  |awk '{print $1}'`
    speeds_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $11" "$12}'| awk  '{print $0"\b \t"}' |tail  -1 |awk '{print $1}' `
    times_rows=`cat  ${BULK_DATA_DIR_RES_LOAD}/${RESULT_NAME}|grep loaded |awk '{print $5}'|head -1  |awk '{print $1}' |sed "s/sec//g" `
    taos -h  ${DATABASE_HOST} -s  "flush database ${DATABASE_NAME};"
    disk_usage_after=`set_command "du -s ${TDPath}/vnode | cut -f 1 " `
    echo "${disk_usage_before},${disk_usage_after}"
    disk_usage=`expr ${disk_usage_after} - ${disk_usage_before}`
    # pid=`ps aux|grep taosd|grep -v  grep |awk '{print $2}'`
    # echo ${pid}
    echo ${FORMAT},${USE_CASE},${SCALE},${BATCH_SIZE},${NUM_WORKER},${speeds_rows},${times_rows},${speed_metrics},${disk_usage} >> ${BULK_DATA_DIR_RES_LOAD}/load_input.csv    
else
    echo "it don't support format"
fi  


