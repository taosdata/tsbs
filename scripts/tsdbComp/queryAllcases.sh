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
load_formats="TDengine"
load_test_scales="200"

#query test parameters
query_ts_start="2016-01-01T00:00:00Z"
query_load_ts_end="2016-01-05T00:00:00Z"
query_ts_end="2016-01-05T00:00:01Z"
query_load_number_wokers="12"
query_number_wokers="12"
query_times="10000"
query_scales="100 4000 100000 1000000 10000000"
query_formats="TDengine"

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

function query_testcase {
#  testcaset
# need define data and result path
echo "testcase scenarios $5"
load_executeTime=`date +%Y_%m%d_%H%M%S`
load_dataDir="${loadDataRootDir}/load_data_${caseType}_host/" 
load_resultDir="${loadRsultRootDir}/log/" 

query_dataDir="${queryDataRootDir}/query_data_${caseType}/" 
query_resultDir="${queryRsultRootDir}log/" 

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

# if [ ${caseType} != "userdefined" ];then
#     # generate png 
#     echo "python3 ${scriptDir}/queryResultBarh.py  ${query_resultDir}/query_input.csv queryType  ${query_resultDir}/test_query_barh.png ${10} "
#     echo "python3 ${scriptDir}/queryRatioBarh.py  ${query_resultDir}/query_input.csv  queryType  ${query_resultDir}/test_query_barRatio.png  ${10}"

#     python3 ${scriptDir}/queryResultBarh.py  ${query_resultDir}/query_input.csv queryType  ${query_resultDir}/test_query_barh.png   ${10}
#     python3 ${scriptDir}/queryRatioBarh.py  ${query_resultDir}/query_input.csv  queryType  ${query_resultDir}/test_query_barRatio.png ${10}
# fi
}

# caseType [cputest | cpu| devops | iot ]
if [ ${caseType} == "cputest" ];then
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-01T12:00:00Z" "2016-01-01T12:00:01Z" "200" "cpu-only" "${query_number_wokers}"  "${query_formats}" "10" "
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-01T12:00:00Z" "2016-01-01T12:00:01Z" "200" "cpu-only" "${query_number_wokers}"  "${query_formats}" "10"
elif [ ${caseType} == "cpu" ];then
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "cpu-only" "${query_number_wokers}" "${query_formats}" "${query_times}" "
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "cpu-only" "${query_number_wokers}" "${query_formats}" "${query_times}"
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100" "cpu-only" "${query_number_wokers}" "${query_formats}" "${query_times}" "
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100" "cpu-only" "${query_number_wokers}" "${query_formats}" "${query_times}"

elif [ ${caseType} == "devops" ];then
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100"  "devops" "${query_number_wokers}" "${query_formats}" "${query_times}" "
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100"  "devops" "${query_number_wokers}" "${query_formats}" "${query_times}"
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "devops" "${query_number_wokers}" "${query_formats}" "${query_times}" "
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "devops" "${query_number_wokers}" "${query_formats}" "${query_times}"
elif [ ${caseType} == "iot" ];then
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100"  "iot" "4"  "${query_formats}"  "10000" "
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "100"  "iot" "4"  "${query_formats}"  "10000"
    echo "query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "iot" "4" "${query_formats}"  "500""
    query_testcase ${serverHost} ${serverPass}  "2016-01-01T00:00:00Z"  "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z"  "4000"  "iot" "4" "${query_formats}"  "500"
elif [ ${caseType} == "userdefined" ];then
    query_testcase ${serverHost} ${serverPass}  "${query_ts_start}" "${query_load_ts_end}"  "${query_ts_end}" "${query_scales}" "${case}" "${query_number_wokers}" "${query_formats}" "${query_times}"
else
    echo "please set correct testcase type"
fi