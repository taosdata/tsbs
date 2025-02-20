#!/bin/bash

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

function set_go_proxy {
  result=$(curl --max-time 10 -s --head https://proxy.golang.org | grep -q "200 OK")
  if [ -z "${result}" ]; then
      echo "Using cn domestic proxy: https://goproxy.cn"
      go env -w GOPROXY=https://goproxy.cn,direct
      export GO111MODULE=on
  else
      echo "Using international proxy: https://proxy.golang.org"
  fi
}


function check_go_version {
go_version=$(go version 2>/dev/null)
if [[ -z "$go_version" ]]; then
    echo "Go is not installed. Proceeding with installation..."
else
    echo "Go is already installed. Version: $go_version"
    # 提取版本号并比较
    installed_version=$(echo "$go_version" | awk '{print $3}' | sed 's/go//')
    required_version="1.17"

    # 比较版本号
    if [[ "$installed_version" < "$required_version" ]]; then
        echo "Installed Go version ($installed_version) is less than the required version ($required_version)."
        echo "Please uninstall the existing Go version and remove Go environment variables before proceeding."
        exit 1
    else
        echo "Installed Go version ($installed_version) meets the requirement. No need to reinstall."
    fi
fi 
}

# install go env
function install_go_env {
echo "============= install go and set go env ============="
check_go_version

echo "install go-1.18.6"
cd ${installPath}
if [ "${osType}" == "centos" ];then
  yum install -y  curl wget
elif [ "${osType}" == "ubuntu" ];then
  apt install wget curl -y
else
  echo "osType can't be supported"
fi    
if [ ! -f "go1.18.6.linux-amd64.tar.gz"  ] ;then
    wget https://golang.google.cn/dl/go1.18.6.linux-amd64.tar.gz
fi 
tar -xf  go1.18.6.linux-amd64.tar.gz

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


set_go_proxy


echo ${GOPATH}
if [[ -z "${GOPATH}" ]];then
    echo "add go path to PATH and set GOPATH"
    export GOPATH=$(go env GOPATH)
    export PATH=$(go env GOPATH)/bin:$PATH
    gopathPar=$(grep -w "PATH=\$PATH:\$GOPATH/bin"  /root/.bashrc)
    if [[ -z ${gopathPar} ]];then
      echo -e  '\nexport GOPATH=$(go env GOPATH)\nexport PATH=$PATH:$GOPATH/bin\n' >> ~/.bashrc
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
      echo "go has been installed and GOPATH has been set"
  fi

  gopathPar=$(grep -w "PATH=\$PATH:\$GOPATH/bin"  /root/.bashrc)
  echo "gopathPar is ${gopathPar}"

  if [[ -z ${gopathPar} ]];then
    echo -e  '\nexport PATH=$PATH:$GOPATH/bin\n' >> ~/.bashrc
  else
      echo "${GOPATH}/bin is already in PATH"
  fi

  export PATH=$GOPATH/bin:$PATH
  set_go_proxy

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
