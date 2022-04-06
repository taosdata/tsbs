#!/bin/bash

set -e
# set parameters by default value
osType=ubuntu   # -o [centos | ubuntu]

while getopts "ho:" arg
do
  case $arg in
    o)
      #echo "osType=$OPTARG"
      osType=$(echo $OPTARG)
      ;;
    h)
      echo "Usage: `basename $0` -o [centos | ubuntu]
                              -h get help         
      osType's default values is  ubuntu"
      exit 0
      ;;
    ?) #unknow option
      echo "unkonw argument"
      exit 1
      ;;
  esac
done

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
  cd /usr/local/
  if [ ! -f "influxdb-1.8.10.x86_64.rpm"  ] ;then
    wget https://dl.influxdata.com/influxdb/releases/influxdb-1.8.10.x86_64.rpm
  fi
  sudo yum  -y localinstall influxdb-1.8.10.x86_64.rpm

  indexPar1=`grep -w 'index-version = "tsi1"' /etc/influxdb/influxdb.conf `
  indexPar2=`grep -w '#index-version = "tsi1"'  /etc/influxdb/influxdb.conf `

  if [[ -z "${indexPar1}" ]] || [[  -n "${indexPar2}" ]];then
    echo 'index-version = "tsi1"' >> /etc/postgresql/14/main/postgresql.conf
  else 
    echo "indexPar has already been add to influxdb.conf"    
  fi 
  nohup influxd & 
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
  apt remove timescaledb-2-postgresql-14 -y
  apt install timescaledb-2-postgresql-14 -y 

  echo "=============timescaledb in ubuntu: start ============="
#   #configure postgresql 
#   sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
#   sudo systemctl enable postgresql-14
  sudo service postgresql restart

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
  service postgresql restart
  PGPASSWORD=password psql -U postgres -h localhost -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
}

function install_influxdb_ubuntu {
  echo "=============reinstall influx in ubuntu ============="
  dpkg -r influxdb
  apt  install curl
  cd /usr/local/
  if [ ! -f "influxdb_1.8.10_amd64.deb" ] ;then
     wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_amd64.deb
  fi
  sudo dpkg -i influxdb_1.8.10_amd64.deb
  indexPar1=`grep -w 'index-version = "tsi1"' /etc/influxdb/influxdb.conf `
  indexPar2=`grep -w '#index-version = "tsi1"'  /etc/influxdb/influxdb.conf `

  if [[ -z "${indexPar1}" ]] || [[  -n "${indexPar2}" ]];then
    echo 'index-version = "tsi1"' >> /etc/postgresql/14/main/postgresql.conf
  else 
    echo "indexPar has already been add to influxdb.conf"    
  fi 
  nohup influxd & 
}


# install influxdb and timescaledb
# maybe will add function of uninstalling timescaledb（cause i don't know how to uninstall timescale ）
# you need add trust link entry for your host in pg_hba.conf manually
# eg : host    all     all             192.168.0.1/24               md5
if [ "${osType}" = "centos" ];then
  install_timescale_centos
  install_influx_centos
elif [ "${osType}" = "ubuntu" ];then
  install_timescale_ubuntu
  # install_influxdb_ubuntu
else
  echo "osType can't be supported"
fi


# install go env
echo "============= install go and set go env ============="
go env
if [ $? -ne 0 ];then
    echo "install go "
    cd /usr/local/
    wget https://studygolang.com/dl/golang/go1.16.9.linux-amd64.tar.gz
    tar -zxvf  go1.16.9.linux-amd64.tar.gz
    echo -e  '\n# GO_HOME\nexport GO_HOME=/usr/local/go\nexport PATH=$GO_HOME/bin:$PATH\nexport PATH=$PATH:$(go env GOPATH)/bin\nexport GOPATH=$(go env GOPATH)' >> ~/.bashrc
    source ~/.bashrc
    go env -w GOPROXY=https://goproxy.cn,direct
    export GO111MODULE=on
else
    echo "go has been installed"
fi

GOPATH=$(go env GOPATH)
echo "${GOPATH}"
if [ -z "${GOPATH}" ];then
    echo "add go path to PATH and set GOPATH"
    echo -e  '\n# GO_HOME\nexport GO_HOME=/usr/local/go\nexport PATH=$GO_HOME/bin:$PATH\nexport PATH=$PATH:$(go env GOPATH)/bin\nexport GOPATH=$(go env GOPATH)' >> ~/.bashrc
else
    echo "GOPATH has been added"
fi

# compile tsbs 
go get github.com/timescale/tsbs
cd ${GOPATH}/pkg/mod/github.com/timescale/tsbs*/ && make
