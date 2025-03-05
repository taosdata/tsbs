#!/bin/bash

# Set DEBUG and NO_COLOR environment variables
export DEBUG=true
export NO_COLOR=true

# define path and filename
scriptDir=$(dirname $(readlink -f $0))
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

# check system type and version. If the system is not supported, exit the script
checkout_system


log_info "set client and server conf"
cd ${scriptDir}
parse_ini ${cfgfile}
if [ ${clientIP} == ${serverIP} ]; then
    export clientHost="$(hostname)"
    export serverHost="$(hostname)"
fi

log_info "==== All test parameters ===="

log_info "General config"
log_info "  installPath: ${installPath}"
log_info "  clientIP: ${clientIP}, clientHost: ${clientHost}"
log_info "  serverIP: ${serverIP}, serverHost: ${serverHost}"
log_info "  installEnvAll: ${installEnvAll}"
log_info "  installGoEnv: ${installGoEnv}"
log_info "  installDB: ${installDB}"
log_info "  installTsbs: ${installTsbs}"
log_info "  caseTypes: ${caseTypes}"
log_info "  case: ${case}"
log_info "  operation_mode: ${operation_mode}"
log_info "  loadDataRootDir: ${loadDataRootDir}"
log_info "  loadResultRootDir: ${loadResultRootDir}"
log_info "  queryDataRootDir: ${queryDataRootDir}"
log_info "  queryResultRootDir: ${queryResultRootDir}"
log_info "Load config"
log_info "  load_number_workers: ${load_number_workers}"
log_info "  load_batch_sizes: ${load_batch_sizes}"
log_info "  load_formats: ${load_formats}"
log_info "  load_fsync: ${load_fsync}"
log_info "  vgroups: ${vgroups}"
log_info "  trigger: ${trigger}"
log_info "Load"
log_info "  load_scales: ${load_scales}"
log_info "  load_time_scales: ${load_time_scale_str}"
log_info "Load test"
log_info "  load_scales: ${LoadTest_load_scales}"
log_info "  load_time_scales: ${load_test_time_scale_str}"
log_info "Query config"
log_info "  query_number_workers: ${query_number_workers}"
log_info "  query_formats: ${query_formats}"
log_info "  reload_data: ${reload_data}"
log_info "  query_debug: ${query_debug}"
log_info "  query_load_batch_size: ${query_load_batch_size}"
log_info "  query_load_workers: ${query_load_workers}"
log_info "  query_types_cpu_all: ${query_types_cpu_all}"
log_info "  query_types_iot_all: ${query_types_iot_all}"
log_info "Query"
log_info "  query_ts_start: ${query_ts_start}"
log_info "  query_load_ts_end: ${query_load_ts_end}"
log_info "  query_ts_end: ${query_ts_end}"
log_info "  query_cpu_scale_times: ${query_cpu_scale_times}"
log_info "  query_iot_scale_times: ${query_iot_scale_times}"
log_info "Query test config"
log_info "  query_ts_start: ${QueryTest_query_ts_start}"
log_info "  query_load_ts_end: ${QueryTest_query_load_ts_end}"
log_info "  query_ts_end: ${QueryTest_query_ts_end}"
log_info "  query_cpu_scale_times: ${QueryTest_query_cpu_scale_times}"
log_info "  query_iot_scale_times: ${QueryTest_query_iot_scale_times}"
log_info "Report config"
log_info "  report: ${report}"

log_info "==== Now we start to test ===="
log_info "Start to install env in ${installPath}"

mkdir -p ${installPath}
if [ "${installEnvAll}" == "true" ]; then
    # install basic env, and you should have python3 and pip3 environment
    log_info "Install basic env"
    cmdInstall python3.8
    cmdInstall python3-pip
    pip3_define_install  matplotlib pandas numpy

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
else
    export GOPATH=$(go env GOPATH)
    export PATH=$(go env GOPATH)/bin:$PATH
fi

for caseType in ${caseTypes}; do
    log_info "========== caseType: ${caseType}, operation: ${operation_mode} =========="
    time=$(date +%Y_%m%d_%H%M%S)

    if [  ${operation_mode} == "both" ] || [  ${operation_mode} == "load" ]; then
        # execute load tests
        log_info "========== Start executing ${caseType} load test =========="

        cd ${scriptDir}
        log_info "caseType=${caseType} ./loadAllcases.sh > log/testload${caseType}${time}.log"
        caseType=${caseType} ./loadAllcases.sh > log/testload${caseType}${time}.log 2>&1

        log_info "========== End executing ${caseType} load test =========="
    fi

    if [  ${operation_mode} == "both" ] || [  ${operation_mode} == "query" ]; then
        # execute query tests
        log_info "========== Start executing ${caseType} query test =========="

        cd ${scriptDir}
        log_info "caseType=${caseType} ./queryAllcases.sh > log/testquery${caseType}${time}.log"
        caseType=${caseType} ./queryAllcases.sh > log/testquery${caseType}${time}.log 2>&1

        log_info "========== End executing ${caseType} query test =========="
    fi
    log_info "Please check result at directory: ${loadResultRootDir} for load operation or ${queryResultRootDir} for query operation"
done