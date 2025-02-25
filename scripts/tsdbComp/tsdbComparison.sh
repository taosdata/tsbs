#!/bin/bash

# Set DEBUG and NO_COLOR environment variables
DEBUG=true
NO_COLOR=true

# define path and filename
scriptDir=$(dirname $(readlink -f $0))
installPath="/usr/local/src/"

cfgfile="test.ini"
logger_sh="${scriptDir}/logger.sh"
common_sh="${scriptDir}/common.sh"
install_env_file="installEnv.sh"

#set error log file
mkdir -p ${scriptDir}/log
error_install_file="${scriptDir}/log/install_error.log"


source ${scriptDir}/logger.sh
source ${scriptDir}/common.sh


log_info "Starting TSDB comparison script"

# check system
checkout_system


log_info "set client and server conf"

cd ${scriptDir}
source ./${cfgfile}
if [ ${clientIP} == ${serverIP} ]; then
    clientHost=$(hostname)
    clientIP=$(ip address | grep inet | grep -v inet6 | grep -v docker | grep -v 127.0.0.1 | awk '{print $2}' | awk -F "/" '{print $1}')

    sed -i "s/clientIP=.*/clientIP=\"${clientIP}\"/g" ${cfgfile}
    sed -i "s/clientHost=.*/clientHost=\"${clientHost}\"/g" ${cfgfile}
    sed -i "s/serverIP=.*/serverIP=\"${clientIP}\"/g" ${cfgfile}
    sed -i "s/serverHost=.*/serverHost=\"${clientHost}\"/g" ${cfgfile}
fi

# enable configure :test.ini
source ./${cfgfile}


log_info "==== All test parameters ===="

log_info "client: ${clientIP}"
log_info "server: ${serverIP}"
log_info "installEnvAll: ${installEnvAll}"
log_info "installGoEnv: ${installGoEnv}"
log_info "installDB: ${installDB}"
log_info "installTsbs: ${installTsbs}"
log_info "case: ${caseType}"
log_info "Load config"
log_info "  load_scales: ${load_scales}"
log_info "  load_formats: ${load_formats}"
log_info "  load_number_workers: ${load_number_workers}"
log_info "Query config"
log_info "  query_scales: ${query_scales}"
log_info "  restload: ${restload}"
log_info "  query_number_workers: ${query_number_workers}"
log_info "  query_formats: ${query_formats}"
log_info "  query_times: ${query_times}"
log_info "  query_types: ${query_types}"

log_info "==== Now we start to test ===="
log_info "Start to install env in ${installPath}"

mkdir -p ${installPath}
# copy configure to installPath
cp ${scriptDir}/${cfgfile} ${installPath}

if [ "${installEnvAll}" == "true" ]; then
    # install basic env, and you should have python3 and pip3 environment
    log_info "Install basic env"
    cmdInstall python3.8
    cmdInstall python3-pip
    pip3_define_install  matplotlib pandas

    # install client env 
    log_info "========== Install client: ${clientIP} basic environment and tsbs =========="

    if [ "${installDB}" == "true" ]; then
        ./installEnv.sh || exit 1
    fi 

    if [ "${installTsbs}" == "true" ] || [ "${installGoEnv}" == "true" ]; then
        ./installTsbsCommand.sh || exit 1
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

    log_info "========== Installation of client: ${clientIP} completed =========="

    if [ "${clientIP}" != "${serverIP}" ]; then
        log_info "========== Start to install server: ${serverIP} environment and databases =========="

        sshpass -p ${serverPass} ssh root@$serverHost << eeooff 
            mkdir -p ${installPath}
eeooff
        sshpass -p ${serverPass} scp ${install_env_file} root@$serverHost:${installPath}
        sshpass -p ${serverPass} scp ${cfgfile} root@$serverHost:${installPath}
        sshpass -p ${serverPass} scp ${logger_sh} root@$serverHost:${installPath}
        sshpass -p ${serverPass} scp ${common_sh} root@$serverHost:${installPath}

        # install at server host 
        if [ "${installDB}" == "true" ]; then
            sshpass -p ${serverPass} ssh root@$serverHost << eeooff 
                cd ${installPath}
                log_info "Install basic env in server ${serverIP}"
                ./installEnv.sh || exit 1
                source /root/.bashrc
                sleep 1
                exit
eeooff
        fi 
        log_info "========== Installation of server: ${serverIP} completed =========="
    else
        log_info "Client and server are the same machine and no need to install server environment"

    fi
fi

for caseType in ${caseTypes}; do
    # execute load tests
    log_info "========== caseType: ${caseType} =========="
    log_info "========== Start executing ${caseType} load test =========="

    time=$(date +%Y_%m%d_%H%M%S)

    cd ${scriptDir}
    log_info "caseType=${caseType} ./loadAllcases.sh &> log/testload${caseType}${time}.log"
    caseType=${caseType} ./loadAllcases.sh > log/testload${caseType}${time}.log 

    log_info "========== End executing ${caseType} load test =========="

    # execute query tests
    log_info "========== Start executing ${caseType} query test =========="

    cd ${scriptDir}
    log_info "caseType=${caseType} ./queryAllcases.sh &> log/testquery${caseType}${time}.log"
    caseType=${caseType} ./queryAllcases.sh > log/testquery${caseType}${time}.log

    log_info "========== End executing ${caseType} query test =========="
done