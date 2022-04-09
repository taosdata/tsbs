# add your testcase :




#  testcaset---scale 100 4000
# need define data and result path
new=`date +%Y_%m%d_%H%M%S`

BULK_DATA_QUERY_DIR="/data2/bulk_data_query_cpu-only" 
BULK_DATA_DIR_RUN_RES="/data2/bulk_result_query_cpu-only_${new}/" 

BULK_DATA_DIR=${BULK_DATA_DIR:-"/data2/bulk_data_cpu-only"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/data2/bulk_result_load_${new}/"}

# QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# QUERY_TYPES_IOT_ALL="last-loc avg-load" \

# excute testcase
TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-05T00:00:01Z" \
LOAD_TS_END="2016-01-05T00:00:00Z" QUERY_DEBUG="false" \
DATABASE_HOST="test209" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="14"  SERVER_PASSWORD="tbase124!" \
BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
USE_CASES="cpu-only" FORMATS="TDengine timescaledb"  QUERIES="100" \
SCALES="100" DATABASE_NAME="benchmarkcpu" RESTLOAD="true" ./querytest.sh 

# generate png report
# loadResultAnaly.py has three parameter,
# 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# echo "python3 loadResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv NUM_WORKER test_load2.png"
# python3 queryResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv NUM_WORKER ${BULK_DATA_DIR_RUN_RES}/test_load2.png




# #  testcaset 1---diffrent querytype 
# # need define data and result path
# BULK_DATA_QUERY_DIR="/home/chr/bulk_queries_check2/" 
# BULK_DATA_DIR_RUN_RES="/home/chr/bulk_result_query_check2/" 
# BULK_DATA_DIR=${BULK_DATA_DIR:-"/home/chr/bulk_data4"}
# BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/home/chr/bulk_result_load3"}

# # QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# # QUERY_TYPES_IOT_ALL="last-loc avg-load" \

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-02T00:00:01Z" \
# LOAD_TS_END="2016-01-02T00:00:00Z"  \
# DATABASE_HOST="test217" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
# BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="16" \
# BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# USE_CASES="devops" FORMATS="TDengine timescaledb influx"  QUERIES="1" \
# SCALE="500" DATABASE_NAME="benchmarkdevops" RESTLOAD="false" ./querytest.sh 

# # generate png report
# # loadResultAnaly.py has three parameter,
# # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# # echo "python3 loadResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv NUM_WORKER test_load2.png"
# # python3 queryResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv NUM_WORKER ${BULK_DATA_DIR_RUN_RES}/test_load2.png





# #  testcaset 2---diffrent querytype 
# # need define data and result path
# BULK_DATA_QUERY_DIR="/home/chr/bulk_queries2/" 
# BULK_DATA_DIR_RUN_RES="/home/chr/bulk_result_query2/" 
# BULK_DATA_DIR=${BULK_DATA_DIR:-"/home/chr/bulk_data4"}
# BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/home/chr/bulk_result_load3"}

# # QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# # QUERY_TYPES_IOT_ALL="last-loc avg-load" \

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-02T00:00:01Z" \
# LOAD_TS_END="2016-01-02T00:00:00Z"  \
# DATABASE_HOST="test217" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
# BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="16" \
# BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# USE_CASES="iot" FORMATS="TDengine influx timescaledb"  QUERIES="100" DATABASE_NAME="benchmarkiot" \
# SCALE="500" ./querytest.sh 

# generate png report
# loadResultAnaly.py has three parameter,
# 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# echo "python3 queryResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType ${BULK_DATA_DIR_RUN_RES}/test_query.png"
# python3 queryResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType ${BULK_DATA_DIR_RUN_RES}/test_query.png

# echo "python3 queryRatioBar..py ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType ${BULK_DATA_DIR_RUN_RES}/test_query_ratio.png"
# python3 queryRatioBar..py ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType ${BULK_DATA_DIR_RUN_RES}/test_query_ratio.png


# #  testcaset 3---diffrent querytype 
# # need define data and result path
# BULK_DATA_QUERY_DIR="/home/chr/bulk_queries_iot/" 
# BULK_DATA_DIR_RUN_RES="/home/chr/bulk_result_query_iot/" 
# BULK_DATA_DIR=${BULK_DATA_DIR:-"/home/chr/bulk_data4"}
# BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/home/chr/bulk_result_load3"}

# # QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# # QUERY_TYPES_IOT_ALL="last-loc avg-load" \

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-02T00:00:01Z" \
# LOAD_TS_END="2016-01-02T00:00:00Z"  \
# DATABASE_HOST="test217" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
# BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="16" RESTLOAD="true" \
# BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# USE_CASES="iot" FORMATS="TDengine"  QUERIES="100" DATABASE_NAME="benchmarkiot"  \
# SCALE="500" QUERY_TYPES_IOT_ALL="avg-vs-projected-fuel-consumption" ./querytest.sh 

# #generate png report
# # loadResultAnaly.py has three parameter,
# # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# echo "python3 queryResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType ${BULK_DATA_DIR_RUN_RES}/test_query.png"
# python3 queryResultAnaly.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType ${BULK_DATA_DIR_RUN_RES}/test_query.png

# echo "python3 queryRatioBar.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType ${BULK_DATA_DIR_RUN_RES}/test_query_ratio.png"
# python3 queryRatioBar.py ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType ${BULK_DATA_DIR_RUN_RES}/test_query_ratio.png
