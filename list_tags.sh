#!/bin/sh

if [ $# -eq 0 ] ; then
  s=":"
else
  s=${1}
fi

for r in $(cat services|grep $s|awk -F: '{print $3}') ; do
  ct=$(grep ":${r}:" services|awk -F: '{print $9}')
  t=$(git ls-remote -t ssh://kbase@git.kbase.us/${r} |grep /20|awk -F/ '{print $3}'|sort -n |tail -1)
  if [ "$ct" = "$t" ] ; then
   echo "s:$r $t $ct"
  else
   echo "d:$r $t $ct"
  fi
done


# git ls-remote -t ssh://kbase@git.kbase.us/cluster_service |grep /20|sort -t/ -k 3 -n
