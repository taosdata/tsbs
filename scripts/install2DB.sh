#!/bin/bash

# set parameters by default value
osType=centos   # -o [centos | ubuntu]

while getopts "ho:" arg
do
  case $arg in
    o)
      #echo "osType=$OPTARG"
      osType=$(echo $OPTARG)
      ;;
    h)
      echo "Usage: `basename $0` -o [centos | ubuntu]"
      exit 0
      ;;
    ?) #unknow option
      echo "unkonw argument"
      exit 1
      ;;
  esac
done

function install_timescale_centos(){
# install timescaledb in centos 
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

  yum remove timescaledb-2-postgresql-14 -y
  yum remove postgresql-14 -y
  yum install timescaledb-2-postgresql-14 -y
}

function install_influx_centos(){
  rpm -e influxdb
  wget https://dl.influxdata.com/influxdb/releases/influxdb-1.8.10.x86_64.rpm
  sudo yum localinstall influxdb-1.8.10.x86_64.rpm
}

function install_timescale_ubuntu(){
  apt install gnupg postgresql-common apt-transport-https lsb-release wget
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
  curl -L https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
  sh -c "echo 'deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main' > /etc/apt/sources.list.d/timescaledb.list"
  wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add -
  apt update
  apt install timescaledb-2-postgresql-14
}

function install_influxdb_ubuntu(){
  dpkg -r influxdb
  wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_amd64.deb
  sudo dpkg -i influxdb_1.8.10_amd64.deb
}


# install influxdb and timescaledb
# maybe will add function of uninstalling timescaledb（cause i don't know how to uninstall timescale ）
if [ osType="centos" ];then
  install_timescale_centos
  install_influx_centos
elif [ osType="ubuntu" ];then
  install_timescale_ubuntu
  install_influxdb_ubuntu
else
  echo "osType can't be supported"
fi


# configure postgresql 
sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
sudo systemctl enable postgresql-14
sudo systemctl start postgresql-14


# reset default password:password 
su - postgres -c "psql -U postgres -c \"alter role  postgres with password 'password';\""
echo "shared_preload_libraries = 'timescaledb'" >> /var/lib/pgsql/14/data/postgresql.conf  
systemctl restart  postgresql-14
PGPASSWORD=password psql -U postgres -h localhost -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
