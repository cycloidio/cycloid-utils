#!/bin/bash

######### Worker func #########

################
# Test access to concourse tsa
################
curl_tsa () {
  # test tsa url (<host port>)
  TSA_URL=$(cat /var/lib/concourse/concourse-worker | grep tsa-host | awk -F '[":]' '{print $2,$3}')
  access_port $TSA_URL concourse_tsa
}

################
# Get worker healthcheck
################
worker_status () {
  echo "curl 127.0.0.1:8888 -v" > $LOGPATH/worker_status.log
  curl 127.0.0.1:8888 -v > $LOGPATH/worker_status.log 2>&1
}

################
# Worker restart manual
################

#stop of worker service then start it (manually with a timeout and echo on a debug log file) ??
worker_restart () {
  mkdir -p $LOGPATH
  # Get listening services
  timeout 10 /var/lib/concourse/concourse-worker > $LOGPATH/worker_restart.log 2>&1
}


# -------------------------- Worker -----------------------------------------

################
# Main Worker
################

agreement

systemctl_debug concourse-worker.service
systemctl_debug var-lib-concourse-datas.mount

mount_debug

ps_debug

curl_tsa
curl_url https://github.com github.com
access_port github.com 22

network_debug

worker_status

var_log_debug user-data.log concourse-worker.log syslog

extra_files_debug /var/lib/concourse/concourse-worker /var/lib/concourse/host_key.pub

if [ "$SENSITIVE" == "true" ]; then
  extra_files_debug /var/lib/concourse/worker_key
fi
validate_rsa_key /var/lib/concourse/worker_key

send_report
