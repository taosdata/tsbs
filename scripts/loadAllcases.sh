# add your testcase :


#  testcaset 1---diffrent SCALES=100 300 500 700 900 1000
# need define data and result path
BULK_DATA_DIR="/tmp/bulk_data2/" 
BULK_DATA_DIR_RES_LOAD="/tmp/bulk_result_load2/" 

# excute testcase
TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-01T01:00:00Z" \
DATABASE_HOST="test217" BULK_DATA_DIR_RES_LOAD="/tmp/bulk_result_load2/" \
BULK_DATA_DIR="/tmp/bulk_data2/" NUM_WORKERS="24" \
USE_CASES="devops" \
SCALES="100 300 500 700 900 1000" ./loadtest.sh 

# generate png report
# loadResultAnaly.py has three parameter,
# 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
echo "python3 loadResultAnaly.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv NUM_WORKER test_load2.png"
python3 loadResultAnaly.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv SCALE test_load1.png