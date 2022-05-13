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
source ./test.ini

echo "${serverHost}"
function load_testcase {
#  testcaset
# need define data and result path
echo "excute testcase scenarios $5"
load_executeTime=`date +%Y_%m%d_%H%M%S`
load_dataDir="${loadDataRootDir}/load_data_${caseType}/" 
load_resultDir="${loadRsultRootDir}/load_result_${caseType}_${load_executeTime}/" 

# excute testcase
TS_START=$3 TS_END=$4  \
DATABASE_HOST=$1 SERVER_PASSWORD=$2  \
BULK_DATA_DIR=${load_dataDir} BULK_DATA_DIR_RES_LOAD=${load_resultDir} \
NUM_WORKERS=$7 USE_CASES=$6 FORMATS=$9 BATCH_SIZES=$8  \
SCALES=$5 DATABASE_NAME="benchmark$caseType" ./loadtest.sh 

#generate png report
# loadResultAnaly.py has three parameter,
# 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
echo "python3 ${scriptDir}/loadResultAnalyBarh.py  ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load.png"
python3 ${scriptDir}/loadResultAnalyBarh.py  ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load.png

echo "${scriptDir}/loadRatioBarh.py ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load_ratio.png"
python3 ${scriptDir}/loadRatioBarh.py ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load_ratio.png

}

# caseType [cputest | cpu| devops | iot ]
if [ ${caseType} == "cputest" ];then
    echo "load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-01T12:00:00Z"  "200" "cpu-only" "${load_number_woker}" "${load_batchsizes}" "${load_formats}" "
    load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-01T12:00:00Z"  "200" "cpu-only" "${load_number_woker}" "${load_batchsizes}" "${load_formats}"
elif [ ${caseType} == "cpu" ];then
    load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z"  "100 4000 100000 1000000 10000000" "cpu-only" "${load_number_woker}" "${load_batchsizes}" "TDengine influx timescaledb"
elif [ ${caseType} == "devops" ];then
    load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z"  "100 4000 100000 1000000 10000000"  "devops" "${load_number_woker}" "${load_batchsizes}" "TDengine influx timescaledb"
elif [ ${caseType} == "iot" ];then
    load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z"  "100 4000 100000 1000000 10000000" "iot" "${load_number_woker}" "${load_batchsizes}" "TDengine influx timescaledb"
elif [ ${caseType} == "userdefined" ];then
    load_testcase ${serverHost} ${serverPass}  "${load_ts_start}" "${load_ts_end}"   "${load_test_scales}" "iot" "${load_number_woker}" "${load_batchsizes}" "${load_formats}"
else  
    echo "please set correct testcase type"
fi





# #  testcaset 3: iot
# # need define data and result path
# new=`date +%Y_%m%d_%H%M%S`
# BULK_DATA_DIR="/data2/bulk_data_iot_0412" 
# BULK_DATA_DIR_RES_LOAD="/data2/result_load_iot_${new}/" 

# # excute testcase
# TS_START="2016-01-01T00:00:00Z" TS_END="2016-01-03T00:00:00Z" \
# DATABASE_HOST="${serverHost}" BULK_DATA_DIR_RES_LOAD=${BULK_DATA_DIR_RES_LOAD} \
# BULK_DATA_DIR=${BULK_DATA_DIR} NUM_WORKERS="12" SERVER_PASSWORD="${serverPass}" \
# USE_CASES="iot" FORMATS="TDengine influx timescaledb" BATCH_SIZES="10000" \
# SCALES="40000" DATABASE_NAME="benchmarkiot" ./loadtest.sh 

# #generate png report
# # loadResultAnaly.py has three parameter,
# # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
# echo "python3 ${scriptDir}/loadResultAnalyBarh.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load.png"
# python3 ${scriptDir}/loadResultAnalyBarh.py  ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load.png

# echo "${scriptDir}/loadRatioBarh.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png"
# python3 ${scriptDir}/loadRatioBarh.py ${BULK_DATA_DIR_RES_LOAD}/load_input.csv  SCALE ${BULK_DATA_DIR_RES_LOAD}/test_load_ratio.png

