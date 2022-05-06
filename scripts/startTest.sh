#!/bin/bash

# set -e
# set parameters by default value
osType=ubuntu   # -o [centos | ubuntu]
installGoEnv=false
installDB=false
installTsbs=false
serverHost=192.168.0.104
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
cmdInstall git

installPath="/usr/local/src/"
envfile="installEnv.sh"
cd ${installPath}
if [ -d "${installPath}/tsbs" ];then 
    cd ${installPath}/tsbs/
    git checkout -f master && git pull origin master
else
    git clone git@github.com:taosdata/tsbs.git 
fi


cd ${installPath}/tsbs/scripts 
./installEnv.sh -g ${installGoEnv} -d ${installDB}  -o ${osType}
source  /root/.bashrc
./installEnv.sh -t ${installTsbs} -o ${osType}

sudo systemctl stop postgresql-14
sudo systemctl stop influxd
sudo systemctl stop taosd


# configure sshd and 
sed -i 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config
service sshd restart
sshpass -p  ${serverPass} scp ${envfile} root@$serverHost:${installPath}
   
# install at server host 
sshpass -p ${serverPass}  ssh root@$serverHost << eeooff 
    cd ${installPath}
    ./installEnv.sh -d ${installDB}  -o ${osType} -s ${serverHost}
    source  /root/.bashrc
    sleep 1
    exit
eeooff


GO_HOME=/usr/local/go
export PATH=$GO_HOME/bin:$PATH
export GOPATH=$(go env GOPATH)
export PATH=$GOPATH/bin:$PATH

pip3 install matplotlib
# execute load tests
time=`date +%Y_%m%d_%H%M%S`
cd ${installPath}/tsbs/scripts
echo "./loadAllcases.sh -s ${serverHost} -p ${serverPass}  -c ${caseType} > testload${time}.log "
./loadAllcases.sh -s ${serverHost} -p ${serverPass}  -c ${caseType} > testload${time}.log 

# execute query tests
time=`date +%Y_%m%d_%H%M%S`
echo "./queryAllcases.sh -s ${serverHost} -p ${serverPass} -c ${caseType} > testquery${time}.log"
./queryAllcases.sh -s ${serverHost} -p ${serverPass} -c ${caseType} > testquery${time}.log
