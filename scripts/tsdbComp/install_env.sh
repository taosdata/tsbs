#!/bin/bash

scriptDir=$(dirname $(readlink -f $0))
cfgfile="test.ini"
cd ${scriptDir}
source ${scriptDir}/logger.sh
source ${scriptDir}/common.sh
parse_ini ${cfgfile}

log_info "Install path: ${installPath}"
log_info "Install Go environment: ${installGoEnv}"
log_info "Install databases: ${installDB}"
log_info "Install TSBS executable: ${installTsbs}"
log_info "Server IP: ${serverIP}"
log_info "Client IP: ${clientIP}"


function install_timescale_centos {
# install timescaledb in centos 
  log_info "============= Installing TimescaleDB on CentOS ============="
  log_debug "Configuring pre-installation for TimescaleDB on CentOS"
  yum install https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{centos})-x86_64/pgdg-redhat-repo-latest.noarch.rpm
if [ ! -f "/etc/yum.repos.d/timescale_timescaledb.repo"  ] ;then
  tee /etc/yum.repos.d/timescale_timescaledb.repo <<EOL
  [timescale_timescaledb]
  name=timescale_timescaledb
  baseurl=https://packagecloud.io/timescale/timescaledb/el/$(rpm -E %{rhel})/\$basearch
  repo_gpgcheck=1
  gpgcheck=0
  enabled=1
  gpgkey=https://packagecloud.io/timescale/timescaledb/gpgkey
  sslverify=1
  sslcacert=/etc/pki/tls/certs/ca-bundle.crt
  metadata_expire=300
EOL
  yum update -y 
fi

  log_debug "Removing and installing TimescaleDB on CentOS"
  yum remove postgresql-14 -y
  yum remove timescaledb-2-postgresql-14 -y
  #   yum remove postgresql-14 -y
  yum install timescaledb-2-postgresql-14='2.13.0*'  timescaledb-2-loader-postgresql-14='2.13.0*' -y

  log_debug "Starting TimescaleDB on CentOS"
  # configure postgresql 
  sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
  sudo systemctl enable postgresql-14
  sudo systemctl start postgresql-14

  log_debug "Configuring and starting PostgreSQL for TimescaleDB on CentOS"
  sharePar1=`grep -w "shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  sharePar2=`grep -w "#shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  if [[ -z "${sharePar1}" ]] || [[  -n  "${sharePar2}" ]];then
    echo "shared_preload_libraries = 'timescaledb'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    log_debug "shared_preload_libraries is already configured in postgresql.conf"
  fi

  listenPar1=`grep -w "listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf `
  listenPar2=`grep -w "#listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf `
  if [[ -z "${listenPar1}" ]] || [[  -n "${listenPar2}" ]];then
    echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    log_debug "listen_addresses is already configured in postgresql.conf"  
  fi 
  systemctl restart  postgresql 

  log_debug "Resetting password to 'password' and adding TimescaleDB extension for PostgreSQL on CentOS"
  # reset default password:password 
  su - postgres -c "psql -U postgres -c \"alter role  postgres with password 'password';\""
  systemctl restart  postgresql 
  PGPASSWORD=password psql -U postgres -h localhost -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
}

function install_influx_centos {
  log_info "============= Reinstalling InfluxDB on CentOS ============="
  rpm -e influxdb
  cd ${installPath}
  yum install wget
  if [ ! -f "influxdb-1.8.10.x86_64.rpm"  ] ;then
    wget --quiet https://dl.influxdata.com/influxdb/releases/influxdb-1.8.10.x86_64.rpm  ||  { echo "Download InfluxDB 1.8 package failed"; exit 1; }
  fi
  sudo yum  -y localinstall influxdb-1.8.10.x86_64.rpm
  indexPar1=`grep -w 'index-version = "tsi1"' /etc/influxdb/influxdb.conf `
  indexPar2=`grep -w '#index-version = "tsi1"'  /etc/influxdb/influxdb.conf `
  if [[ -z "${indexPar1}" ]] || [[  -n "${indexPar2}" ]];then
    sed -i '/^\[data\]/a\ index-version = "tsi1"'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ max-values-per-tag = 0'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ cache-max-memory-size = "80g"'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ compact-full-write-cold-duration = "30s"'  /etc/influxdb/influxdb.conf 
  else 
    log_debug "index-version is already configured in influxdb.conf" 
  fi 
  systemctl restart influxd
}

