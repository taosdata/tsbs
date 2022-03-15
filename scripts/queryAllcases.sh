# add your testcase :


#  testcaset 1---diffrent querytype 
# need define data and result path
BULK_DATA_QUERY_DIR="/tmp/bulk_queries1/" 
BULK_DATA_DIR_RUN_RES="/tmp/bulk_result_query1/" 
BULK_DATA_DIR=${BULK_DATA_DIR:-"/tmp/bulk_data3"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/tmp/bulk_result_load3"}

# QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# QUERY_TYPES_IOT_ALL="last-loc avg-load" \

# excute testcase
TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-02T00:00:01Z" \
LOAD_TS_END="2016-01-02T00:00:00Z"  \
DATABASE_HOST="test217" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="16" \
BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
USE_CASES="devops" FORMATS="timescaledb influx"  QUERIES="1000" \
SCALE="100" ./querytest.sh 

# generate png report
# loadResultAnaly.py has three parameter,
# 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
echo "python3 loadResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv NUM_WORKER test_load2.png"
python3 queryResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv 