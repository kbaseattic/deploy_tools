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
else
  ./deploy_cluster start
fi

while [ true ] ; do
  sleep 60
done
