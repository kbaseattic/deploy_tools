#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "Client name is required"
    exit 1
fi

rsync -av --progress --exclude '/bootstrap' /kbase/runtimes/20141125-prod/ ${1}:/kbase/runtimes/20141125-prod/
rsync -av --progress '/bootstrap' /kb/ ${1}:/kb/

echo "Awe sync completed at $(date)"


