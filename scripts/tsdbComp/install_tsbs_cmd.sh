#!/bin/bash

scriptDir=$(dirname $(readlink -f $0))
cfgfile="test.ini"
# export DEBUG=true

cd ${scriptDir}
source ${scriptDir}/logger.sh
source ${scriptDir}/common.sh
parse_ini ${cfgfile}

log_info "Install path: ${installPath}"
log_info "Install Go environment: ${installGoEnv}"
log_info "Install databases: ${installDB}"
log_info "Install TSBS executable: ${installTsbs}"

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
      return 1
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
          return 0
      fi
  fi 
}

# install go env
function install_go_env {
  log_info "============= Installing Go and setting Go environment ============="
  check_go_version
  if [ $? -eq 0 ]; then
      log_info "Go environment is already set up. Skipping installation."
      return 0
  fi

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
      wget -q https://golang.google.cn/dl/${go_tar} || { log_error "Failed to download ${go_tar}"; exit 1; }
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

  tar -xf "${go_tar}" || { log_error "Failed to extract ${go_tar}"; exit 1; }

  log_debug "add go to PATH"
  GOROOT=${installPath}/go
  goPar=`grep -w "GOROOT=${installPath}/go"  /root/.bashrc`
  export PATH=$GOROOT/bin:$PATH
  if [[ -z ${goPar} ]];then
      echo -e  "\n# GOROOT\nexport GOROOT=${installPath}/go\n" >> /root/.bashrc
      echo -e  'export PATH=$GOROOT/bin:$PATH\n' >> /root/.bashrc
  else 
      log_debug "GOROOT is already added to PATH in /root/.bashrc"      
  fi 

  set_go_proxy


  log_debug "GOPATH: ${GOPATH}"
  if [[ -z "${GOPATH}" ]];then
      log_info "add go path to PATH and set GOPATH"
      export GOPATH=$(go env GOPATH)
      export PATH=$(go env GOPATH)/bin:$PATH
      gopathPar=$(grep -w "PATH=\$PATH:\$GOPATH/bin"  /root/.bashrc)
      if [[ -z ${gopathPar} ]];then
        echo -e  '\nexport GOPATH=$(go env GOPATH)\nexport PATH=$PATH:$GOPATH/bin\n' >> ~/.bashrc
      fi
  else
      log_debug "GOPATH is already set"
  fi

  log_debug "now GOPATH is $GOPATH and PATH is $PATH"
  log_info "Go environment setup complete"
}

