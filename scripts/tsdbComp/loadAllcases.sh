# add your testcase :

set -e
# set parameters by default value
# [centos | ubuntu]
osType=ubuntu      
installPath="/usr/local/src/"

# install env
installGoEnv=false
installDB=false
installTsbs=false

#client and server paras
cientIP="192.168.0.203"
clientHost="trd03"
serverIP="192.168.0.204"
serverHost="trd04"
serverPass="taosdata!"

#testcase type
#[cputest | cpu| devops | iot ]
caseType=cputest
case="cpu-only"

# data and result root path
# datapath is bulk_data_rootDir/bulk_data_${caseType} 
# executeTime=`date +%Y_%m%d_%H%M%S`
# resultpath is bulk_data_resultrootdir/load_data_${caseType}_${executeTime}
loadDataRootDir="/data2/"
loadRsultRootDir="/data2/"
queryDataRootDir="/data2/"
queryRsultRootDir="/data2/"


#load test parameters
load_ts_start="2016-01-01T00:00:00Z"
load_ts_end="2016-01-02T00:00:00Z"
load_number_wokers="12"
load_batchsizes="10000"
load_scales="100 4000 100000 1000000 10000000"
load_formats="TDengine influx timescaledb"
load_test_scales="200"
load_fsync="0"
vgroups="24"

#query test parameters
query_ts_start="2016-01-01T00:00:00Z"
query_load_ts_end="2016-01-05T00:00:00Z"
query_ts_end="2016-01-05T00:00:01Z"
query_load_number_wokers="12"
query_number_wokers="12"
query_times="10000"
query_scales="100 4000 100000 1000000 10000000"
query_formats="TDengine influx timescaledb"

# while getopts "hs:p:o:g:d:c:t:" arg
# do
#   case $arg in
#     o)
#       osType=$(echo $OPTARG)
#       ;;
#     s)
#       serverHost=$(echo $OPTARG)
#       ;;
#     p)
#       serverPass=$(echo $OPTARG)
#       ;;
#     g)
#       installGoEnv=$(echo $OPTARG)
#       ;;
#     d)
#       installDB=$(echo $OPTARG)
#       ;;
#     t)
#       installTsbs=$(echo $OPTARG)
#       ;;
#     c)
#       caseType=$(echo $OPTARG)
#       ;; 
#     h)
#       echo "Usage: `basename $0` -o osType [centos | ubuntu]
#                               -s server host or ip
#                               -p server Password
#                               -g installGoEnv [true | false]
#                               -d installDB [true | false]           
#                               -t installTsbs [true | false]
#                               -c caseType [cputest | cpu| devops | iot ]
#                               -h get help         
#       osType's default values is  ubuntu,other is false"
#       exit 0
#       ;;
#     ?) #unknow option
#       echo "unkonw argument"
#       exit 1
#       ;;
#   esac
# done

scriptDir=$(dirname $(readlink -f $0))

cd ${scriptDir}
source ./test.ini

echo "${serverHost}"
function load_testcase {
#  testcaset
# need define data and result path
echo "excute testcase scenarios $5"
load_executeTime=`date +%Y_%m%d_%H%M%S`
load_dataDir="${loadDataRootDir}/load_data_${caseType}_host/" 
load_resultDir="${loadRsultRootDir}/load_result_${caseType}_${load_executeTime}/" 

# excute testcase
echo "TS_START="$3" TS_END="$4"  DATABASE_HOST="$1" SERVER_PASSWORD="$2" BULK_DATA_DIR=${load_dataDir} BULK_DATA_DIR_RES_LOAD=${load_resultDir}  NUM_WORKERS="$7" USE_CASES="$6" FORMATS="$9" BATCH_SIZES="$8" CASE_TYPE=${caseType} SCALES="$5" DATABASE_NAME="benchmark$caseType"  WALFSYNCPERIOD="$load_fsync"  VGROUPS="$vgroups" ./loadtest.sh "

TS_START="$3" TS_END="$4"  \
DATABASE_HOST="$1" SERVER_PASSWORD="$2"  \
BULK_DATA_DIR=${load_dataDir} BULK_DATA_DIR_RES_LOAD=${load_resultDir} \
NUM_WORKERS="$7" USE_CASES="$6" FORMATS="$9" BATCH_SIZES="$8" CASE_TYPE=${caseType} \
SCALES="$5" DATABASE_NAME="benchmark$caseType" WALFSYNCPERIOD="$load_fsync"  VGROUPS="$vgroups" ./loadtest.sh 


if [ ${caseType} != "userdefined" ];then
    #generate png report
    # loadResultAnaly.py has three parameter,
    # 1: loadResultFile 2:define the x-axis 3. reportResultImageFile
    echo "python3 ${scriptDir}/loadResultAnalyBarh.py  ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load.png"
    python3 ${scriptDir}/loadResultAnalyBarh.py  ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load.png

    echo "${scriptDir}/loadRatioBarh.py ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load_ratio.png"
    python3 ${scriptDir}/loadRatioBarh.py ${load_resultDir}/load_input.csv  SCALE ${load_resultDir}/test_load_ratio.png
fi
}

# caseType [cputest | cpu| devops | iot ]
if [ ${caseType} == "cputest" ];then
    echo "load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-01T12:00:00Z"  "200" "cpu-only" "${load_number_wokers}" "${load_batchsizes}" "TDengine influx timescaledb" "
    load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-01T12:00:00Z"  "200" "cpu-only" "${load_number_wokers}" "${load_batchsizes}" "TDengine influx timescaledb"
elif [ ${caseType} == "cpu" ];then
    load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z"  "100 4000 100000 1000000 10000000" "cpu-only" "${load_number_wokers}" "${load_batchsizes}" "TDengine influx timescaledb" 
elif [ ${caseType} == "devops" ];then
    load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z"  "100 4000 100000 1000000 10000000"  "devops" "${load_number_wokers}" "${load_batchsizes}" "TDengine influx timescaledb"
elif [ ${caseType} == "iot" ];then
    load_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z"  "100 4000 100000 1000000 10000000" "iot" "${load_number_wokers}" "${load_batchsizes}" "TDengine influx timescaledb"
elif [ ${caseType} == "userdefined" ];then
    load_testcase ${serverHost} ${serverPass}  "${load_ts_start}" "${load_ts_end}"   "${load_scales}" "${case}" "${load_number_wokers}" "${load_batchsizes}" "${load_formats}"
else  
    echo "please set correct testcase type"
fi

