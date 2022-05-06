# add your testcase :

set -e
# set parameters by default value
osType=ubuntu   # -o [centos | ubuntu]
installGoEnv=false
installDB=false
installTsbs=false
serverHost=test209
serverPass="taosdata!"
caseType=cputest

while getopts "hs:p:o:g:d:c:t:" arg
do
  case $arg in
    o)
      osType=$(echo $OPTARG)
      ;;
    s)
      serverHost=$(echo $OPTARG)
      ;;
    p)
      serverPass=$(echo $OPTARG)
      ;;
    g)
      installGoEnv=$(echo $OPTARG)
      ;;
    d)
      installDB=$(echo $OPTARG)
      ;;
    t)
      installTsbs=$(echo $OPTARG)
      ;;
    c)
      caseType=$(echo $OPTARG)
      ;; 
    h)
      echo "Usage: `basename $0` -o osType [centos | ubuntu]
                              -s server host or ip
                              -p server Password
                              -g installGoEnv [true | false]
                              -d installDB [true | false]           
                              -t installTsbs [true | false]
                              -c caseType [cputest | cpu| devops | iot ]
                              -h get help         
      osType's default values is  ubuntu,other is false"
      exit 0
      ;;
    ?) #unknow option
      echo "unkonw argument"
      exit 1
      ;;
  esac
done

scriptDir=$(dirname $(readlink -f $0))

cd ${scriptDir}

function testcase {
#  testcaset
# need define data and result path
echo "testcase scenarios $5"
new=`date +%Y_%m%d_%H%M%S`

BULK_DATA_DIR="/data2/bulk_data_cpu-only"
BULK_DATA_DIR_RES_LOAD="/data2/bulk_result_load_${new}/"

BULK_DATA_QUERY_DIR="/data2/bulk_data_query_cpu-only" 
BULK_DATA_DIR_RUN_RES="/data2/bulk_result_query_cpu-only_${new}/" 

# excute testcase
# this two para can be set，the default is all query type。
# QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# QUERY_TYPES_IOT_ALL="last-loc avg-load" \


TS_START="2016-01-01T00:00:00Z" QUERY_TS_END=$3 LOAD_TS_END=$4 \
DATABASE_HOST=$1 SERVER_PASSWORD=$2  \
BULK_DATA_DIR=${BULK_DATA_DIR}  BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD}   \
BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
NUM_WORKERS="12" USE_CASES=$6 FORMATS="TDengine influx timescaledb" \
QUERY_DEBUG="false" RESTLOAD="true" QUERIES="1000" \
SCALES=$5 DATABASE_NAME="benchmark$caseType" ./querytest.sh 

# generate png 
python3 ${scriptDir}/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barh_100.png
python3 ${scriptDir}/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/query_input.csv  queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_4000.png

}


# caseType [cputest | cpu-only | devops | iot ]
if [ ${caseType} == "cputest" ];then
    testcase ${serverHost} ${serverPass}  "2016-01-01T12:00:01Z" "2016-01-01T12:00:00Z"  "200" "cpu-only"
elif [ ${caseType} == "cpu" ];then
    testcase ${serverHost} ${serverPass}  "2016-01-05T00:00:01Z" "2016-01-05T00:00:00Z"  "100"  "cpu-only"
    testcase ${serverHost} ${serverPass}  "2016-01-05T00:00:01Z" "2016-01-05T00:00:00Z"  "4000"  "cpu-only"
elif [ ${caseType} == "devops" ];then
    testcase ${serverHost} ${serverPass}  "2016-01-05T00:00:01Z" "2016-01-05T00:00:00Z"  "100"  "devops"
    testcase ${serverHost} ${serverPass}  "2016-01-05T00:00:01Z" "2016-01-05T00:00:00Z"  "4000"  "devops"
elif [ ${caseType} == "iot" ];then
    testcase ${serverHost} ${serverPass}  "2016-01-05T00:00:01Z" "2016-01-05T00:00:00Z"  "100"  "iot"
    testcase ${serverHost} ${serverPass}  "2016-01-05T00:00:01Z" "2016-01-05T00:00:00Z"  "4000"  "iot"
else 
    echo "please set correct testcase type"
fi

# #  testcaset---cpu-only
# # need define data and result path
# new=`date +%Y_%m%d_%H%M%S`

# BULK_DATA_QUERY_DIR="/data2/bulk_data_query_cpu-only" 
# BULK_DATA_DIR_RUN_RES="/data2/bulk_result_query_cpu-only_${new}/" 

# BULK_DATA_DIR=${BULK_DATA_DIR:-"/data2/bulk_data_cpu-only"}
# BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD:-"/data2/bulk_result_load_${new}/"}



# # excute testcase（batchsize=50000）
# TS_START="2016-01-01T00:00:00Z" QUERY_TS_END="2016-01-01T12:00:01Z" \
# LOAD_TS_END="2016-01-05T00:00:00Z"  \
# DATABASE_HOST="${serverHost}" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
# BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="14"  SERVER_PASSWORD="${serverPass}" \
# BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# USE_CASES="cpu-only" FORMATS="TDengine timescaledb influx"   \
# SCALES="110" DATABASE_NAME="benchmarkcpu"  ./querytest.sh 

# # generate png 
# awk -F ',' -v OFS=','  '{if($4==100)print$0}' ${BULK_DATA_DIR_RUN_RES}/query_input.csv > ${BULK_DATA_DIR_RUN_RES}/100query_input.csv 
# awk -F ',' -v OFS=','  '{if($4==4000)print$0}' ${BULK_DATA_DIR_RUN_RES}/query_input.csv > ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv
# python3 ${scriptDir}/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/100query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_bar_100.png
# python3 ${scriptDir}/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_bar_4000.png
# python3 ${scriptDir}/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/100query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_100.png
# python3 ${scriptDir}/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv  queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_4000.png


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
# DATABASE_HOST="${serverHost}" BULK_DATA_DIR_RUN_RES=${BULK_DATA_DIR_RUN_RES} \
# BULK_DATA_QUERY_DIR=${BULK_DATA_QUERY_DIR}  NUM_WORKERS="14"  SERVER_PASSWORD="${serverPass}" \
# BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# USE_CASES="iot" FORMATS="TDengine influx timescaledb"  QUERIES="1000" \
# SCALES="4000 100" DATABASE_NAME="benchmarkiot" RESTLOAD="true" ./querytest.sh 

# # generate png 
# awk -F ',' -v OFS=','  '{if($4==100)print$0}' ${BULK_DATA_DIR_RUN_RES}/query_input.csv > ${BULK_DATA_DIR_RUN_RES}/100query_input.csv 
# awk -F ',' -v OFS=','  '{if($4==4000)print$0}' ${BULK_DATA_DIR_RUN_RES}/query_input.csv > ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv
# python3 ${scriptDir}/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/100query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_bar_100.png
# python3 ${scriptDir}/queryResultBarh.py  ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_bar_4000.png
# python3 ${scriptDir}/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/100query_input.csv queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_100.png
# python3 ${scriptDir}/queryRatioBarh.py  ${BULK_DATA_DIR_RUN_RES}/4000query_input.csv  queryType  ${BULK_DATA_DIR_RUN_RES}/test_query_barRatio_4000.png

