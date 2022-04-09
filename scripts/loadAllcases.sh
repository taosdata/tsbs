# add your testcase :

set -e


# #  testcaset 1.1: devops/diffrent NUM_WORKERS/1day
# # need define data and result path
# BULK_DATA_DIR="/home/chr/bulk_data4/" 
# BULK_DATA_DIR_RES_LOAD="/home/chr/bulk_result_load4/" 

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-02T00:00:00Z" \
# DATABASE_HOST="test217" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="8 12 16 20 24" \
# USE_CASES="devops" FORMATS="TDengine influx timescaledb" \
# SCALES="500" ./loadtest.sh 


# #  testcaset 1.2---iot  diffrent NUM_WORKERS
# # need define data and result path
# BULK_DATA_DIR="/home/chr/testresult/bulk_data_3day/" 
# BULK_DATA_DIR_RES_LOAD="/home/chr/testresult/bulk_result_load_iot_worker/" 

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-04T00:00:00Z" \
# DATABASE_HOST="test217" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="8 12 16 20 24" \
# USE_CASES="iot" FORMATS="TDengine influx timescaledb" \
# SCALES="500" ./loadtest.sh 


# # #  testcaset 3---diffrent batchsize=1000 100000 50000 60000 70000 80000 90000
# # # need define data and result path
# BULK_DATA_DIR="/home/chr/bulk_data5/" 
# BULK_DATA_DIR_RES_LOAD="/home/chr/bulk_result_load_batchsize/" 

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-02T00:10:00Z" \
# DATABASE_HOST="test217" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="24 " FORMATS="TDengine influx timescale" \
# USE_CASES="devops iot"  BATCH_SIZES="10000 30000 50000 60000 70000 80000 90000"  \
# SCALES="500" ./loadtest.sh 


# #  testcaset 4---diffrent NUM_WORKERS
# # need define data and result path
# BULK_DATA_DIR="/tmp/bulk_data_scale3000/" 
# BULK_DATA_DIR_RES_LOAD="/tmp/bulk_result_load_scale3000/" 

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-02T00:00:00Z" \
# DATABASE_HOST="test217" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="12" \
# USE_CASES="devops" FORMATS="TDengine influx" \
# SCALES="1000 2000 3000" ./loadtest.sh 



# #  testcaset 5---diffrent SCALES=100  500  1000 1500 FORMATS="timescaledb influx TDengine"
# ## 1.1need define data and result path
# BULK_DATA_DIR="/tmp/bulk_data1/" 
# BULK_DATA_DIR_RES_LOAD="/tmp/bulk_result_load1/" 

# ##  excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-01T00:10:00Z" \
# DATABASE_HOST="test217" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="8" \
# USE_CASES="devops iot" FORMATS="TDengine influx" \
# SCALES="100 500 1500" ./loadtest.sh 



#  testcaset 6: devops/diffrent NUM_WORKERS/1day
# need define data and result path
new=`date +%Y_%m%d_%H%M%S`
BULK_DATA_DIR="/data2/bulk_data_cpu-only/" 
BULK_DATA_DIR_RES_LOAD="/data2/bulk_result_data_cpu-only_${new}/" 

# excute testcase
TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-03T00:00:00Z" \
DATABASE_HOST="test209" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="12" SERVER_PASSWORD="tbase124!" \
USE_CASES="cpu-only" FORMATS="influx" BATCH_SIZES="10000" \
SCALES="100000" ./loadtest.sh 

# #generate png report
# # loadResultAnaly.py has three parameter,
# # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# echo "python3 /home/chr/tsbs/scripts/loadResultAnaly.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  NUM_WORKER ${BULK_DATA_DIR_RES_LOAD}/test_load.png"
# python3 /home/chr/tsbs/scripts/loadResultAnaly.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  NUM_WORKER ${BULK_DATA_DIR_RES_LOAD}/test_load.png

# echo "python3 /home/chr/tsbs/scripts/loadRatioBar.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  NUM_WORKER ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png"
# python3 /home/chr/tsbs/scripts/loadRatioBar.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  NUM_WORKER ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png