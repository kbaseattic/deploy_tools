#!/bin/bash

if [ "$MYSERVICES" = "www" ] ; then
  echo "www"
  mkdir /etc/nginx/ssl
  cp ./ssl/proxy.crt /etc/nginx/ssl/server.crt
  cp ./ssl/proxy.key /etc/nginx/ssl/server.key.insecure
  /etc/init.d/nginx start
elif [ "$MYSERVICES" = "narrative" ] ; then
  echo "narrative"
  SKIPNAR=1 ./config/postprocess_narrative 
  # Use production auth since redeployed auth is broken
  grep -rl authorization /kb/deployment/ui-common|xargs sed -i 's/\/\/[^/]*\/services\/authorization/\/\/kbase.us\/services\/authorization/'
  # Dial back number of narratives
  sed -i 's/M.provision_count = 20/M.provision_count = 2/' /kb/deployment/services/narrative/docker/proxy_mgr.lua 
  # Certs
  mkdir /etc/nginx/ssl
  cp ./ssl/narrative.crt /etc/nginx/ssl/server.chained.crt
  cp ./ssl/narrative.key /etc/nginx/ssl/server.key
  groupmod -g 115 docker
  usermod -g 115 www-data
  /etc/init.d/nginx start
elif [ "$MYSERVICES" = "aweworker" ] ; then
  echo $ADMIN_PASS|kbase-login $ADMIN_USER
  unset ADMIN_PASS
  AUTH="Authorization: OAuth $(grep token ~/.kbase_config|sed 's/token=//')";
  curl -s -X POST -H "$AUTH" http://awe:7107/cgroup/$CGROUP > /dev/null
  TOK=$(curl -s -H "$AUTH" http://awe:7107/cgroup/|python -mjson.tool|sed 's/ /\n/'|grep $CGROUP|grep token|sed 's/.*name=/name=/'|sed 's/"//')
  sed -i "s/replacetoken/$TOK/" cluster.ini
  ./config/postprocess_aweworker
  ./deploy_cluster start
else
  [ -e /mnt/Shock/data ] || mkdir /mnt/Shock/data /mnt/Shock/site /mnt/Shock/logs
  [ -e /mnt/transform_working ] || mkdir /mnt/transform_working
  ./deploy_cluster start
fi

while [ true ] ; do
  sleep 60
done

