#!/bin/bash

scriptDir=$(dirname $(readlink -f $0))
cfgfile="test.ini"
cd ${scriptDir}
source ${scriptDir}/logger.sh
source ${scriptDir}/common.sh
parse_ini ${cfgfile}

echo "install path: ${installPath}"
echo "installGoEnv: ${installGoEnv}"
echo "installDB: ${installDB}"
echo "installTsbs: ${installTsbs}"

function set_go_proxy {
  curl --max-time 10 --silent --head https://proxy.golang.org | grep "HTTP/2 200"
  if [ $? -ne 0 ]; then
      log_info "Using cn domestic proxy: https://goproxy.cn"
      go env -w GOPROXY=https://goproxy.cn,direct
      export GO111MODULE=on
  else
      export GO111MODULE=on
      log_info "Using international proxy: https://proxy.golang.org"
  fi
}


function check_go_version {
  go_version=$(go version 2>/dev/null)
  if [[ -z "$go_version" ]]; then
      log_info "Go is not installed. Proceeding with installation..."
  else
      log_info "Go is already installed. Version: $go_version"
      installed_version=$(echo "$go_version" | awk '{print $3}' | sed 's/go//')
      required_version="1.17"

      if [[ "$installed_version" < "$required_version" ]]; then
          log_error "Installed Go version ($installed_version) is less than the required version ($required_version)."
          log_error "Please uninstall the existing Go version and remove Go environment variables before proceeding."
          exit 1
      else
          log_info "Installed Go version ($installed_version) meets the requirement. No need to reinstall."
      fi
  fi 
}

# install go env
function install_go_env {
  log_info "============= Installing Go and setting Go environment ============="
  check_go_version

  version="1.17.13"
  go_tar="go${version}.linux-amd64.tar.gz"
  expected_md5="480e02c8c6b425105757282c80b5c9e1"

  log_debug "Installing Go version ${version}"

  cd ${installPath}
  if [ "${osType}" == "centos" ];then
    yum install -y  curl wget
  elif [ "${osType}" == "ubuntu" ];then
    apt install wget curl -y
  else
    log_error "OS type not supported"
  fi    

  if [ ! -f "${go_tar}"  ] ;then
      wget -q https://golang.google.cn/dl/${go_tar} || { echo "Failed to download ${go_tar}"; exit 1; }
  fi 

  # 计算文件的实际 MD5 值
  actual_md5=$(md5sum "${go_tar}" | awk '{print $1}')

  # 比较实际 MD5 值和预期 MD5 值
  if [[ "$actual_md5" != "$expected_md5" ]]; then
      log_error "MD5 check error! Actual MD5: $actual_md5, Expected MD5: $expected_md5"
      exit 1  
  else
      log_debug "MD5 check successful, MD5 values match."
  fi

  tar -xf "${go_tar}" || { echo "Failed to extract ${go_tar}"; exit 1; }

  echo "add go to PATH"
  GO_HOME=${installPath}/go
  goPar=`grep -w "GO_HOME=${installPath}/go"  /root/.bashrc`
  export PATH=$GO_HOME/bin:$PATH
  if [[ -z ${goPar} ]];then
      echo -e  "\n# GO_HOME\nexport GO_HOME=${installPath}/go\n" >> /root/.bashrc
      echo -e  'export PATH=$GO_HOME/bin:$PATH\n' >> /root/.bashrc
  else 
      log_debug "GO_HOME is already added to PATH in /root/.bashrc"      
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
      log_debug "GOPATH is already set"
  fi

  log_debug $PATH
  log_debug $(go env)
  log_info "Go environment setup complete"
}

# compile tsbs 
function install_tsbs {
  log_info "============= Installing TSBS ============="
  tail -10 /root/.bashrc
  source  /root/.bashrc
  goenv=${GOPATH}
  if [[ -z ${goenv} ]];then
      GO_HOME=${installPath}/go
      export PATH=$GO_HOME/bin:$PATH
      export GOPATH=$(go env GOPATH)
      export PATH=$GOPATH/bin:$PATH
  else
      log_debug "Go is already installed and GOPATH is set"
  fi

  gopathPar=$(grep -w "PATH=\$PATH:\$GOPATH/bin"  /root/.bashrc)
  log_debug "gopathPar is ${gopathPar}"

  if [[ -z ${gopathPar} ]];then
    echo -e  '\nexport PATH=$PATH:$GOPATH/bin\n' >> ~/.bashrc
  else
    log_debug "${GOPATH}/bin is already in PATH"
  fi

  export PATH=$GOPATH/bin:$PATH
  set_go_proxy

  log_debug ${GOPATH}
  log_debug "Installing TSBS dependencies"  
  go get github.com/timescale/tsbs
  go mod tidy
  cd ${GOPATH}/pkg/mod/github.com/timescale/tsbs*/ && make

  log_debug "Building TSBS binaries"
  [ -d "${GOPATH}/bin" ] || mkdir ${GOPATH}/bin/

  cd ${installPath}/tsbs/cmd/tsbs_generate_data/  &&  go build && cp tsbs_generate_data ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_generate_queries/  && go build && cp tsbs_generate_queries  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_load_tdengine/  && go build && cp tsbs_load_tdengine  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_load_tdenginestmt2/  && go build && cp tsbs_load_tdenginestmt2  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_run_queries_tdengine/ && go build  && cp tsbs_run_queries_tdengine  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_load_tdenginestmt2/  && go build && cp tsbs_load_tdenginestmt2  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_load_influx/  &&  go build && cp tsbs_load_influx ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_run_queries_influx/  &&  go build && cp tsbs_run_queries_influx ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_load_influx3/  &&  go build && cp tsbs_load_influx3 ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_run_queries_influx3/  &&  go build && cp tsbs_run_queries_influx3 ${GOPATH}/bin/

  log_info "TSBS installation complete"
}

cmdInstall sshpass
cmdInstall git

if [ "${installGoEnv}" == "true" ];then
  install_go_env
else 
  log_info "Go environment will not be installed. To install, set installGoEnv to true."
fi 


if [ "${installTsbs}" == "true" ];then
  if [[ -z `tsbs_load_tdengine --help` ]];then
      install_tsbs
  else
    log_info "TSBS is already installed. To update TSBS, please remove tsbs_load_tdengine from the system."
  fi
else
  log_info "TSBS will not be installed or updated. To install, set installTsbs to true."
fi 