# add trust link entry for your host in pg_hba.conf manually
# eg : host    all     all             192.168.0.1/24               md5
function add_trust_link_entry() {
    local ip=$1
    local description=$2

    log_debug "Adding trust link entry for your ${description} IP in pg_hba.conf automatically"
    trustPar=`grep -w "${ip}" /etc/postgresql/14/main/pg_hba.conf`
    if [ -z "${trustPar}" ]; then
        echo -e "\r\nhost    all     all             ${ip}/24               md5\n" >> /etc/postgresql/14/main/pg_hba.conf
    else
        log_debug "Trust link entry for your ${description} IP is already added in pg_hba.conf"
    fi
}

function install_timescale_ubuntu {
  log_info "=============Reinstalling TimescaleDB on Ubuntu ============="
  log_debug "Configuring pre-installation for TimescaleDB on Ubuntu"
  apt install -y  gnupg postgresql-common apt-transport-https lsb-release wget 
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y 
  curl -L https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
  sh -c "echo 'deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main' > /etc/apt/sources.list.d/timescaledb.list"
  wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add -
  apt update -y 
  
  log_debug "Removing and installing TimescaleDB on Ubuntu"
  apt remove postgresql-14 -y
  apt remove timescaledb-2-postgresql-14 -y
  apt install postgresql-14 -y
  apt install timescaledb-2-postgresql-14='2.13.0*'  --allow-downgrades timescaledb-2-loader-postgresql-14='2.13.0*'  -y 

  log_debug "Configuring and starting PostgreSQL for TimescaleDB on Ubuntu"
  sharePar1=`grep -w "shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  sharePar2=`grep -w "#shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  if [[ -z "${sharePar1}" ]] || [[  -n  "${sharePar2}" ]];then
    echo "shared_preload_libraries = 'timescaledb'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    log_debug "shared_preload_libraries is already configured in postgresql.conf"
  fi

  listenPar1=`grep -w "listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf `
  listenPar2=`grep -w "#listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf `
  if [[ -z "${listenPar1}" ]] || [[  -n "${listenPar2}" ]];then
    echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    log_debug "listen_addresses is already configured in postgresql.conf" 
  fi 
  systemctl restart  postgresql 

  log_debug "Resetting password to 'password' and adding TimescaleDB extension for PostgreSQL on Ubuntu"
  # reset default password:password 
  su - postgres -c "psql -U postgres -c \"alter role  postgres with password 'password';\""
  systemctl restart  postgresql 
  PGPASSWORD=password psql -U postgres -h localhost -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"

  if [ "${clientIP}" != "${serverIP}" ]; then
    add_trust_link_entry "${serverIP}" "server"
    add_trust_link_entry "${clientIP}" "client"
  fi
}

function install_influx_ubuntu {
  log_info "=============Reinstalling InfluxDB on ubuntu ============="
  dpkg -r influxdb
  cd ${installPath}
  if [ ! -f "influxdb_1.8.10_amd64.deb" ] ;then
     wget --quiet https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_amd64.deb  ||  { echo "Download InfluxDB 1.8 package failed"; exit 1; }
  fi
  sudo dpkg -i influxdb_1.8.10_amd64.deb
  indexPar1=`grep -w 'index-version = "tsi1"' /etc/influxdb/influxdb.conf `
  indexPar2=`grep -w '#index-version = "tsi1"'  /etc/influxdb/influxdb.conf `
  if [[ -z "${indexPar1}" ]] || [[  -n "${indexPar2}" ]];then
    sed -i '/^\[data\]/a\ index-version = "tsi1"'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ max-values-per-tag = 0'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ cache-max-memory-size = "80g"'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ compact-full-write-cold-duration = "30s"'  /etc/influxdb/influxdb.conf 
  else 
    log_debug "index-version is already configured in influxdb.conf" 
  fi 
  systemctl restart influxd
}


