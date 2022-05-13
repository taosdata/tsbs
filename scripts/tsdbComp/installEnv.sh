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
clientIP="192.168.0.203"
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
        apt-get install ${comd}
    elif command -v yum ;then
        yum install ${comd}
    else
        echo "you should install ${comd} manually"
    fi
fi
}

function install_timescale_centos {
# install timescaledb in centos 
echo "=============install timescaledb in centos ============="
echo "=============timescaledb in centos: configure preinstall   ============="
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

echo "=============timescaledb in centos: remove and install  ============="
  yum remove postgresql-14 -y
  yum remove timescaledb-2-postgresql-14 -y
#   yum remove postgresql-14 -y
  yum install timescaledb-2-postgresql-14 -y

echo "=============timescaledb in centos: start ============="
  # configure postgresql 
  sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
  sudo systemctl enable postgresql-14
  sudo systemctl start postgresql-14

  echo "============timescaledb in centos: configure and start postgresql ============="
  sharePar1=`grep -w "shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  sharePar2=`grep -w "#shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  if [[ -z "${sharePar1}" ]] || [[  -n  "${sharePar2}" ]];then
    echo "shared_preload_libraries = 'timescaledb'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    echo "sharePar has already been add to postgresql.conf"
  fi

  listenPar1=`grep -w "listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf `
  listenPar2=`grep -w "#listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf `
  if [[ -z "${listenPar1}" ]] || [[  -n "${listenPar2}" ]];then
    echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    echo "listenPar has already been add to postgresql.conf"    
  fi 
  systemctl restart  postgresql 

  echo "=============timescaledb in centos: reset password to 'password'  and add extension timescaledb for postgresql ============="
  # reset default password:password 
  su - postgres -c "psql -U postgres -c \"alter role  postgres with password 'password';\""
  systemctl restart  postgresql 
  PGPASSWORD=password psql -U postgres -h localhost -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
}

function install_influx_centos {
echo "=============reinstall influx in centos ============="
  rpm -e influxdb
  cd ${installPath}
  yum install wget
  if [ ! -f "influxdb-1.8.10.x86_64.rpm"  ] ;then
    wget https://dl.influxdata.com/influxdb/releases/influxdb-1.8.10.x86_64.rpm
  fi
  sudo yum  -y localinstall influxdb-1.8.10.x86_64.rpm
  indexPar1=`grep -w 'index-version = "tsi1"' /etc/influxdb/influxdb.conf `
  indexPar2=`grep -w '#index-version = "tsi1"'  /etc/influxdb/influxdb.conf `
  if [[ -z "${indexPar1}" ]] || [[  -n "${indexPar2}" ]];then
    sed -i '/^\[data\]/a\ index-version = "tsi1"'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ max-values-per-tag = 0'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ cache-max-memory-size = "5g"'  /etc/influxdb/influxdb.conf 
  else 
    echo "indexPar has already been add to influxdb.conf"    
  fi 
systemctl restart influxd
}

function install_timescale_ubuntu {
  echo "=============reinstall timescaledb in ubuntu ============="
  echo "=============timescaledb in ubuntu: configure preinstall   ============="
  apt install -y  gnupg postgresql-common apt-transport-https lsb-release wget 
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y 
  curl -L https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
  sh -c "echo 'deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main' > /etc/apt/sources.list.d/timescaledb.list"
  wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add -
  apt update -y 
  
  echo "=============timescaledb in ubuntu: remove and install  ============="
  apt remove postgresql-14 -y
  apt remove timescaledb-2-postgresql-14 -y
  apt install postgresql-14 -y
  apt install timescaledb-2-postgresql-14 -y 

  echo "============timescaledb in ubuntu: configure and start postgresql ============="
  sharePar1=`grep -w "shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  sharePar2=`grep -w "#shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  if [[ -z "${sharePar1}" ]] || [[  -n  "${sharePar2}" ]];then
    echo "shared_preload_libraries = 'timescaledb'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    echo "sharePar has already been add to postgresql.conf"
  fi

  listenPar1=`grep -w "listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf `
  listenPar2=`grep -w "#listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf `
  if [[ -z "${listenPar1}" ]] || [[  -n "${listenPar2}" ]];then
    echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    echo "listenPar has already been add to postgresql.conf"    
  fi 
  systemctl restart  postgresql 

  echo "=============timescaledb in ubuntu: reset password to 'password'  and add extension timescaledb for postgresql ============="
  # reset default password:password 
  su - postgres -c "psql -U postgres -c \"alter role  postgres with password 'password';\""
  systemctl restart  postgresql 
  PGPASSWORD=password psql -U postgres -h localhost -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
}

