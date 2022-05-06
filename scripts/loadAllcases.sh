# add your testcase :

set -e


# #  testcaset 1: cpu-only
# # need define data and result path
# new=`date +%Y_%m%d_%H%M%S`
# BULK_DATA_DIR="/data2/bulk_data_cpu-only/" 
# BULK_DATA_DIR_RES_LOAD="/data2/load_data_cpu-only_${new}/" 

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-03T00:00:00Z" \
# DATABASE_HOST="test209" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="12" SERVER_PASSWORD="tbase124!" \
# USE_CASES="devops" FORMATS="TDengine influx timescaledb" BATCH_SIZES="10000" \
# SCALES="100 4000 100000 1000000 10000000" DATABASE_NAME="benchmarkdev" ./loadtest.sh 

# #generate png report
# # loadResultAnaly.py has three parameter,
# # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# echo "python3 /home/chr/tsbs/scripts/loadResultAnalyBarh.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load.png"
# python3 /home/chr/tsbs/scripts/loadResultAnalyBarh.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load.png

# echo "/home/chr/tsbs/scripts/loadRatioBarh.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png"
# python3 /home/chr/tsbs/scripts/loadRatioBarh.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png


# #  testcaset 2: devops
# # need define data and result path
# new=`date +%Y_%m%d_%H%M%S`
# BULK_DATA_DIR="/data2/bulk_data_devops_0329" 
# BULK_DATA_DIR_RES_LOAD="/data2/result_load_devops_${new}/" 

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-03T00:00:00Z" \
# DATABASE_HOST="test209" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="12" SERVER_PASSWORD="tbase124!" \
# USE_CASES="devops" FORMATS="influx timescaledb" BATCH_SIZES="10000" \
# SCALES="100 4000 100000 1000000" DATABASE_NAME="benchmarkdev" ./loadtest.sh 

# #generate png report
# # loadResultAnaly.py has three parameter,
# # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# echo "python3 /home/chr/tsbs/scripts/loadResultAnalyBarh.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load.png"
# python3 /home/chr/tsbs/scripts/loadResultAnalyBarh.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load.png

# echo "/home/chr/tsbs/scripts/loadRatioBarh.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png"
# python3 /home/chr/tsbs/scripts/loadRatioBarh.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png


#  testcaset 3: iot
# need define data and result path
new=`date +%Y_%m%d_%H%M%S`
BULK_DATA_DIR="/data2/bulk_data_iot_0412" 
BULK_DATA_DIR_RES_LOAD="/data2/result_load_iot_${new}/" 

# excute testcase
TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-03T00:00:00Z" \
DATABASE_HOST="test209" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="12" SERVER_PASSWORD="tbase124!" \
USE_CASES="iot" FORMATS="TDengine influx timescaledb" BATCH_SIZES="10000" \
SCALES="40000" DATABASE_NAME="benchmarkiot" ./loadtest.sh 

# #generate png report
# # loadResultAnaly.py has three parameter,
# # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# echo "python3 /home/chr/tsbs/scripts/loadResultAnalyBarh.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load.png"
# python3 /home/chr/tsbs/scripts/loadResultAnalyBarh.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load.png

# echo "/home/chr/tsbs/scripts/loadRatioBarh.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png"
# python3 /home/chr/tsbs/scripts/loadRatioBarh.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png

