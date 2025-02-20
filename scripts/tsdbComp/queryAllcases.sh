
set -e

scriptDir=$(dirname $(readlink -f $0))
cd ${scriptDir}
source ./test.ini

function query_testcase {
#  testcaset
# need define data and result path
echo "testcase scenarios $5"
load_executeTime=`date +%Y_%m%d_%H%M%S`
load_dataDir="${loadDataRootDir}/load_data_${caseType}_host/" 
load_resultDir="${loadRsultRootDir}/load_result_${caseType}_${load_executeTime}/" 

query_dataDir="${queryDataRootDir}/query_data_${caseType}/" 
query_resultDir="${queryRsultRootDir}/query_result_${caseType}_${load_executeTime}/" 

# excute testcase
# this two para can be set，the default is all query type。
# QUERY_TYPES_ALL="cpu-max-all-1 single-groupby-5-8-1" \
# QUERY_TYPES_IOT_ALL="last-loc avg-load" \


TS_START=$3 QUERY_TS_END=$5 LOAD_TS_END=$4 \
DATABASE_HOST=$1 SERVER_PASSWORD=$2  \
BULK_DATA_DIR=${load_dataDir}  BULK_DATA_DIR_RES_LOAD=${load_resultDir}   \
BULK_DATA_QUERY_DIR=${query_dataDir}  BULK_DATA_DIR_RUN_RES=${query_resultDir} \
NUM_WORKERS=$8 USE_CASES=$7 FORMATS=$9 VGROUPS="$vgroups" \
QUERY_DEBUG="false" RESTLOAD="true" QUERIES=${10} \
SCALES=$6 DATABASE_NAME="benchmark$caseType" ./querytest.sh 

if [ ${caseType} != "userdefined" ];then
    # generate png 
    echo "python3 ${scriptDir}/queryResultBarh.py  ${query_resultDir}/query_input.csv queryType  ${query_resultDir}/test_query_barh.png ${10} "
    echo "python3 ${scriptDir}/queryRatioBarh.py  ${query_resultDir}/query_input.csv  queryType  ${query_resultDir}/test_query_barRatio.png  ${10}"

    python3 ${scriptDir}/queryResultBarh.py  ${query_resultDir}/query_input.csv queryType  ${query_resultDir}/test_query_barh.png   ${10}
    python3 ${scriptDir}/queryRatioBarh.py  ${query_resultDir}/query_input.csv  queryType  ${query_resultDir}/test_query_barRatio.png ${10}
fi
}


# caseType [cputest | cpu| devops | iot ]
echo "caseType: ${caseType}"
if [ "${caseType}" == "cputest" ];then
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-01T12:00:00Z" "2016-01-01T12:00:01Z" "200" "cpu-only" "${query_number_wokers}"  "TDengine influx timescaledb" "10" "
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-01T12:00:00Z" "2016-01-01T12:00:01Z" "200" "cpu-only" "${query_number_wokers}"  "TDengine influx timescaledb" "10"

elif [ "${caseType}" == "iottest" ];then
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-01T12:00:00Z" "2016-01-01T12:00:01Z" "200" "iot" "${query_number_wokers}"  "TDengine influx timescaledb" "10" "
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-01T12:00:00Z" "2016-01-01T12:00:01Z" "200" "iot" "${query_number_wokers}"  "TDengine influx timescaledb" "10"

elif [ "${caseType}" == "cpu" ];then
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "cpu-only" "${query_number_wokers}" "TDengine timescaledb influx " "${query_times}"
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100" "cpu-only" "${query_number_wokers}" "TDengine timescaledb influx" "${query_times}"

elif [ "${caseType}" == "devops" ];then
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100"  "devops" "${query_number_wokers}" "TDengine influx timescaledb" "${query_times}"
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "devops" "${query_number_wokers}" "TDengine influx timescaledb" "${query_times}"

elif [ "${caseType}" == "iot" ];then
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100"  "iot" "4"  "TDengine timescaledb influx"  "10000"
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "iot" "4" "TDengine timescaledb influx"  "500"

elif [ "${caseType}" == "userdefined" ];then
    query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "${case}" "${query_number_wokers}" "${query_formats}" "${query_times}"

else
    echo "please set correct testcase type"
fi