function install_TDengine {
  log_info "============= Reinstalling TDengine on Ubuntu ============="
  cd ${installPath}
  sudo apt-get install -y gcc cmake build-essential git libssl-dev
  if [ ! -d "TDengine" ];then
    git clone https://github.com/taosdata/TDengine.git || exit 1
  fi
  # if [ caseType == "cpu" ];then
  #   cd TDengine && git checkout c90e2aa791ceb62542f6ecffe7bd715165f181e8
  # else 
  #   cd TDengine && git checkout 1bea5a53c27e18d19688f4d38596413272484900
  # fi
  
    cd TDengine && git checkout main

    if [ -d "debug/" ]; then
        rm -rf debug
    fi
    sed -i "s/\-Werror / /g" cmake/cmake.define
    mkdir -p debug && cd debug

    # Trap any exit signal and log it
    trap 'echo "TDengine build failed"; exit 1' EXIT

    cmake .. -Ddisable_assert=True -DSIMD_SUPPORT=true   -DCMAKE_BUILD_TYPE=Release -DBUILD_TOOLS=false

    # Detect memory size
    memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    memory_kb=$memory
    memory_mb=$((memory_kb / 1024))
    memory_gb=$(echo "scale=0; ($memory_mb / 1024) + ($memory_mb % 1024 > 0)" | bc)
    core_number=$(nproc)
    if [ "${memory_gb}" -ge 12 ]; then
        log_debug "Using make -j${core_number}"
        make -j$(nproc) || exit 1
    else
        log_debug "Using make"
        make || exit 1
    fi

    make install || exit 1

    # Remove the trap if everything succeeded
    trap - EXIT

    # Check if taosd and taos commands are available
    if ! command -v taosd &> /dev/null || ! command -v taos &> /dev/null; then
        log_error "Install TDengine failed"
        exit 1
    fi

    systemctl status taosd

    # Resolved the issue of failure after three restarts within the default time range (600s)
    sed -i '/StartLimitInterval/s/.*/StartLimitInterval=60s/' /etc/systemd/system/taosd.service
    systemctl daemon-reload
    taosPar=$(grep -w "numOfVnodeFetchThreads 4" /etc/taos/taos.cfg)
    if [ -z "${taosPar}" ]; then
        echo -e "numOfVnodeFetchThreads 4\nqueryRspPolicy 1\ncompressMsgSize 28000\nSIMD-builtins 1\n" >> /etc/taos/taos.cfg
    fi
    fqdnCPar=$(grep -w "${clientIP} ${clientHost}" /etc/hosts)
    if [ -z "${fqdnCPar}" ];then
        echo -e "\n${clientIP} ${clientHost} \n" >> /etc/hosts
    fi
    if [ "${clientIP}" != "${serverIP}" ]; then
        fqdnSPar=$(grep -w "${serverIP} ${serverHost}" /etc/hosts)
        if [ -z "${fqdnSPar}" ]; then
            echo -e "\n${serverIP} ${serverHost} \n" >> /etc/hosts
        fi
    fi
}

