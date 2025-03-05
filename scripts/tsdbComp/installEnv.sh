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
  cd ${installPath}
  # if influxdb3 is already installed, no need to reinsall
  if [[ -z `influxdb3 --help` ]];then
    curl -O https://www.influxdata.com/d/install_influxdb3.sh && sh install_influxdb3.sh <<EOF
2
n
EOF
  fi

  source  /root/.bashrc
  # run influxdb3 --version to check if it is installed successfully
  if [[ -z `influxdb3 --version` ]];then
    log_error "Install InfluxDB3 failed"
    exit 1
  fi

  # if influxdb3 is started, restart it
  if ps -ef | grep influxdb3 | grep -v grep > /dev/null; then
    log_debug "Influxdb3 is already started, restarting it"
    pkill influxdb3
  fi
  influx3_path=${influx3_data_dir:-"/var/lib/influxdb3"}
  influx3_port=${influx3_port:-"8086"}
  mkdir -p ${influx3_path}
  nohup influxdb3 serve --node-id=local01 --object-store=file --data-dir ${influx3_data_dir} --http-bind=0.0.0.0:${influx3_port} &

}


# install sshpass,git and dool
cmdInstall sshpass
cmdInstall git
cmdInstall gcc 
cmdInstall cmake 
cmdInstall build-essential
cmdInstall libssl-dev

cd ${installPath}
if [ ! -f "v1.1.0.tar.gz" ] ;then
  wget --quiet https://github.com/scottchiefbaker/dool/archive/refs/tags/v1.1.0.tar.gz  ||  { echo "Download dool 1.1 package failed"; exit 1; }
fi

tar xf v1.1.0.tar.gz && cd dool-1.1.0/ && ./install.py

# install db  
if [ "${installDB}" == "true" ];then
  if [ "${osType}" == "centos" ];then
    yum install -y  curl wget
    install_timescale_centos
    install_influx_centos
    # if [[ -z `influx --help` ]];then
    #   install_influx_centos
    # fi
  elif [ "${osType}" == "ubuntu" ];then
    sudo apt-get update
    sudo apt install wget curl  -y
    install_timescale_ubuntu 
    install_influx_ubuntu 
    # if [[ -z `influx --help` ]];then
    #   install_influx_ubuntu 
    # fi
  else
    log_error "OS type not supported"
  fi
  install_TDengine
  install_influxdb3

  # if [[ -z `taosd --help` ]];then
  #   install_TDengine
  # fi
else 
  log_warning "timescaleDB InfluxDB and TDengine will not be installed. To install, set installDB to true."
fi 


# you need add trust link entry for your host in pg_hba.conf manually
# eg : host    all     all             192.168.0.1/24               md5

if [ "${clientIP}" != "${serverIP}" ]; then
    log_debug "Adding trust link entry for your test server ip in pg_hba.conf automatically"
    trustSlinkPar=`grep -w "${serverIP}" /etc/postgresql/14/main/pg_hba.conf`
# echo "grep -w "${serverIP}" /etc/postgresql/14/main/pg_hba.conf"
# echo "${trustSlinkPar}"
    if [ -z "${trustSlinkPar}" ];then
      echo -e  "\r\nhost    all     all             ${serverIP}/24               md5\n"  >> /etc/postgresql/14/main/pg_hba.conf
    else
      log_debug "Trust link entry for your test server IP is already added in pg_hba.conf"
    fi

    trustClinkPar=`grep -w "${clientIP}" /etc/postgresql/14/main/pg_hba.conf`
    # echo "grep -w "${clientIP}" /etc/postgresql/14/main/pg_hba.conf"
    # echo "${trustClinkPar}"
    if [ -z "${trustClinkPar}" ];then
      echo -e  "\r\nhost    all     all             ${clientIP}/24               md5\n"  >> /etc/postgresql/14/main/pg_hba.conf
    else
      log_debug "Trust link entry for your client IP is already added in pg_hba.conf"
    fi
fi