# compile tsbs 
function install_tsbs {
  log_info "============= Installing TSBS ============="
  
  GOPATH=$(go env GOPATH)
  if [[ -z ${GOPATH} ]];then
      GOROOT=${installPath}/go
      export PATH=$GOROOT/bin:$PATH
      export GOPATH=$(go env GOPATH)
      export PATH=$GOPATH/bin:$PATH
  else
      export GOPATH=$(go env GOPATH)
      export PATH=$GOPATH/bin:$PATH
      log_debug "Go is already installed and GOPATH is set"
  fi

 # add go path to PATH in /root/.bashrc
  gopathPar=$(grep -w "PATH=\$PATH:\$GOPATH/bin"  /root/.bashrc)

  if [[ -z ${gopathPar} ]];then
    echo -e  '\nexport PATH=$PATH:$GOPATH/bin\n' >> ~/.bashrc
  else
    log_debug "${GOPATH}/bin is already in PATH"
  fi

  # set go proxy
  set_go_proxy

  log_debug "now GOPATH is $GOPATH and PATH is $PATH"
  log_debug "Installing TSBS dependencies"

  # go get github.com/timescale/tsbs
  # go mod tidy
  # cd ${GOPATH}/pkg/mod/github.com/timescale/tsbs*/ && make

  log_debug "Building TSBS binaries"
  [ -d "${GOPATH}/bin" ] || mkdir -p ${GOPATH}/bin/

  cd ${installPath}/tsbs/cmd/tsbs_generate_data/  &&  go build && cp tsbs_generate_data ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_generate_queries/  && go build && cp tsbs_generate_queries  ${GOPATH}/bin/
 
  declare -A db_set
  if [[ "$operation_mode" == "query" || "$operation_mode" == "both" ]]; then
      for db in $query_formats; do
          db_set[$db]=1
      done
  fi

  if [[ "$operation_mode" == "load" || "$operation_mode" == "both" ]]; then
      for db in $load_formats; do
          db_set[$db]=1
      done
  fi

  for db in "${!db_set[@]}"; do
      if [[ "$db" == "TDengine" ]]; then
          cd ${installPath}/tsbs/cmd/tsbs_load_tdengine/  && go build && cp tsbs_load_tdengine  ${GOPATH}/bin/
          cd ${installPath}/tsbs/cmd/tsbs_run_queries_tdengine/  && go build && cp tsbs_run_queries_tdengine  ${GOPATH}/bin/
      elif [[ "$db" == "TDengineStmt2" ]]; then
          cd ${installPath}/tsbs/cmd/tsbs_load_tdenginestmt2/  && go build && cp tsbs_load_tdenginestmt2  ${GOPATH}/bin/
          cd ${installPath}/tsbs/cmd/tsbs_run_queries_tdengine/  && go build && cp tsbs_run_queries_tdengine  ${GOPATH}/bin/
      elif [[ "$db" == "influx" ]]; then
          cd ${installPath}/tsbs/cmd/tsbs_load_influx/  &&  go build && cp tsbs_load_influx ${GOPATH}/bin/
          cd ${installPath}/tsbs/cmd/tsbs_run_queries_influx/  &&  go build && cp tsbs_run_queries_influx ${GOPATH}/bin/
      elif [[ "$db" == "influx3" ]]; then
          cd ${installPath}/tsbs/cmd/tsbs_load_influx3/  &&  go build && cp tsbs_load_influx3 ${GOPATH}/bin/
          cd ${installPath}/tsbs/cmd/tsbs_run_queries_influx3/  &&  go build && cp tsbs_run_queries_influx3 ${GOPATH}/bin/
      elif [[ "$db" == "timescaledb" ]]; then
          cd ${installPath}/tsbs/cmd/tsbs_load_timescaledb/  &&  go build && cp tsbs_load_timescaledb ${GOPATH}/bin/
          cd ${installPath}/tsbs/cmd/tsbs_run_queries_timescaledb/  &&  go build && cp tsbs_run_queries_timescaledb ${GOPATH}/bin/
      fi
  done

 
  # cd ${installPath}/tsbs/cmd/tsbs_run_queries_tdengine/ && go build  && cp tsbs_run_queries_tdengine  ${GOPATH}/bin/
  # cd ${installPath}/tsbs/cmd/tsbs_load_tdenginestmt2/  && go build && cp tsbs_load_tdenginestmt2  ${GOPATH}/bin/
  # cd ${installPath}/tsbs/cmd/tsbs_load_influx/  &&  go build && cp tsbs_load_influx ${GOPATH}/bin/
  # cd ${installPath}/tsbs/cmd/tsbs_run_queries_influx/  &&  go build && cp tsbs_run_queries_influx ${GOPATH}/bin/
  # cd ${installPath}/tsbs/cmd/tsbs_load_influx3/  &&  go build && cp tsbs_load_influx3 ${GOPATH}/bin/
  # cd ${installPath}/tsbs/cmd/tsbs_run_queries_influx3/  &&  go build && cp tsbs_run_queries_influx3 ${GOPATH}/bin/

  log_info "TSBS installation complete and TSBS binaries are located in ${GOPATH}/bin/"
  log_debug "$(ls ${GOPATH}/bin/)"
  # log_debug "$(tsbs_run_queries_timescaledb)"

}

if [ "${installGoEnv}" == "true" ];then
  install_go_env
else 
  log_info "Go environment will not be installed. To install, set installGoEnv to true."
  export GOPATH=$(go env GOPATH)
  export PATH=$(go env GOPATH)/bin:$PATH
fi 

if [ "${installTsbs}" == "true" ];then
  install_tsbs
else
  log_info "TSBS will not be installed or updated. To install, set installTsbs to true."
fi 
