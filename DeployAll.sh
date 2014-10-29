#!/bin/bash

PATH=$PATH:/sbin

. /etc/profile.d/xcat.sh

cd /root/deploy_tools
./deploy_cluster resetdeploy
./deploy_cluster deploy all | tee /tmp/deploy.report
grep 'Services deployed successfully' /tmp/deploy.report | mail -s 'service deployments' kkeller@lbl.gov scanon@lbl.gov dolson@mcs.anl.gov
