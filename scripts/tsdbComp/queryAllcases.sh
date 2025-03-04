scriptDir=$(dirname $(readlink -f $0))
cd ${scriptDir}
source ${scriptDir}/common.sh
source ${scriptDir}/logger.sh

function query_testcase {
    #  testcaset
    # need define data and result path
    log_info "excute testcase scenarios $5"
    load_executeTime=`date +%Y_%m%d_%H%M%S`
    load_dataDir="${loadDataRootDir}/load_data_${caseType}_host/" 
    load_resultDir="${loadResultRootDir}/load_result_${caseType}_${load_executeTime}/" 

    query_dataDir="${queryDataRootDir}/query_data_${caseType}/" 
    query_resultDir="${queryResultRootDir}/query_result_${caseType}_${load_executeTime}/" 

    log_debug "TS_START=$3 QUERY_TS_END=$5 LOAD_TS_END=$4 \
    DATABASE_HOST=$1 SERVER_PASSWORD=$2  \
    BULK_DATA_DIR=${load_dataDir}  BULK_DATA_DIR_RES_LOAD=${load_resultDir}   \
    BULK_DATA_QUERY_DIR=${query_dataDir}  BULK_DATA_DIR_RUN_RES=${query_resultDir} \
    NUM_WORKERS=$8 USE_CASE=$7 FORMATS=$9 VGROUPS="$vgroups" \
    QUERY_DEBUG="${query_debug}" RELOADDATA="${reload_data}" QUERIES=${10} \
    SCALE=$6 DATABASE_NAME="benchmark$caseType" \
    NUM_WORKER_LOAD=${query_load_workers} BATCH_SIZE=${query_load_batch_size}\
    QUERY_TYPES_ALL=${query_types_cpu_all} QUERY_TYPES_IOT_ALL=${query_types_iot_all} ./querytest.sh "
    TS_START=$3 QUERY_TS_END=$5 LOAD_TS_END=$4 \
    DATABASE_HOST=$1 SERVER_PASSWORD=$2  \
    BULK_DATA_DIR=${load_dataDir}  BULK_DATA_DIR_RES_LOAD=${load_resultDir}   \
    BULK_DATA_QUERY_DIR=${query_dataDir}  BULK_DATA_DIR_RUN_RES=${query_resultDir} \
    NUM_WORKERS=$8 USE_CASE=$7 FORMATS=$9 VGROUPS="$vgroups" \
    QUERY_DEBUG="${query_debug}" RELOADDATA="${reload_data}" QUERIES=${10} \
    SCALE=$6 DATABASE_NAME="benchmark$caseType" \
    NUM_WORKER_LOAD=${query_load_workers} BATCH_SIZE=${query_load_batch_size}\
    QUERY_TYPES_ALL=${query_types_cpu_all} QUERY_TYPES_IOT_ALL=${query_types_iot_all} ./querytest.sh 

    if [  ${caseType} != "userdefined" ] && [  ${report} == "true" ]; then
        # generate png 
        log_info "python3 ${scriptDir}/gen_report/query_report.py  -i  ${query_resultDir}/query_input.csv -x queryType -o  ${query_resultDir}/test_query.png -q ${10}"
        log_info "python3 ${scriptDir}/gen_report/queryResultBarh.py  -i  ${query_resultDir}/query_input.csv -x queryType -o  ${query_resultDir}/test_query.png  -q ${10} -m ratio"

        python3 ${scriptDir}/gen_report/query_report.py  -i  ${query_resultDir}/query_input.csv -x queryType -o  ${query_resultDir}/test_query.png -q ${10}
       python3 ${scriptDir}/gen_report/query_report.py  -i  ${query_resultDir}/query_input.csv -x queryType -o  ${query_resultDir}/test_query.png  -q ${10} -m ratio
    fi
}


# caseType [cputest | cpu| devops | iot ]
log_info "caseType: ${caseType}"
if [ "${caseType}" == "cpu" ] || [ "${caseType}" == "cputest" ];then
    if [ "${caseType}" == "cputest" ];then
        query_cpu_scale_times=${QueryTest_query_cpu_scale_times}
        query_ts_end=${QueryTest_query_ts_end}
        query_load_ts_end=${QueryTest_query_load_ts_end}
        query_ts_start=${QueryTest_query_ts_start}
    fi
    # 解析  query_cpu_scale_times 得 scale 和 query_times
    IFS=' ' read -r -a cpu_scale_times <<< "${query_cpu_scale_times}"
    for pair in "${cpu_scale_times[@]}"; do
        IFS=',' read -r scale times <<< "$pair"
        log_info "query_testcase ${serverHost} ${serverPass} ${query_ts_start} ${query_load_ts_end} ${query_ts_end} ${scale} cpu-only ${query_number_workers} ${query_formats} ${times}"
        query_testcase ${serverHost} ${serverPass} "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${scale}" "cpu-only" "${query_number_workers}" "${query_formats}" "${times}"
    done

elif [ "${caseType}" == "devops" ];then
    IFS=' ' read -r -a devops_scale_times <<< "${query_devops_scale_times}"
    for pair in "${devops_scale_times[@]}"; do
        IFS=',' read -r scale times <<< "$pair"
        log_info "query_testcase ${serverHost} ${serverPass} ${query_ts_start} ${query_load_ts_end} ${query_ts_end} ${scale} devops ${query_number_workers} ${query_formats} ${times}"
        query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${scale}" "devops" "${query_number_workers}" "${query_formats}" "${times}"
    done

elif [ "${caseType}" == "iot" ] || [ "${caseType}" == "iottest" ];then
    if [ "${caseType}" == "iottest" ];then
        query_iot_scale_times=${QueryTest_query_iot_scale_times}
        query_ts_end=${QueryTest_query_ts_end}
        query_load_ts_end=${QueryTest_query_load_ts_end}
        query_ts_start=${QueryTest_query_ts_start}
    fi
    # 解析  query_iot_scale_times 得 scale 和 query_times
    IFS=' ' read -r -a iot_scale_times <<< "${query_iot_scale_times}"
    for pair in "${iot_scale_times[@]}"; do
        IFS=',' read -r scale times <<< "$pair"
        log_info "query_testcase ${serverHost} ${serverPass} ${query_ts_start} ${query_load_ts_end} ${query_ts_end} ${scale} iot ${query_number_workers} ${query_formats} ${times}"
        query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${scale}" "iot" "${query_number_workers}" "${query_formats}" "${times}"
    done

elif [ "${caseType}" == "userdefined" ];then
    IFS=' ' read -r -a devops_scale_times <<< "${query_devops_scale_times}"
    for pair in "${devops_scale_times[@]}"; do
        IFS=',' read -r scale times <<< "$pair"
        log_info "query_testcase ${serverHost} ${serverPass} ${query_ts_start} ${query_load_ts_end} ${query_ts_end} ${scale} ${case} ${query_number_workers} ${query_formats} ${times}"
        query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "${case}" "${query_number_workers}" "${query_formats}" "${times}"
    done
    
else
    log_error "please set correct testcase type"
fi

