#!/bin/bash

PATH=$PATH:/sbin

label='next'

. /etc/profile.d/xcat.sh

cd /root/deploy_tools
./deploy_cluster resetdeploy
# there are race conditions all over the place here, just ignoring for now
./deploy_cluster deploy all |grep -v 'Sending build context to Docker daemon'| tee /tmp/deploy.report.$label
echo "Check status of services: https://monitor.kbase.us/check_mk/view.py?view_name=host&site=berkeley&host=$label-www" > /tmp/deploy.report.$label.mail
echo >> /tmp/deploy.report.$label.mail
grep 'Services deployed successfully' /tmp/deploy.report.$label >> /tmp/deploy.report.$label.mail
# UUOC
cat /tmp/deploy.report.$label.mail | mail -r 'nightly-build@kbase.us' -s "$label.kbase.us Nightly Build Report" kkeller@lbl.gov scanon@lbl.gov dolson@mcs.anl.gov nightly-build@lists.kbase.us
# just in case -r doesn't work in cron job
#cat /tmp/deploy.report.mail | mail -s 'next.kbase.us Nightly Build Report' kkeller@lbl.gov 
