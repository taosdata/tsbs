set -e

scriptDir=$(dirname $(readlink -f $0))
cd ${scriptDir}
source ./test.ini

echo "${serverHost}","${caseType}"
function load_testcase {
    #  testcaset
    # need define data and result path
    echo "excute testcase scenarios $5"
    load_executeTime=`date +%Y_%m%d_%H%M%S`
    load_dataDir="${loadDataRootDir}/load_data_${caseType}_host/" 
    load_resultDir="${loadResultRootDir}/load_result_${caseType}_${load_executeTime}/" 

    # excute testcase
    echo "TS_START="$3" TS_END="$4"  DATABASE_HOST="$1" SERVER_PASSWORD="$2" BULK_DATA_DIR=${load_dataDir} BULK_DATA_DIR_RES_LOAD=${load_resultDir}  NUM_WORKERS="$7" USE_CASES="$6" FORMATS="$9" BATCH_SIZES="$8" CASE_TYPE=${caseType} SCALES="$5" DATABASE_NAME="benchmark$caseType"  WALFSYNCPERIOD="$load_fsync"  VGROUPS="$vgroups" ./loadtest.sh "

    TS_START="$3" TS_END="$4"  \
    DATABASE_HOST="$1" SERVER_PASSWORD="$2"  \
    BULK_DATA_DIR=${load_dataDir} BULK_DATA_DIR_RES_LOAD=${load_resultDir} \
    NUM_WORKERS="$7" USE_CASES="$6" FORMATS="$9" BATCH_SIZES="$8" CASE_TYPE=${caseType} \
    SCALES="$5" DATABASE_NAME="benchmark$caseType" WALFSYNCPERIOD="$load_fsync"  VGROUPS="$vgroups" TRIGGER=${triggers} ./loadtest.sh 


    if [ ${caseType} != "userdefined" ] && [ ${report} == "true" ]; then
        #generate png report
        # loadResultAnaly.py has three parameter,
        # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
        echo "python3 ${scriptDir}/gen_report/loadResultAnalyBarh.py  ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load.png"
        python3 ${scriptDir}/gen_report/loadResultAnalyBarh.py  ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load.png

        echo "${scriptDir}/gen_report/loadRatioBarh.py ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load_ratio.png"
        python3 ${scriptDir}/gen_report/loadRatioBarh.py ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load_ratio.png
    fi
}

# caseType [cputest | cpu| devops | iot ]
echo "caseType: ${caseType}"
if [ "${caseType}" == "cputest" ];then
    echo "load_testcase ${serverHost} ${serverPass}  ${load_ts_start} ${load_ts_end}  ${load_scales} cpu-only ${load_number_workers} ${load_batchsizes} ${load_formats}"
    load_testcase ${serverHost} ${serverPass}  "${load_ts_start}" "${load_ts_end}"  "${load_scales}" "cpu-only" "${load_number_workers}" "${load_batchsizes}" "${load_formats}"

elif [ "${caseType}" == "iottest" ];then
    echo "load_testcase ${serverHost} ${serverPass}  ${load_ts_start} ${load_ts_end}  ${load_scales} iot ${load_number_workers} ${load_batchsizes} ${load_formats}"
    load_testcase ${serverHost} ${serverPass}  "${load_ts_start}" "${load_ts_end}"  "${load_scales}" "iot" "${load_number_workers}" "${load_batchsizes}" "${load_formats}"

elif [ "${caseType}" == "cpu" ];then
    load_testcase ${serverHost} ${serverPass}  "${load_ts_start}" "${load_ts_end}"  "${load_scales}" "cpu-only" "${load_number_workers}" "${load_batchsizes}" "${load_formats}"

elif [ "${caseType}" == "devops" ];then
    load_testcase ${serverHost} ${serverPass}  "${load_ts_start}" "${load_ts_end}"  "${load_scales}"  "devops" "${load_number_workers}" "${load_batchsizes}" "${load_formats}"

elif [ "${caseType}" == "iot" ];then
    load_testcase ${serverHost} ${serverPass}  "${load_ts_start}" "${load_ts_end}"  "${load_scales}" "iot" "${load_number_workers}" "${load_batchsizes}" "${load_formats}"

elif [ "${caseType}" == "userdefined" ];then
    load_testcase ${serverHost} ${serverPass}  "${load_ts_start}" "${load_ts_end}"   "${load_scales}" "${case}" "${load_number_workers}" "${load_batchsizes}" "${load_formats}"

else  
    echo "please set correct testcase type"
fi
