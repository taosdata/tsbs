#!/bin/bash

# set -e
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

#query test parameters
query_ts_start="2016-01-01T00:00:00Z"
query_load_ts_end="2016-01-05T00:00:00Z"
query_ts_end="2016-01-05T00:00:01Z"
query_load_number_wokers="12"
query_number_wokers="12"
query_times="10000"
query_scales="100 4000 100000 1000000 10000000"
query_formats="TDengine influx timescaledb"


# start to install 
scriptDir=$(dirname $(readlink -f $0))
cd ${scriptDir}
source ./test.ini

echo "install path: ${installPath}"
echo "installGoEnv: ${installGoEnv}"
echo "installDB: ${installDB}"
echo "installTsbs: ${installTsbs}"

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



# install go env
function install_go_env {
echo "============= install go and set go env ============="
goenv=`go env`
if [[ -z ${goenv} ]];then
    echo "install go "
    cd ${installPath}
    if [ "${osType}" == "centos" ];then
      yum install -y  curl wget
    elif [ "${osType}" == "ubuntu" ];then
      apt install wget curl -y
    else
      echo "osType can't be supported"
    fi    
    if [ ! -f "go1.16.9.linux-amd64.tar.gz"  ] ;then
        wget https://studygolang.com/dl/golang/go1.16.9.linux-amd64.tar.gz
    fi 
    tar -zxvf  go1.16.9.linux-amd64.tar.gz
    echo "add go to PATH"
    GO_HOME=${installPath}/go
    goPar=`grep -w "GO_HOME=${installPath}/go"  /root/.bashrc`
    export PATH=$GO_HOME/bin:$PATH
    if [[ -z ${goPar} ]];then
        echo -e  "\n# GO_HOME\nexport GO_HOME=${installPath}/go\n" >> /root/.bashrc
        echo -e  'export PATH=$GO_HOME/bin:$PATH\n' >> /root/.bashrc
    else 
        echo "GOHOME already been add to PATH of /root/.bashrc"    
    fi 
    source  /root/.bashrc
else
    echo "go has been installed"
fi

go env -w GOPROXY=https://goproxy.cn,direct
export GO111MODULE=on

echo ${GOPATH}
if [[ -z "${GOPATH}" ]];then
    echo "add go path to PATH and set GOPATH"
    export GOPATH=$(go env GOPATH)
    export PATH=$(go env GOPATH)/bin:$PATH
    gopathPar=`grep -w "PATH=\$PATH:\$GOPATH/bin"  /root/.bashrc`
    if [[ -z ${goPar} ]];then
      echo -e  '\nexport GOPATH=$(go env GOPATH)\nexport PATH=$GOPATH/bin:$PATH\n' >> ~/.bashrc
    fi
    source  /root/.bashrc
else
    echo "GOPATH has been added"
fi
echo $PATH
echo $(go env)

}

# compile tsbs 
function install_tsbs {
  echo "install tsbs"
  tail -10 /root/.bashrc
  source  /root/.bashrc
  goenv=${GOPATH}
  if [[ -z ${goenv} ]];then
      GO_HOME=${installPath}/go
      export PATH=$GO_HOME/bin:$PATH
      export GOPATH=$(go env GOPATH)
      export PATH=$GOPATH/bin:$PATH
  else
      export PATH=$GOPATH/bin:$PATH
      echo "go has been installed"
  fi
  go env -w GOPROXY=https://goproxy.cn,direct
  export GO111MODULE=on
  echo ${GOPATH}
  
  go get github.com/timescale/tsbs
  go mod tidy
  cd ${GOPATH}/pkg/mod/github.com/timescale/tsbs*/ && make

  # # clone taosdata repo and  compile
  # cd ${installPath} 
  # if [ -d "${installPath}/tsbs" ];then 
  #   cd ${installPath}/tsbs/
  #   git checkout -f master && git pull origin master
  # else
  #   git clone https://github.com/taosdata/tsbs.git 
  # fi

  [ -d "${GOPATH}/bin" ] || mkdir ${GOPATH}/bin/

  cd ${installPath}/tsbs/cmd/tsbs_generate_data/  &&  go build && cp tsbs_generate_data ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_generate_queries/  && go build && cp tsbs_generate_queries  ${GOPATH}/bin/
  # cd ${installPath}/tsbs/cmd/tsbs_load/  &&  go build && cp tsbs_load  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_load_tdengine/  && go build && cp tsbs_load_tdengine  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_run_queries_tdengine/ && go build  && cp tsbs_run_queries_tdengine  ${GOPATH}/bin/

}

cmdInstall sshpass
cmdInstall git


if [ "${installGoEnv}" == "true" ];then
  install_go_env
else 
  echo "It doesn't  install go and set go env.If you want to install,please set installGo-env true"
fi 


if [ "${installTsbs}" == "true" ];then
  if [[ -z `tsbs_load_tdengine --help` ]];then
      install_tsbs
  else
    echo "command of tsbs_load_tdengine has been found in system,so tsbs has been installed.If you want to update tdengine of tsbs ,please remove tsbs_load_tdengine from system"
  fi
else
  echo "It wouldn't install and update tsbs.If you want to install,please set installTsbs true"
fi 
