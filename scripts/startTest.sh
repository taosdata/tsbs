#!/bin/bash

# set -e
# set parameters by default value
osType=ubuntu   # -o [centos | ubuntu]
installGoEnv=false
installDB=false
installTsbs=false
serverHost=test209
serverPass="taosdata!"

while getopts "hs:p:o:g:d:t:" arg
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
    h)
      echo "Usage: `basename $0` -o osType [centos | ubuntu]
                              -s server host or ip
                              -p server Password
                              -g installGoEnv [true | false]
                              -d installDB [true | false]           
                              -t installTsbs [true | false]
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
./installEnv.sh -g ${installGoEnv} -d ${installDB}  -o ubuntu
source  /root/.bashrc
./installEnv.sh -t ${installTsbs} -o ubuntu
sshppass -p  ${serverPass} scp ${envfile} root@$serverHost:${installPath}
   
sshpass -p ${serverPass}  ssh root@$serverHost << eeooff 
    ./installEnv.sh -g ${installGoEnv} -d ${installDB}  -o ubuntu
    source  /root/.bashrc
    ./installEnv.sh -t ${installTsbs} -o ubuntu
    sleep 1
    exit
eeooff


# execute load tests
time=`date +%Y_%m%d_%H%M%S`
cd ${installPath}/tsbs/scritps
./loadAllcases.sh > testload${time}.log 

# execute query tests
time=`date +%Y_%m%d_%H%M%S`
./queryAllcases.sh > testquery${time}.log
