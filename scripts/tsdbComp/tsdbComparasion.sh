
# [centos | ubuntu]
osType=ubuntu      

# install env
installGoEnv=false
installDB=false
installTsbs=false

#server para
serverIP="192.168.0.104"
serverHost="trd04"
serverPass="taosdata!"

#testcase type
#[cputest | cpu| devops | iot ]
caseType=cputest

# data and result root path
# datapath is bulk_data_rootDir/bulk_data_${caseType} 
# executeTime=`date +%Y_%m%d_%H%M%S`
# resultpath is bulk_data_resultrootdir/load_data_${caseType}_${executeTime}
loadDataRootDir="/data2/"
loadRsultRootDir="/data2/"


#load test parameters
load_number_wokers="12"
load_batchsizes="10000"
load_scales="100 4000 100000 1000000 10000000"
load_formats="TDengine influx timescaledb"
load_test_scales="200"

#query test parameters
query_load_number_wokers="12"
query_number_wokers="12"
query_times="10000"
query_scales="100 4000 100000 1000000 10000000"
query_formats="TDengine influx timescaledb"

scriptDir=$(dirname $(readlink -f $0))

# start to test
cd ${scriptDir}

# define path and filename
installPath="/usr/local/src/"
envfile="installEnv.sh"
cfgfile="test.ini"
source ./${cfgfile}


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

# install  basic env, and you should have python3 and pip3 environment
cmdInstall sshpass
cmdInstall git
pip3 install matplotlib


# pull tsbs rep and install env  if set installenv ture
cd ${installPath}


if [ -d "${installPath}/tsbs" ];then 
    cd ${installPath}/tsbs/
    # git checkout -f master && git pull origin master
else
    git clone git@github.com:taosdata/tsbs.git 
fi


cd ${installPath}/tsbs/scripts/tsdbComp
./installEnv.sh 

# ./installEnv.sh -g ${installGoEnv} -d ${installDB} -t ${installTsbs}  -o ${osType}
# source  /root/.bashrc
# ./installEnv.sh -t ${installTsbs} -o ${osType}

sudo systemctl stop postgresql-14
sudo systemctl stop influxd
sudo systemctl stop taosd


# configure sshd 
sed -i 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config
service sshd restart
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


GO_HOME=/usr/local/go
export PATH=$GO_HOME/bin:$PATH
export GOPATH=$(go env GOPATH)
export PATH=$GOPATH/bin:$PATH

# execute load tests
time=`date +%Y_%m%d_%H%M%S`
cd ${installPath}/tsbs/scripts/tsdbComp
# echo "./loadAllcases.sh -s ${serverHost} -p ${serverPass}  -c ${caseType} > testload${time}.log "
# ./loadAllcases.sh -s ${serverHost} -p ${serverPass}  -c ${caseType} > testload${time}.log 
./loadAllcases.sh > testload${time}.log 

# # execute query tests
# time=`date +%Y_%m%d_%H%M%S`
# # echo "./queryAllcases.sh -s ${serverHost} -p ${serverPass} -c ${caseType} > testquery${time}.log"
# # ./queryAllcases.sh -s ${serverHost} -p ${serverPass} -c ${caseType} > testquery${time}.log
./queryAllcases.sh  > testquery${time}.log

