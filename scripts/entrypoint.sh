#!/bin/bash

if [ "$MYSERVICES" = "www" ] ; then
  echo "www"
  mkdir /etc/nginx/ssl
  cp ./ssl/proxy.crt /etc/nginx/ssl/server.crt
  cp ./ssl/proxy.key /etc/nginx/ssl/server.key.insecure
  /etc/init.d/nginx start
  sleep 10000000000
elif [ "$MYSERVICES" = "narrative" ] ; then
  echo "narrative"
  SKIPNAR=1 ./config/postprocess_narrative 
  # Use production auth since redeployed auth is broken
  grep -rl authorization /kb/deployment/ui-common|xargs sed -i 's/\/\/[^/]*\/services\/authorization/\/\/kbase.us\/services\/authorization/'
  # Dial back number of narratives
  sed -i 's/M.provision_count = 20/M.provision_count = 2/' /kb/deployment/services/narrative/docker/proxy_mgr.lua 
  sed -i 's/VolumesFrom = "",/VolumesFrom = json.util.null,/' /kb/deployment/services/narrative/docker/docker.lua
  # Certs
  mkdir /etc/nginx/ssl
  cp ./ssl/narrative.crt /etc/nginx/ssl/server.chained.crt
  cp ./ssl/narrative.key /etc/nginx/ssl/server.key
  GID=$(ls -n /var/run/docker.sock |awk '{print $4}')
  groupmod -g $GID docker
  usermod -g $GID www-data
  /etc/init.d/nginx start
  sleep 10000000000
elif [ "$MYSERVICES" = "aweworker" ] ; then
  echo $ADMIN_PASS|kbase-login $ADMIN_USER
  unset ADMIN_PASS
  AUTH="Authorization: OAuth $(grep token ~/.kbase_config|sed 's/token=//')";
  curl -s -X POST -H "$AUTH" http://awe:7107/cgroup/$CGROUP > /dev/null
  TOK=$(curl -s -H "$AUTH" http://awe:7107/cgroup/|python -mjson.tool|sed 's/ /\n/'|grep $CGROUP|grep token|sed 's/.*name=/name=/'|sed 's/"//')
  sed -i "s/replacetoken/$TOK/" cluster.ini
  ./config/postprocess_aweworker
  ./deploy_cluster start
  sleep 10000000000
else
  [ -e /mnt/Shock/data ] || mkdir /mnt/Shock/data /mnt/Shock/site /mnt/Shock/logs
  [ -e /mnt/transform_working ] || mkdir /mnt/transform_working
  ./deploy_cluster start
  L=$(ls /kb/deployment//services/*/*/*/*/server.log)
  [ ! -z $L ] && tail -n 1000 -f $L
fi

