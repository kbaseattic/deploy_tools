#!/bin/sh

prod_tag () {
  SERV=$CW/services
  cd $TDIR
  tag=${1}
  echo "Production Tag: $tag"
  for module in $(cat $SERV|awk -F: '{print $3}') ; do
    echo $module
    if [ ! -e "$module" ] ; then
      git clone ssh://kbase@git.kbase.us/$module
    fi
    cd $module
    git checkout -q master
    git pull -q
    VERS=$(cat $SERV|grep ":${module}:"|awk -F: '{print $9}')
    git checkout -q $VERS || exit
    git tag $tag
    git push --tags
    cd ..
  done
  return 0
}

# Create workspace
CW=$(pwd)
TDIR=/tmp/tagdir
[ -d $TDIR ] || mkdir $TDIR

if [ "${1}" = "-p" ] ; then
  echo "Tagging for production"
  shift
  if [ $# -gt 0 ] ; then
    tag=${1}
  else
    tag="$(date +%Y%m%d)-prod"
  fi
  prod_tag $tag
  exit
elif [ $(echo ${1}|grep -c '^20') -gt 0 ] ; then
  tag=${1}
  shift
else
  tag="$(date +%Y%m%d)-test"
fi

echo "Tag: $tag"
cd $TDIR

for p in $@ ; do
 if [ ! -e "${p}" ] ; then
   git clone ssh://kbase@git.kbase.us/$p
 fi
 cd $p
 git checkout master
 git pull
 git tag $tag
 git push --tags
 cd ..
done
