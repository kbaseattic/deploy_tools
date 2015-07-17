#!/bin/sh
. ./site.cfg
[ -z $IMAGE ] || IMAGE=kbase/depl:1.0

USER=$(id -u)
WWW=$(docker ps|grep _www_|awk '{print $1}')

docker run -it --rm --user $USER --name client-$USER --workdir $HOME --volume $HOME:$HOME --env HOME=$HOME --link $WWW:www --entrypoint bash $IMAGE
