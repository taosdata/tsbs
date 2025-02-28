set -e

scriptDir=$(dirname $(readlink -f $0))
cd ${scriptDir}
source ${scriptDir}/logger.sh

function query_testcase {
    #  testcaset
    # need define data and result path
    log_info "testcase scenarios $5"
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
    QUERY_DEBUG="${query_debug}" RELOADDATA="${reload_data}" QUERIES=${10} \
    SCALES=$6 DATABASE_NAME="benchmark$caseType" \
    QUERY_TYPES_ALL=${query_types_cpu_all} QUERY_TYPES_IOT_ALL=${query_types_iot_all} ./querytest.sh 

    if [  ${caseType} != "userdefined" ] && [  ${report} == "true" ]; then
        # generate png 
        log_info "python3 ${scriptDir}/gen_report/queryResultBarh.py  ${query_resultDir}/query_input.csv queryType  ${query_resultDir}/test_query_barh.png ${10} "
        log_info "python3 ${scriptDir}/gen_report/queryRatioBarh.py  ${query_resultDir}/query_input.csv  queryType  ${query_resultDir}/test_query_barRatio.png  ${10}"

        python3 ${scriptDir}/gen_report/queryResultBarh.py  ${query_resultDir}/query_input.csv queryType  ${query_resultDir}/test_query_barh.png   ${10}
        python3 ${scriptDir}/gen_report/queryRatioBarh.py  ${query_resultDir}/query_input.csv  queryType  ${query_resultDir}/test_query_barRatio.png ${10}
    fi
}


# caseType [cputest | cpu| devops | iot ]
log_info "caseType: ${caseType}"
if [ "${caseType}" == "cpu" ] || [ "${caseType}" == "cputest" ];then
    if [ "${caseType}" == "cputest" ];then
        query_cpu_scale_times=${QueryTest_query_cpu_scale_times}
    fi
    # 解析  query_cpu_scale_times 得 scale 和 query_times
    IFS=' ' read -r -a cpu_scale_times <<< "${query_cpu_scale_times}"
    for pair in "${cpu_scale_times[@]}"; do
        IFS=',' read -r scale times <<< "$pair"
        log_info "query_testcase ${serverHost} ${serverPass} ${query_ts_start} ${query_load_ts_end} ${query_ts_end} ${scale} cpu-only ${query_number_wokers} ${query_formats} ${times}"
        query_testcase ${serverHost} ${serverPass} "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${scale}" "cpu-only" "${query_number_wokers}" "${query_formats}" "${times}"
    done

elif [ "${caseType}" == "devops" ];then
    IFS=' ' read -r -a devops_scale_times <<< "${query_devops_scale_times}"
    for pair in "${devops_scale_times[@]}"; do
        IFS=',' read -r scale times <<< "$pair"
        log_info "query_testcase ${serverHost} ${serverPass} ${query_ts_start} ${query_load_ts_end} ${query_ts_end} ${scale} devops ${query_number_wokers} ${query_formats} ${times}"
        query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${scale}" "devops" "${query_number_wokers}" "${query_formats}" "${times}"
    done

elif [ "${caseType}" == "iot" ] || [ "${caseType}" == "iottest" ];then
    if [ "${caseType}" == "iottest" ];then
        query_iot_scale_times=${QueryTest_query_iot_scale_times}
    fi
    # 解析  query_iot_scale_times 得 scale 和 query_times
    IFS=' ' read -r -a iot_scale_times <<< "${query_iot_scale_times}"
    for pair in "${iot_scale_times[@]}"; do
        IFS=',' read -r scale times <<< "$pair"
        log_info "query_testcase ${serverHost} ${serverPass} ${query_ts_start} ${query_load_ts_end} ${query_ts_end} ${scale} iot ${query_number_wokers} ${query_formats} ${times}"
        query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${scale}" "iot" "${query_number_wokers}" "${query_formats}" "${times}"
    done

elif [ "${caseType}" == "userdefined" ];then
    IFS=' ' read -r -a devops_scale_times <<< "${query_devops_scale_times}"
    for pair in "${devops_scale_times[@]}"; do
        IFS=',' read -r scale times <<< "$pair"
        log_info "query_testcase ${serverHost} ${serverPass} ${query_ts_start} ${query_load_ts_end} ${query_ts_end} ${scale} ${case} ${query_number_wokers} ${query_formats} ${times}"
        query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "${case}" "${query_number_wokers}" "${query_formats}" "${times}"
    done
    
else
    log_error "please set correct testcase type"
fi

