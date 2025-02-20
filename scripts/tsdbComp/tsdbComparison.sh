

scriptDir=$(dirname $(readlink -f $0))

# Check if command exists
function cmdInstall {
comd=$1
if command -v ${comd} ;then
    echo "${comd} is already installed" 
else 
    if command -v apt ;then
        apt-get install ${comd} -y 
    elif command -v yum ;then
        yum install ${comd} -y 
    else
        echo "you should install ${comd} manually"
    fi
fi
}


# start to test
cd ${scriptDir}
mkdir -p log/
# define path and filename
installPath="/usr/local/src/"
envfile="installEnv.sh"
cfgfile="test.ini"
source ./${cfgfile}

if [ ${clientIP} == ${serverIP} ];then
    clientHost=`hostname`
    clientIP=`ip address | grep inet | grep -v inet6 |grep -v docker| grep -v 127.0.0.1 | awk '{print $2}' | awk -F "/" '{print $1}'`

    sed -i "s/clientIP=.*/clientIP=\"${clientIP}\"/g" ${cfgfile}
    sed -i "s/clientHost=.*/clientHost=\"${clientHost}\"/g" ${cfgfile}
    sed -i "s/serverIP=.*/serverIP=\"${clientIP}\"/g" ${cfgfile}
    sed -i "s/serverHost=.*/serverHost=\"${clientHost}\"/g" ${cfgfile}
fi

# enable configure :test.ini
source ./${cfgfile}


# print 
echo "====all test parameters===="

echo -e  "client:${clientIP} \r\nserver:${serverIP} \r\ninstallEnvAll: ${installEnvAll}  \r\n   installGoEnv: ${installGoEnv} installDB: ${installDB} installTsbs: ${installTsbs} \r\ncase: ${caseType}\r\nLoad config \r\n  load_scales: ${load_scales}\r\n  load_formats: ${load_formats}\r\n  load_number_wokers: ${load_number_wokers}\r\nQuery config \r\n  query_scales: ${query_scales}\r\n  restload: ${restload} \r\n  query_number_wokers: ${query_number_wokers}\r\n  query_formats: ${query_formats} \r\n  query_times: ${query_times}\r\n  query_types: ${query_types}"

echo "====now we start to test===="
echo "start to install env in ${installPath}"
mkdir -p ${installPath}
# copy configure to installPath
cp ${scriptDir}/${cfgfile} ${installPath}


if [ "${installEnvAll}" == "true" ];then
    # install  basic env, and you should have python3 and pip3 environment
    echo "install basic env"
    cmdInstall python3.8
    cmdInstall python3-pip
    pip3 install matplotlib pandas

    # install clinet env 
    echo -e "========== install client:${clientIP} basic environment and tsbs ========\n\n"

    if [ "${installDB}" == "true" ] ;then
        ./installEnv.sh 
    fi 

    if [ "${installTsbs}" == "true" ] || [ "${installGoEnv}" == "true" ];then
        ./installTsbsCommand.sh
        GO_HOME=${installPath}/go
        export PATH=$GO_HOME/bin:$PATH
        export GOPATH=$(go env GOPATH)
        export PATH=$GOPATH/bin:$PATH
    fi
    sudo systemctl stop postgresql-14
    sudo systemctl stop influxd
    sudo systemctl stop taosd


    # configure sshd 
    sed -i 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config
    service sshd restart

    echo -e "========== intallation of client:${clientIP}  completed ========\n\n"

    if [ "${clientIP}" != "${serverIP}" ];then
        echo  -e "========== start to install server:${serverIP} environment and databases ========\n\n"

        sshpass -p ${serverPass} ssh root@$serverHost << eeooff 
            mkdir -p  ${installPath}
eeooff
        sshpass -p ${serverPass}  scp ${envfile} root@$serverHost:${installPath}
        sshpass -p ${serverPass}  scp ${cfgfile} root@$serverHost:${installPath}
        # install at server host 
        if [ "${installDB}" == "true" ];then

        sshpass -p ${serverPass}  ssh root@$serverHost << eeooff 
            cd ${installPath}
            echo "install basic env in server ${serverIP}"
            ./installEnv.sh 
            source  /root/.bashrc
            sleep 1
            exit
eeooff

        fi 
    else
        echo "client and server are the same machine"
    fi

    echo -e "========== intallation of server:${serverIP}  completed ========\n\n"
fi

for caseType in ${caseTypes}; do
    # execute load tests
    echo -e "========== caseType: ${caseType} =======\n\n"
    current_date=$(date +%Y_%m%d_%H%M%S)
    echo -e "========== ${current_date}: start executing ${caseType} load test ========\n\n"
                      
    time=`date +%Y_%m%d_%H%M%S`

    cd ${scriptDir}
    mkdir -p log
    # echo "./loadAllcases.sh -s ${serverHost} -p ${serverPass}  -c ${caseType} > testload${time}.log "
    # ./loadAllcases.sh -s ${serverHost} -p ${serverPass}  -c ${caseType} > testload${time}.log 
    echo "./loadAllcases.sh &> log/testload${caseType}${time}.log "
    caseType=${caseType} ./loadAllcases.sh > log/testload${caseType}${time}.log 

    current_date=$(date +%Y_%m%d_%H%M%S)
    echo -e "\n\n"
    echo -e "========== ${current_date}: end executing ${caseType} load test ===========\n\n"

    # # execute query tests
    current_date=$(date +%Y_%m%d_%H%M%S)
    echo -e "========== ${current_date}: start executing ${caseType} query test ========\n\n"

    cd ${scriptDir}
    time=`date +%Y_%m%d_%H%M%S`
    # time=`date +%Y_%m%d_%H%M%S`
    # # echo "./queryAllcases.sh -s ${serverHost} -p ${serverPass} -c ${caseType} > testquery${time}.log"
    # # ./queryAllcases.sh -s ${serverHost} -p ${serverPass} -c ${caseType} > testquery${time}.log
    echo "./queryAllcases.sh  &> log/testquery${caseType}${time}.log"
    caseType=${caseType}  ./queryAllcases.sh  > log/testquery${caseType}${time}.log

    current_date=$(date +%Y_%m%d_%H%M%S)
    echo -e "\n\n"
    echo -e "========== ${current_date}: end executing ${caseType} query test ===========\n\n"
done