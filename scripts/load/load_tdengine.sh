#!/bin/bash

# Ensure loader is available
EXE_FILE_NAME_LOAD_DATA=${EXE_FILE_NAME_LOAD_DATA:-$(which tsbs_load_tdengine)}
if [[ -z "$EXE_FILE_NAME_LOAD_DATA" ]]; then
    echo "tsbs_load_tdengine is not available. It is not specified explicitly and not found in \$PATH"
    exit 1
fi

# Load parameters - common
DATA_FILE_NAME=${DATA_FILE_NAME:-tdengine-data.gz}
DATABASE_NAME=${DATABASE_NAME:-benchmark}
DATABASE_HOST=${DATABASE_HOST:-localhost}
DATABASE_TAOS_PORT=${DATABASE_TAOS_PORT:-6030}
DATABASE_TAOS_PWD=${DATABASE_TAOS_PWD:-taosdata}
FORMAT=${FORMAT:-"tdengine"}

# Load parameters - personal
VGROUPS=${VGROUPS:-"12"}
BUFFER=${BUFFER:-"256"}
PAGES=${PAGES:-"4096"}
TRIGGER=${TRIGGER:-"8"} 
WALFSYNCPERIOD=${WALFSYNCPERIOD:-"3000"}
WAL_LEVEL=${WAL_LEVEL:-"2"}

EXE_DIR=${EXE_DIR:-$(dirname $0)}
source ${EXE_DIR}/load_common.sh

while ! pg_isready -h ${DATABASE_HOST} -p ${DATABASE_PORT}; do
    echo "Waiting for timescaledb"
    sleep 1
done

echo " cat ${DATA_FILE}  | gunzip |  ${EXE_FILE_NAME_LOAD_DATA}  --db-name=${DATABASE_NAME} --host=${DATABASE_HOST}  --workers=${NUM_WORKER}   --batch-size=${BATCH_SIZE} --vgroups=${vgroups}   --buffer=${BUFFER} --pages=${PAGES} --hash-workers=true  --stt_trigger=${TRIGGER} --wal_level=${WAL_LEVEL} --wal_fsync_period=${WALFSYNCPERIOD} "

cat ${DATA_FILE} | gunzip | $EXE_FILE_NAME_LOAD_DATA \
                                --db-name=${DATABASE_NAME} \
                                --host=${DATABASE_HOST} \
                                --port=${DATABASE_TAOS_PORT} \
                                --pass=${DATABASE_TAOS_PWD} \
                                --workers=${NUM_WORKERS} \
                                --batch-size=${BATCH_SIZE} \
                                --vgroups=${vgroups} \
                                --buffer=${BUFFER} \
                                --pages=${PAGES} \
                                --hash-workers=true \
                                --stt_trigger=${TRIGGER} \
                                --wal_level=${WAL_LEVEL} \
                                --wal_fsync_period=${WALFSYNCPERIOD} 
