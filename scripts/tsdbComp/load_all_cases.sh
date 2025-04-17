set -e

scriptDir=$(dirname $(readlink -f $0))
cd ${scriptDir}
source ${scriptDir}/common.sh
source ${scriptDir}/logger.sh

log_info "${serverHost}","${caseType}"
function load_testcase {
    #  testcaset
    # need define data and result path
    log_info "excute testcase scenarios $5"
    load_executeTime=`date +%Y_%m%d_%H%M%S`
    load_dataDir="${loadDataRootDir}/load_data_${caseType}_host/" 
    load_resultDir="${loadResultRootDir}/load_result_${caseType}_${load_executeTime}/" 

    export DATABASE_HOST="$1"
    export SERVER_PASSWORD="$2"
    export TIME_SCALE_STR="$3"
    export BULK_DATA_DIR=${load_dataDir}
    export BULK_DATA_DIR_RES_LOAD=${load_resultDir}
    export NUM_WORKERS="$6"
    export USE_CASE="$5"
    export FORMATS="$8"
    export BATCH_SIZES="$7"
    export CASE_TYPE=${caseType}
    export SCALES="$4"
    export DATABASE_NAME="benchmark$caseType"
    export WALFSYNCPERIOD="$load_fsync"
    export VGROUPS="$vgroups"
    export TRIGGER=${trigger}
    export HORIZONTAL_SCALING_FACTOR=${horizontal_scaling_factor}
    
    log_info "Executing load_test.sh with environment variables"
    log_debug "DATABASE_HOST=$DATABASE_HOST SERVER_PASSWORD=$SERVER_PASSWORD DATABASE_NAME=$DATABASE_NAME \
        BULK_DATA_DIR=${BULK_DATA_DIR} BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD}  \
        NUM_WORKERS=$NUM_WORKERS USE_CASE=$USE_CASE FORMATS=$FORMATS BATCH_SIZES=$BATCH_SIZES CASE_TYPE=${CASE_TYPE} SCALES=$SCALES \
        WALFSYNCPERIOD=$load_fsync  VGROUPS=$vgroups"
    ./load_test.sh

    if [ ${caseType} != "userdefined" ] && [ ${report} == "true" ]; then
        #generate png report
        # loadResultAnaly.py has three parameter,
        # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
        log_info "python3 ${scriptDir}/load_report.py -i  ${load_resultDir}/load_input.csv -x SCALE -o ${load_resultDir}/test_load.png"
        execute_python_file ${scriptDir} ${scriptDir}/load_report.py -i  ${load_resultDir}/load_input.csv -x SCALE -o ${load_resultDir}/test_load.png

        log_info "python3 ${scriptDir}/load_report.py -i  ${load_resultDir}/load_input.csv -x SCALE -o ${load_resultDir}/test_load.png -m ratio"
        execute_python_file ${scriptDir} ${scriptDir}/load_report.py -i  ${load_resultDir}/load_input.csv -x SCALE -o ${load_resultDir}/test_load.png -m ratio

        log_info "python3 ${scriptDir}/load_report.py -i  ${load_resultDir}/load_input.csv -x SCALE -o ${load_resultDir}/test_load.png -m diskusage"
        execute_python_file ${scriptDir} ${scriptDir}/load_report.py -i  ${load_resultDir}/load_input.csv -o ${load_resultDir}/test_load.png -m diskusage
    fi
}

# caseType [cputest | cpu| devops | iot ]
log_info "caseType: ${caseType}"
if [ "${caseType}" == "cputest" ];then
    log_info "load_testcase ${serverHost} ${serverPass}  ${load_test_time_scale_str} ${LoadTest_load_scales} cpu-only ${load_number_workers} ${load_batch_sizes} ${load_formats}"
    load_testcase ${serverHost} ${serverPass}  "${load_test_time_scale_str}"  "${LoadTest_load_scales}" "cpu-only" "${load_number_workers}" "${load_batch_sizes}" "${load_formats}"

elif [ "${caseType}" == "iottest" ];then
    log_info "load_testcase ${serverHost} ${serverPass} ${load_test_time_scale_str} ${LoadTest_load_scales} iot ${load_number_workers} ${load_batch_sizes} ${load_formats}"
    load_testcase ${serverHost} ${serverPass} "${load_test_time_scale_str}"  "${LoadTest_load_scales}" "iot" "${load_number_workers}" "${load_batch_sizes}" "${load_formats}"

elif [ "${caseType}" == "cpu" ];then
    log_info "load_testcase ${serverHost} ${serverPass}  ${load_time_scale_str}  ${load_scales} cpu-only ${load_number_workers} ${load_batch_sizes} ${load_formats}"
    load_testcase ${serverHost} ${serverPass}  "${load_time_scale_str}"  "${load_scales}" "cpu-only" "${load_number_workers}" "${load_batch_sizes}" "${load_formats}"

elif [ "${caseType}" == "devops" ];then
    load_testcase ${serverHost} ${serverPass}  "${load_time_scale_str}"  "${load_scales}"  "devops" "${load_number_workers}" "${load_batch_sizes}" "${load_formats}"

elif [ "${caseType}" == "iot" ];then
    log_info "load_testcase ${serverHost} ${serverPass}  ${load_time_scale_str}  ${load_scales} iot ${load_number_workers} ${load_batch_sizes} ${load_formats}"
    load_testcase ${serverHost} ${serverPass}  "${load_time_scale_str}"  "${load_scales}" "iot" "${load_number_workers}" "${load_batch_sizes}" "${load_formats}"

elif [ "${caseType}" == "userdefined" ];then
    load_testcase ${serverHost} ${serverPass}  "${load_time_scale_str}"  "${load_scales}" "${case}" "${load_number_workers}" "${load_batch_sizes}" "${load_formats}"

else  
    log_error "please set correct testcase type"
fi
