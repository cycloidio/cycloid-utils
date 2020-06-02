#!/bin/bash

LOGPATH=/tmp/debug
SENSITIVE=false

agreement () {

  echo "You are going to create a system report shared with Cycloid, datas will be encrypted and archived.\n
Datas could contains sensitive information like cycloid database credentials. Sensitive datas could help support to understand your issue."

  read -p "Do you want to send sensitive datas to cycloid ? (y/N)? " answer < /dev/tty
  case ${answer:0:1} in
      y|Y )
          SENSITIVE=true
      ;;
      * )
          SENSITIVE=false
      ;;
  esac
}

################
# systemctl
################

systemctl_debug () {
  service=$1
  mkdir -p $LOGPATH/systemctl

  # Get service config
  systemctl cat $service > $LOGPATH/systemctl/$service 2>&1
  systemctl status $service > $LOGPATH/systemctl/$service.status 2>&1

  # Get the EnvironmentFile
  EnvironmentFile=$(cat $LOGPATH/systemctl/$service | grep EnvironmentFile | awk -F '[=]' '{print $2}')
  if [ ! -z "$EnvironmentFile" ]; then
    cp $EnvironmentFile $LOGPATH/systemctl/

    if [ "$SENSITIVE" == "false" ]; then
      sed -i 's/.*PASSWORD=.*/PASSWORD=XXXXXXXX/; s/JWT_KEY.*/JWT_KEY_XXXXX/' $LOGPATH/systemctl/$(basename $EnvironmentFile)
    fi

  fi

  # Get service logs
  journalctl -xel -u $service > $LOGPATH/systemctl/$service.log 2>&1
}

################
# ps
################

ps_debug () {
  mkdir -p $LOGPATH
  # Get process
  ps aux > $LOGPATH/ps.log
}

################
# system
################

system_debug () {
  mkdir -p $LOGPATH/system

  # Get uptime
  uptime > $LOGPATH/system/uptime

  # Show who is logged on
  w > $LOGPATH/system/w_logged_users

  # Get Kernel version
  uname -a  > $LOGPATH/system/uptime
  cat /proc/cmdline > $LOGPATH/system/proc_cmdline
}

################
# /var/log/ like user-data.log
################

var_log_debug () {
  logfiles=$*
  mkdir -p $LOGPATH/var_log
  # Get service logs

  for log in $logfiles; do
    cp /var/log/$log $LOGPATH/var_log/$(echo $log | sed 's/\//-/g');
  done
}

################
# checkou mounted volumes
################

mount_debug () {
  mkdir -p $LOGPATH
  # Get mount
  cat /proc/mounts > $LOGPATH/mounts.log 2>&1
}

################
# cp extra files
################

extra_files_debug () {
  mkdir -p $LOGPATH/files
  files=$*
  # Copy extra files
  for file in $files; do
    cp $file $LOGPATH/files/$(echo $file | sed 's/\//-/g');
  done
}

################
# network / resolv / firewall
################

network_debug () {
  mkdir -p $LOGPATH/network
  # Get resolv
  cp /etc/resolv.conf $LOGPATH/network/
  # Get hosts
  cp /etc/hosts $LOGPATH/network/

  # network interfaces
  ip a > $LOGPATH/network/ip_a 2>&1

  # routing
  ip r > $LOGPATH/network/ip_r 2>&1

  # hostname
  cat /etc/hostname > $LOGPATH/network/hostname 2>&1

  # iptables
  iptables -L -xvn > $LOGPATH/network/iptables 2>&1
  iptables -L -xvn -t nat > $LOGPATH/network/iptables_nat 2>&1

  netstat -lutpena > $LOGPATH/network/netstat.log 2>&1

  # iptables
  echo "ip_forward: $(cat /proc/sys/net/ipv4/ip_forward)" > $LOGPATH/network/ip_forward
}

################
# curl url
################

curl_url () {
  mkdir -p $LOGPATH/curl
  # curl url
  url=$1
  if [ -z "$2" ]; then
    name=$url
  else
    name=$2
  fi

  echo "curl $url -k -vL" >> $LOGPATH/curl/$name.log
  curl $url  --connect-timeout 5 -k -vL  >> $LOGPATH/curl/$name.log 2>&1
  echo "" >> $LOGPATH/curl/$name.log
}

################
# Port access / <url> <port>
################
access_port () {
  mkdir -p $LOGPATH/access_port
  url=$1
  port=$2
  if [ -z "$3" ]; then
    name="${url}_${port}"
  else
    name=$3
  fi

  echo "nc -zv -w 2 $url $port" > $LOGPATH/access_port/$name.log
  #validate if access to the port is allowed
  nc -zv -w 2 $url $port >> $LOGPATH/access_port/$name.log 2>&1
}

################
# Validate rsa key format
################

validate_rsa_key () {
  mkdir -p $LOGPATH/openssl
  key=$1

  # Check openssl rsa format
  if [ "$SENSITIVE" == "true" ]; then
    openssl rsa -noout -text -in $key -check > $LOGPATH/openssl/$(echo $key | sed 's/\//-/g') 2>&1
  else
    openssl rsa -noout -text -in $key -check 2>&1 | sed -e 1b -e '$!d' > $LOGPATH/openssl/$(echo $key | sed 's/\//-/g')
  fi
}

################
# Save / export
################
send_report () {
  cd $LOGPATH
  filename=debug-$(date +%Y-%m-%d-%H:%M:%S).tar.gz

  tar zcf /tmp/${filename} . >> /tmp/send_report.log 2>&1
  rm -rf $LOGPATH

  SECRET="$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)"
  cd /tmp
  echo $SECRET | gpg --passphrase-fd 0 --batch  --symmetric ${filename}

  echo ""
  echo "Report have been saved under /tmp/${filename}.gpg"
  echo ""
  echo "Please share this url and secret to cycloid team: "
  echo ""
  curl https://pastefile-owl.cycloid.io -F file=@${filename}.gpg
  echo "secret: $SECRET"
  rm /tmp/${filename} -rf
}