function install_influx_ubuntu {
  echo "=============reinstall influx in ubuntu ============="
  dpkg -r influxdb
  cd ${installPath}
  if [ ! -f "influxdb_1.8.10_amd64.deb" ] ;then
     wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_amd64.deb
  fi
  sudo dpkg -i influxdb_1.8.10_amd64.deb
  indexPar1=`grep -w 'index-version = "tsi1"' /etc/influxdb/influxdb.conf `
  indexPar2=`grep -w '#index-version = "tsi1"'  /etc/influxdb/influxdb.conf `
  if [[ -z "${indexPar1}" ]] || [[  -n "${indexPar2}" ]];then
    sed -i '/^\[data\]/a\ index-version = "tsi1"'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ max-values-per-tag = 0'  /etc/influxdb/influxdb.conf 
    sed -i '/^\[data\]/a\ cache-max-memory-size = "5g"'  /etc/influxdb/influxdb.conf 
  else 
    echo "indexPar has already been add to influxdb.conf"    
  fi 
systemctl restart influxd
}


function install_TDengine {
  echo "=============reinstall TDengine  in ubuntu ============="
  cd ${installPath}
  if [ ! -f "TDengine-server-2.4.0.14-Linux-x64.tar.gz"  ] ;then
    wget https://taosdata.com/assets-download/TDengine-server-2.4.0.14-Linux-x64.tar.gz 
  fi
  tar xvf TDengine-server-2.4.0.14-Linux-x64.tar.gz 
  cd  TDengine-server-2.4.0.14
  ./install.sh  -e no
  systemctl restart taosd
  taosPar=`grep -w "tableIncStepPerVnode 100000" /etc/taos/taos.cfg`
  if [ -z "${taosPar}" ];then
    echo -e  "tableIncStepPerVnode 100000\nminTablesPerVnode    100000 \nmaxSQLLength 1048576 \n#tscEnableRecordSql 1 \n#debugflag 135 \n#shortcutFlag 1 \n"  >> /etc/taos/taos.cfg
  fi
  fqdnCPar=`grep -w "${clientIP} ${clientHost}" /etc/hosts`
  fqdnSPar=`grep -w "${serverIP} ${serverHost}" /etc/hosts`
  if [ -z "${fqdnCPar}" ];then
    echo -e  "\n${clientIP} ${clientHost} \n"  >> /etc/hosts
  fi
  if [ -z "${fqdnSPar}" ];then
    echo -e  "\n${serverIP} ${serverHost} \n"  >> /etc/hosts
  fi
}



cmdInstall sshpass
cmdInstall git


if [ "${installDB}" == "true" ];then
  if [ "${osType}" == "centos" ];then
    yum install -y  curl wget
    yum install expect -y 
    install_timescale_centos
    install_influx_centos
    # if [[ -z `influx --help` ]];then
    #   install_influx_centos
    # fi
  elif [ "${osType}" == "ubuntu" ];then
    apt install wget -y
    apt install curl -y
    install_timescale_ubuntu 
    install_influx_ubuntu 
    # if [[ -z `influx --help` ]];then
    #   install_influx_ubuntu 
    # fi
  else
    echo "osType can't be supported"
  fi
  install_TDengine

  # if [[ -z `taosd --help` ]];then
  #   install_TDengine
  # fi
else 
  echo "It doesn't install timescaleDB InfluxDB and TDengine.If you want to install,please set installGo env true"
fi 


# you need add trust link entry for your host in pg_hba.conf manually
# eg : host    all     all             192.168.0.1/24               md5

trustlinkPar=`grep -w "${serverIP}" /etc/postgresql/14/main/pg_hba.conf`
echo "grep -w "${serverIP}" /etc/postgresql/14/main/pg_hba.conf"
echo "${trustlinkPar}"
if [ -z "${trustlinkPar}" ];then
  echo -e  "\r\nhost    all     all             ${serverIP}/24               md5\n"  >> /etc/postgresql/14/main/pg_hba.conf
else
  echo "it has been added trust link entry for your test server ip in pg_hba.conf"
fi
