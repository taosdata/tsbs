
# [centos | ubuntu]
osType=ubuntu      

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

#query test parameters
query_ts_start="2016-01-01T00:00:00Z"
query_load_ts_end="2016-01-05T00:00:00Z"
query_ts_end="2016-01-05T00:00:01Z"
query_load_number_wokers="12"
query_number_wokers="12"
query_times="10000"
query_scales="100 4000 100000 1000000 10000000"
query_formats="TDengine influx timescaledb"

scriptDir=$(dirname $(readlink -f $0))

# Check if command exists
function cmdInstall {
comd=$1
if command -v ${comd} ;then
    echo "${comd} is already installed" 
else 
    if command -v apt ;then
        apt-get install ${comd}
    elif command -v yum ;then
        yum install ${comd}
    else
        echo "you should install ${comd} manually"
    fi
fi
}

cmdInstall sshpass

# start to test
cd ${scriptDir}

# define path and filename
installPath="/usr/local/src/"
envfile="installEnv.sh"
cfgfile="test.ini"

# enable configure :test.ini
source ./${cfgfile}

echo "====now we start to test===="
echo "start to install env in ${installPath}"
mkdir -p ${installPath}
# copy configure to installPath
cp ${scriptDir}/${cfgfile} ${installPath}

# install  basic env, and you should have python3 and pip3 environment
echo "install basic env, and you should have python3 and pip3 environment"

pip3 install matplotlib


# install clinet env 
echo "==========install client:${cientIP} environment and tsbs ========"

./installEnv.sh 
./installTsbsCommand.sh
sudo systemctl stop postgresql-14
sudo systemctl stop influxd
sudo systemctl stop taosd

# configure sshd 
sed -i 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config
service sshd restart

echo "==========install server:${serverIP} environment========"

sshpass -p ${serverPass}  ssh root@$serverHost << eeooff 
    mkdir -p  ${installPath}
eeooff
sshpass -p  ${serverPass} scp ${envfile} root@$serverHost:${installPath}
sshpass -p  ${serverPass} scp ${cfgfile} root@$serverHost:${installPath}
# install at server host 
sshpass -p ${serverPass}  ssh root@$serverHost << eeooff 
    cd ${installPath}
    echo "install basic env in server ${serverIP}"
    ./installEnv.sh 
    source  /root/.bashrc
    sleep 1
    exit
eeooff

GO_HOME=${installPath}/go
export PATH=$GO_HOME/bin:$PATH
export GOPATH=$(go env GOPATH)
export PATH=$GOPATH/bin:$PATH

# execute load tests
echo "execute load tests"
time=`date +%Y_%m%d_%H%M%S`
cd ${scriptDir}
# echo "./loadAllcases.sh -s ${serverHost} -p ${serverPass}  -c ${caseType} > testload${time}.log "
# ./loadAllcases.sh -s ${serverHost} -p ${serverPass}  -c ${caseType} > testload${time}.log 
./loadAllcases.sh > testload${time}.log 

# # execute query tests
cd ${scriptDir}
# time=`date +%Y_%m%d_%H%M%S`
# # echo "./queryAllcases.sh -s ${serverHost} -p ${serverPass} -c ${caseType} > testquery${time}.log"
# # ./queryAllcases.sh -s ${serverHost} -p ${serverPass} -c ${caseType} > testquery${time}.log
./queryAllcases.sh  > testquery${time}.log

