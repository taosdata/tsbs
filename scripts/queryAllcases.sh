# add your testcase :

#  testcaset---cpu-only
# need define data and result path
new=`date +%Y_%m%d_%H%M%S`

BULK_DATA_QUERY_DIR="/data2/bulk_data_query_cpu-only" 
BULK_DATA_DIR_RUN_RES="/data2/bulk_result_query_cpu-only_${new}/" 

BULK_DATA_DIR=${BULK_DATA_DIR:-"/data2/bulk_data_cpu-only"}
BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/data2/bulk_result_load_${new}/"}

# QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# QUERY_TYPES_IOT_ALL="last-loc avg-load" \

# excute testcase（batchsize=50000）
TS_START="2016-01-01T00:00:00Z" QUERY_TS_END="2016-01-05T00:00:01Z" \
LOAD_TS_END="2016-01-05T00:00:00Z" QUERY_DEBUG="false" \
DATABASE_HOST="test209" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="14"  SERVER_PASSWORD="tbase124!" \
BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
USE_CASES="cpu-only" FORMATS="TDengine timescaledb influx"  QUERIES="1000" \
SCALES="100 4000" DATABASE_NAME="benchmarkcpu" RESTLOAD="true" ./querytest.sh 

# generate png 
awk -F ',' -v OFS=','  '{if($4==100)print$0}' ${BULK_DATA_DIR_RUN_RES}/query_input.csv > ${BULK_DATA_DIR_RUN_RES}/100query_input.csv 
awk -F ',' -v OFS=','  '{if($4==4000)print$0}' ${BULK_DATA_DIR_RUN_RES}/query_input.csv > ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv
python3 /home/chr/tsbs/scripts/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/100query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_bar_100.png
python3 /home/chr/tsbs/scripts/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_bar_4000.png
python3 /home/chr/tsbs/scripts/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/100query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_100.png
python3 /home/chr/tsbs/scripts/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv  queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_4000.png


# #  testcaset---iot
# # need define data and result path
# new=`date +%Y_%m%d_%H%M%S`

# BULK_DATA_QUERY_DIR="/data2/bulk_data_query_iot" 
# BULK_DATA_DIR_RUN_RES="/data2/bulk_result_query_iot_${new}/" 

# BULK_DATA_DIR=${BULK_DATA_DIR:-"/data2/bulk_data_iot_0412"}
# BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/data2/bulk_result_load_iot_${new}/"}


# # QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# # QUERY_TYPES_IOT_ALL="last-loc avg-load" \

# # excute testcase（batchsize=50000）
# TS_START="2016-01-01T00:00:00Z" QUERY_TS_END="2016-01-05T00:00:01Z" \
# LOAD_TS_END="2016-01-05T00:00:00Z" QUERY_DEBUG="false" \
# DATABASE_HOST="test209" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
# BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="14"  SERVER_PASSWORD="tbase124!" \
# BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# USE_CASES="iot" FORMATS="TDengine influx timescaledb"  QUERIES="1000" \
# SCALES="4000 100" DATABASE_NAME="benchmarkiot" RESTLOAD="true" ./querytest.sh 

# # generate png 
# awk -F ',' -v OFS=','  '{if($4==100)print$0}' ${BULK_DATA_DIR_RUN_RES}/query_input.csv > ${BULK_DATA_DIR_RUN_RES}/100query_input.csv 
# awk -F ',' -v OFS=','  '{if($4==4000)print$0}' ${BULK_DATA_DIR_RUN_RES}/query_input.csv > ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv
# python3 /home/chr/tsbs/scripts/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/100query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_bar_100.png
# python3 /home/chr/tsbs/scripts/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_bar_4000.png
# python3 /home/chr/tsbs/scripts/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/100query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_100.png
# python3 /home/chr/tsbs/scripts/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv  queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_4000.png

