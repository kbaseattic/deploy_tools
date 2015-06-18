#!/bin/bash

if [ "$MYSERVICES" = "www" ] ; then
  echo "www"
  openssl genrsa -des3 -out server.key -passout pass:temp 2048
  openssl req -batch -config openssl.cnf -new -passin pass:temp -key server.key -out server.csr
  openssl x509 -req -days 365 -passin pass:temp -in server.csr -signkey server.key -out server.crt
  openssl rsa -passin pass:temp -in server.key -out server.key.insecure
  mkdir /etc/nginx/ssl
  cp server* /etc/nginx/ssl
  /etc/init.d/nginx start
elif [ "$MYSERVICES" = "narrative" ] ; then
  echo "narrative"
  SKIPNAR=1 ./config/postprocess_narrative 
  sed -i 's/M.provision_count = 20/M.provision_count = 2/' proxy_mgr.lua /kb/dev_container/modules/narrative/docker/proxy_mgr.lua 
  openssl genrsa -des3 -out server.key -passout pass:temp 2048
  openssl req -batch -config openssl.cnf -new -passin pass:temp -key server.key -out server.csr
  openssl x509 -req -days 365 -passin pass:temp -in server.csr -signkey server.key -out server.chained.crt
  openssl rsa -passin pass:temp -in server.key -out server.key
  mkdir /etc/nginx/ssl
  cp server* /etc/nginx/ssl
  groupmod -g 115 docker
  usermod -g 115 www-data
  /etc/init.d/nginx start
elif [ "$MYSERVICES" = "aweworker" ] ; then
  echo $ADMIN_PASS|kbase-login $ADMIN_USER
  unset ADMIN_PASS
  AUTH="Authorization: OAuth $(grep token ~/.kbase_config|sed 's/token=//')";
  curl -s -X POST -H "$AUTH" http://awe:7107/cgroup/$CGROUP > /dev/null
  TOK=$(curl -s -H "$AUTH" http://awe:7107/cgroup/|python -mjson.tool|grep token|sed 's/.*name=/name=/'|sed 's/"//')
  sed -i "s/replacetoken/$TOK/" cluster.ini
  ./config/postprocess_aweworker
  ./deploy_cluster start
else
  [ -e /mnt/Shock/data ] || mkdir /mnt/Shock/data /mnt/Shock/site /mnt/Shock/logs
  ./deploy_cluster start
fi

while [ true ] ; do
  sleep 60
done

