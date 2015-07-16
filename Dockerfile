# Dockerfile that builds a minimal container for IPython + narrative
#
# Copyright 2013 The Regents of the University of California,
# Lawrence Berkeley National Laboratory
# United States Department of Energy
# The DOE Systems Biology Knowledgebase (KBase)
# Made available under the KBase Open Source License
#
FROM kbase/deplbase:1.0
MAINTAINER Shane Canon scanon@lbl.gov

ADD ./ /root/dt/
WORKDIR /root/dt
ENV TARGET /kb/deployment
ENV PATH ${TARGET}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV USER root
RUN  git config --global user.email "user@kbase.us";git config --global user.name "Docker User"

# This run command does several things including:
# - Changing the memory size for the workspace
# - Deploy the nginx config (setup_www)
# - Run postporcess for shock and awe
# - Clones special versions of ui-common and narrative
#	cd modules/auth_service;cat /root/dt/auth.fix |patch -p0;make deploy;\
RUN cp ./cluster.ini /kb/deployment/deployment.cfg;\
	cd /kb/dev_container/;. ./user-env.sh;\
	cd /root/dt; \
	sed -i 's/10000/256/' /kb/deployment/services/workspace/start_service && \
	sed -i 's/15000/384/' /kb/deployment/services/workspace/start_service && \
	cd config;NOSTART=1 MYSERVICES=www ./setup_www;cd ../;\
	./config/postprocess_shock;\
	./config/postprocess_awe;\
        sed -i 's/ssl_verify = True/ssl_verify = False/' /kb/deployment/lib/biokbase/Transform/script_utils.py;\
	MYSERVICES=Transform ./config/postprocess_Transform;\
	mkdir /mnt;mkdir /mnt/Shock;\
	mkdir /mnt/Shock/logs;\
        cd /kb/dev_container/modules;\
        git clone https://github.com/kbase/ui-common -b staging;\
        git clone https://github.com/scanon/narrative -b docker

# We need to refix start
RUN sed -i 's/start_service &/start_service/' /root/dt/perl/KBDeploy.pm

ENTRYPOINT ./scripts/entrypoint.sh
