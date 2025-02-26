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
    load_resultDir="${loadResultRootDir}/load_result_${caseType}_${load_executeTime}/" 

    query_dataDir="${queryDataRootDir}/query_data_${caseType}/" 
    query_resultDir="${queryResultRootDir}/query_result_${caseType}_${load_executeTime}/" 

    TS_START=$3 QUERY_TS_END=$5 LOAD_TS_END=$4 \
    DATABASE_HOST=$1 SERVER_PASSWORD=$2  \
    BULK_DATA_DIR=${load_dataDir}  BULK_DATA_DIR_RES_LOAD=${load_resultDir}   \
    BULK_DATA_QUERY_DIR=${query_dataDir}  BULK_DATA_DIR_RUN_RES=${query_resultDir} \
    NUM_WORKERS=$8 USE_CASES=$7 FORMATS=$9 VGROUPS="$vgroups" \
    QUERY_DEBUG="false" RELOADDATA="${reloaddata}" QUERIES=${10} \
    SCALES=$6 DATABASE_NAME="benchmark$caseType" \
    QUERY_TYPES_ALL=${query_types_cpu_all} QUERY_TYPES_IOT_ALL=${query_types_iot_all} ./querytest.sh 

    if [  ${caseType} != "userdefined" ] && [  ${report} == "true" ]; then
        # generate png 
        echo "python3 ${scriptDir}/gen_report/queryResultBarh.py  ${query_resultDir}/query_input.csv queryType  ${query_resultDir}/test_query_barh.png ${10} "
        echo "python3 ${scriptDir}/gen_report/queryRatioBarh.py  ${query_resultDir}/query_input.csv  queryType  ${query_resultDir}/test_query_barRatio.png  ${10}"

        python3 ${scriptDir}/gen_report/queryResultBarh.py  ${query_resultDir}/query_input.csv queryType  ${query_resultDir}/test_query_barh.png   ${10}
        python3 ${scriptDir}/gen_report/queryRatioBarh.py  ${query_resultDir}/query_input.csv  queryType  ${query_resultDir}/test_query_barRatio.png ${10}
    fi
}


# caseType [cputest | cpu| devops | iot ]
echo "caseType: ${caseType}"
if [ "${caseType}" == "cputest" ];then
    echo "query_testcase ${serverHost} ${serverPass}  ${query_ts_start} ${query_load_ts_end}  ${query_ts_end} ${query_scales} cpu-only ${query_number_wokers}  ${query_formats} ${query_times_cpu}"
    query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "cpu-only" "${query_number_wokers}"  "${query_formats}" "${query_times_cpu}"

elif [ "${caseType}" == "iottest" ];then
    echo "query_testcase ${serverHost} ${serverPass}  ${query_ts_start} ${query_load_ts_end}  ${query_ts_end} ${query_scales} iot ${query_number_wokers}  ${query_formats} ${query_times_iot}"
    query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "iot" "${query_number_wokers}"  "${query_formats}" "${query_times_iot}"

elif [ "${caseType}" == "cpu" ];then
    query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "cpu-only" "${query_number_wokers}" "${query_formats}" "${query_times_cpu}"
    #query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z"  "100" "cpu-only" "${query_number_wokers}" "influx TDengine timescaledb" "${query_times}"
    #query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z"  "4000"  "cpu-only" "${query_number_wokers}" "influx TDengine timescaledb" "${query_times}"

elif [ "${caseType}" == "devops" ];then
    query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "devops" "${query_number_wokers}" "${query_formats}" "${query_times_default}"
    #query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z"  "100"  "devops" "${query_number_wokers}" "influx TDengine timescaledb" "${query_times}"
    #query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z"  "4000"  "devops" "${query_number_wokers}" "influx TDengine timescaledb" "${query_times}"

elif [ "${caseType}" == "iot" ];then
    query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "iot" "${query_number_wokers}" "${query_formats}" "${query_times_iot}"
    #query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z"  "100"  "iot" "4"  "influx TDengine timescaledb"  "10000"
    #query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z"  "4000"  "iot" "4" "influx TDengine timescaledb"  "500"

elif [ "${caseType}" == "userdefined" ];then
    query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "${case}" "${query_number_wokers}" "${query_formats}" "${query_times_default}"

else
    echo "please set correct testcase type"
fi