function install_influxdb3 {
  log_info "=============Installing InfluxDB3 on ubuntu ============="
  check_glibc_version
  if [ $? -eq 0 ]; then
    echo "glibc version is supported."
  else
    echo  "glibc version is not supported."
    exit 1
  fi
  
  cd ${installPath}
  # if influxdb3 is already installed, no need to reinsall
  help_output=$(timeout 5 ~/.influxdb/influxdb3 --help 2>&1)
  help_exit_code=$?
  if [[ $help_exit_code -ne 0 ]]; then
    log_warning "InfluxDB3 help command failed: ${help_output}"
    curl -O https://www.influxdata.com/d/install_influxdb3.sh && sh install_influxdb3.sh <<EOF
2
n
EOF
  fi

  export PATH="$PATH:~/.influxdb/"
  # run influxdb3 --version to check if it is installed successfully
  version_output=$(timeout 5 ~/.influxdb/influxdb3 --version 2>&1)
  version_exit_code=$?
  if [[ $version_exit_code -ne 0 ]]; then
    log_error "Install InfluxDB3 failed: ${version_output}"
    exit 1
  fi

  # if influxdb3 is started, restart it
  if ps -ef | grep influxdb3 | grep -v grep > /dev/null; then
    log_debug "Influxdb3 is already started, restarting it"
    pkill -9 influxdb3 || true
  fi
  influx3_path=${influx3_data_dir:-"/var/lib/influxdb3"}
  influx3_port=${influx3_port:-"8086"}
  influx3_log=${influx3_path}/influxdb3.log
  influx3_path=${influx3_path}/tsbs_test_data
  mkdir -p ${influx3_path}
  rm -rf ${influx3_path}/*
  nohup ~/.influxdb/influxdb3 serve --node-id=local01 --object-store=file --data-dir ${influx3_path} --http-bind=0.0.0.0:${influx3_port} >> ${influx3_log} 2>&1 &

  if check_influxdb3_status ${influx3_port}; then
    log_info "InfluxDB3 started successfully on port ${influx3_port}."
  else
    log_error "InfluxDB3 failed to start on port ${influx3_port}."
    exit 1
  fi

}

function install_database {
    local db=$1
    case $db in
        TDengine | TDengineStmt2)
            log_info "Installing TDengine..."
            install_TDengine
            ;;
        influx)
            log_info "Installing InfluxDB..."
            if [ "${osType}" == "centos" ];then
              yum install -y  curl wget
              install_influx_centos
            elif [ "${osType}" == "ubuntu" ];then
              install_influx_ubuntu 
            else
              log_error "OS type not supported"
            fi
            ;;
        timescaledb)
            log_info "Installing TimescaleDB..."
              if [ "${osType}" == "centos" ];then
                yum install -y  curl wget
                install_timescale_centos
              elif [ "${osType}" == "ubuntu" ];then
                install_timescale_ubuntu 
              else
                log_error "OS type not supported"
              fi
            ;;
        influx3)
            log_info "Installing InfluxDB3..."
            install_influxdb3
            ;;
        *)
            log_warning "Unknown database format: $db"
            ;;
    esac
}

# install sshpass,git and dool
cmdInstall sshpass
cmdInstall git
cmdInstall gcc 
cmdInstall cmake 
cmdInstall build-essential
cmdInstall libssl-dev
cmdInstall net-tools

cd ${installPath}
if [ ! -f "v1.1.0.tar.gz" ] ;then
  wget --quiet https://github.com/scottchiefbaker/dool/archive/refs/tags/v1.1.0.tar.gz  ||  { echo "Download dool 1.1 package failed"; exit 1; }
fi

tar xf v1.1.0.tar.gz && cd dool-1.1.0/ && execute_python_file ${scriptDir} ./install.py

# install db  
if [ "${installDB}" == "true" ]; then
  log_info "Installing databases. Operation mode: ${operation_mode}"
  log_debug "Operation mode: ${operation_mode}, query formats: ${query_formats}, load formats: ${load_formats}"

  db_list=$(get_db_set "${operation_mode}" "${query_formats}" "${load_formats}")

  for db in $db_list; do
    log_debug "Installing database: $db"
    install_database $db
  done
else
  log_warning "Databases will not be installed. To install, set installDB to true."
fi