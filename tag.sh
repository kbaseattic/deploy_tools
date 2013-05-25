#!/bin/sh


if [ $(echo ${1}|grep -c '^20') -gt 0 ] ; then
  tag=${1}
  shift
else
  tag="$(date +%Y%m%d)-test"
fi
echo "Tag: $tag"

TDIR=/tmp/tagdir

[ -d $TDIR ] || mkdir $TDIR
cd $TDIR

for p in $@ ; do
 git clone ssh://kbase@git.kbase.us/$p
 cd $p
 git tag $tag
 git push --tags
 cd ..
# rm -rf $p
done
