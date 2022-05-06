#!/bin/bash

# set -e
# set parameters by default value
osType=ubuntu   # -o [centos | ubuntu]
installGoEnv=false
installDB=false
installTsbs=false


while getopts "ho:g:d:t:" arg
do
  case $arg in
    o)
      osType=$(echo $OPTARG)
      ;;
    g)
      installGoEnv=$(echo $OPTARG)
      ;;
    d)
      installDB=$(echo $OPTARG)
      ;;
    t)
      installTsbs=$(echo $OPTARG)
      ;;
    h)
      echo "Usage: `basename $0` -o osType [centos | ubuntu]
                              -g installGoEnv [true | false]
                              -d installDB [true | false]           
                              -t installTsbs [true | false]
                              -h get help         
      osType's default values is  ubuntu,other is false"
      exit 0
      ;;
    ?) #unknow option
      echo "unkonw argument"
      exit 1
      ;;
  esac
done


installPath="/usr/local/src/"


echo "install path: ${installPath}"
echo "installGoEnv: ${installGoEnv}"
echo "installDB: ${installDB}"
echo "installTsbs: ${installTsbs}"


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

echo "=============timescaledb in centos: reset password to 'password' ============="

  # reset default password:password 
  su - postgres -c "psql -U postgres -c \"alter role  postgres with password 'password';\""
  sharePar=`grep "shared_preload_libraries = 'timescaledb'"  /etc/postgresql/14/main/postgresql.conf  `
  if [ -z "${sharePar}" ];then
    echo "shared_preload_libraries = 'timescaledb'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    echo "it has already been add to postgresql.conf"
  fi
  listenPar=`grep "listen_addresses = '\*'"  /etc/postgresql/14/main/postgresql.conf  `
  if [ -z "${listenPar}" ];then
    echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
  else 
    echo "it has already been add to postgresql.conf"    
  fi
  systemctl restart  postgresql-14
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

  echo "=============timescaledb in ubuntu: start ============="
#   #configure postgresql 
#   sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
#   sudo systemctl enable postgresql-14
  sudo systemctl  restart postgresql

  echo "=============timescaledb in ubuntu: configure and reset password to 'password' ============="
  # reset default password:password 
  su - postgres -c "psql -U postgres -c \"alter role  postgres with password 'password';\""
  
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
  PGPASSWORD=password psql -U postgres -h localhost -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
}

function install_influxdb_ubuntu {
  echo "=============reinstall influx in ubuntu ============="
  dpkg -r influxdb
  apt install wget
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
  cd /usr/local/src
  if [ ! -f "TDengine-server-2.4.0.14-Linux-x64.deb"  ] ;then
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
}



# install go env
function install_go_env {
echo "============= install go and set go env ============="
goenv=`go env`
if [[ -z ${goenv} ]];then
    echo "install go "
    # cd /usr/local/
    # if [ ! -f "TDengine-server-2.4.0.14-Linux-x64.deb"  ] ;then
    #     wget https://studygolang.com/dl/golang/go1.16.9.linux-amd64.tar.gz
    # fi 
    # tar -zxvf  go1.16.9.linux-amd64.tar.gz
    echo "add go to PATH"
    GO_HOME=/usr/local/go
    goPar=`grep -w "GO_HOME=/usr/local/go"  /root/.bashrc`
    export PATH=$GO_HOME/bin:$PATH
    if [[ -z ${goPar} ]];then
        echo -e  '\n# GO_HOME\nexport GO_HOME=/usr/local/go\nexport PATH=$GO_HOME/bin:$PATH\n' >> /root/.bashrc
    else 
        echo "GOHOME already been add to PATH of /root/.bashrc"    
    fi 
    source  /root/.bashrc
    echo $PATH
else
    echo "go has been installed"
fi

go env -w GOPROXY=https://goproxy.cn,direct
export GO111MODULE=on
echo `go env`
echo ${GOPATH}
if [[ -z "${GOPATH}" ]];then
    echo "add go path to PATH and set GOPATH"
    export GOPATH=$(go env GOPATH)
    export PATH=$PATH:$(go env GOPATH)/bin
    gopathPar=`grep -w "PATH=\$PATH:\$(go env GOPATH)/bin"  /root/.bashrc`
    if [[ -z ${goPar} ]];then
      echo -e  '\nexport GOPATH=$(go env GOPATH)\nexport PATH=$PATH:$(go env GOPATH)/bin\n' >> ~/.bashrc
      source  /root/.bashrc
    fi
else
    echo "GOPATH has been added"
fi
}

# compile tsbs 
function install_tsbs {
  echo "install tsbs"
  go get github.com/timescale/tsbs
  cd ${GOPATH}/pkg/mod/github.com/timescale/tsbs*/ && make

  # clone taosdata repo and  compile
  cd ${installPath} 
  # if [ ! -d ${installPath}/tsbs ];then
  #     git clone git@github.com:taosdata/tsbs.git 
  # fi
  if [ -d "${installPath}/tsbs" ];then 
    cd ${installPath}/tsbs/
    git pull origin master
  else
    git clone git@github.com:taosdata/tsbs.git 
  fi

  [ -d "${GOPATH}/bin" ] || mkdir ${GOPATH}/bin/

  cd ${installPath}/tsbs/cmd/tsbs_generate_data/  &&  go build && cp tsbs_generate_data ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_generate_queries/  && go build && cp tsbs_generate_queries  ${GOPATH}/bin/
  # cd ${installPath}/tsbs/cmd/tsbs_load/  &&  go build && cp tsbs_load  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_load_tdengine/  && go build && cp tsbs_load_tdengine  ${GOPATH}/bin/
  cd ${installPath}/tsbs/cmd/tsbs_run_queries_tdengine/ && go build  && cp tsbs_run_queries_tdengine  ${GOPATH}/bin/

}

if [ "${installGoEnv}" == "true" ];then
  install_go_env
else 
  echo "It doesn't  install go and set go env.If you want to install,please set installGo-env true"
fi 

# install  influxdb and timescaledb 
# maybe will add function of uninstalling timescaledb（cause i don't know how to uninstall timescale ）
# you need add trust link entry for your host in pg_hba.conf manually
# eg : host    all     all             192.168.0.1/24               md5

if [ "${installDB}" == "true" ];then
  if [ "${osType}" == "centos" ];then
    yum install expect -y 
    install_timescale_centos
    install_influx_centos
  elif [ "${osType}" == "ubuntu" ];then
    install_timescale_ubuntu
    install_influxdb_ubuntu
  else
    echo "osType can't be supported"
  fi
  install_TDengine
else 
  echo "It doesn't install timescaleDB InfluxDB and TDengine.If you want to install,please set installGo env true"
fi 

if [ "${installTsbs}" == "true" ];then
  install_tsbs
else 
  echo "It doesn't install and update tsbs.If you want to install,please set installGo env true"
fi 