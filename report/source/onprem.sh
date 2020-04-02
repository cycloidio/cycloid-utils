#!/bin/bash

######### Onprem func #########

################
# docker
################
docker_debug () {
  mkdir -p $LOGPATH/docker

  docker info > $LOGPATH/docker/docker_info.log 2>&1
  docker ps -a > $LOGPATH/docker/docker_ps.log 2>&1
  docker images -a > $LOGPATH/docker/docker_images.log 2>&1
  docker stats --no-stream > $LOGPATH/docker/docker_stats.log 2>&1

  cp /etc/default/docker $LOGPATH/docker/etc_default_docker
  systemctl_debug docker.service
}

# -------------------------- Onprem -----------------------------------------

################
# Main Onprem
################

agreement

systemctl_debug cycloid-api_container.service
systemctl_debug cycloid-db_container.service
systemctl_debug cycloid-frontend_container.service
systemctl_debug cycloid-redis_container.service
systemctl_debug cycloid-smtp_container.service
systemctl_debug concourse-db_container.service
systemctl_debug concourse-web_container.service
systemctl_debug vault_container.service

ps_debug
system_debug

mount_debug
network_debug

curl_url https://localhost/api nginx-cycloid-api
curl_url http://localhost:3001 cycloid-api
curl_url https://localhost/ nginx-cycloid-frontend
curl_url http://localhost:8888 cycloid-frontend
curl_url http://localhost:8080 concourse-web_http
curl_url https://localhost:8443 concourse-web_https
curl_url https://localhost:8200/ui/ vault
curl_url https://github.com github.com

access_port localhost 3306 cycloid-db
access_port localhost 6379 cycloid-redis
access_port localhost 1025 cycloid-smtp
access_port localhost 8025 cycloid-smtps
access_port localhost 5432 concourse-db
access_port localhost 2222 concourse-web_tsa_ssh
access_port github.com 22

docker_debug

var_log_debug syslog messages nginx/cycloid-api-access.log nginx/cycloid-api-error.log nginx/cycloid-console-access.log nginx/cycloid-console-error.log
extra_files_debug /etc/nginx/sites-enabled/01-cycloid-console.conf /etc/nginx/sites-enabled/02-cycloid-api.conf /etc/nginx/conf.d/01-proxy.conf

send_report
