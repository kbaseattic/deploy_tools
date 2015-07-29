# Dockerfile that builds a minimal container for IPython + narrative
#
# Copyright 2013 The Regents of the University of California,
# Lawrence Berkeley National Laboratory
# United States Department of Energy
# The DOE Systems Biology Knowledgebase (KBase)
# Made available under the KBase Open Source License
#
FROM kbase/rtmin:1.2
MAINTAINER Shane Canon scanon@lbl.gov

#RUN DEBIAN_FRONTEND=noninteractive apt-get update;apt-get -y upgrade;apt-get install -y \
#	mercurial bzr gfortran subversion tcsh cvs mysql-client libgd2-dev tcl-dev tk-dev \
#	libtiff-dev libpng12-dev libpng-dev libjpeg-dev libgd2-xpm-dev libxml2-dev \
#	libwxgtk2.8-dev libdb5.1-dev libgsl0-dev libxslt1-dev libfreetype6-dev libreadline-dev \
#	libpango1.0-dev libx11-dev libxt-dev libcairo2-dev zlib1g-dev libgtk2.0-dev python-dev \
#	libmysqlclient-dev libmysqld-dev libssl-dev libpq-dev libexpat1-dev libzmq-dev libbz2-dev \
#	libncurses5-dev libcurl4-gnutls-dev uuid-dev git wget uuid-dev build-essential curl \
#	libsqlite3-dev libffi-dev
RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
         python-pip libcurl4-gnutls-dev python-dev ncurses-dev software-properties-common

RUN echo ''|add-apt-repository ppa:nginx/stable; apt-get update; apt-get install -y nginx nginx-extras

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
         lua5.1 luarocks liblua5.1-0 liblua5.1-0-dev liblua5.1-json liblua5.1-lpeg2 \
         nodejs-dev npm nodejs-legacy;\
         npm install -g grunt-cli

RUN luarocks install luasocket;\
    luarocks install luajson;\
    luarocks install penlight;\
    luarocks install lua-spore;\
    luarocks install luacrypto

#mysystem("usermod www-data -G docker");

ADD ./ /root/dt
WORKDIR /root/dt
ENV TARGET /kb/deployment
ENV PATH ${TARGET}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
 
RUN cp cluster.ini.docker cluster.ini && ./deploy_cluster mkhashfile tagfile && rm -f site.cfg && rm -rf ssl

RUN MYSERVICES=awe ./deploy_cluster -s deploy local tagfile

# Make things run in the foreground and spit out logs -- hacky
RUN \
        sed -i 's/--daemonize [^ ]*log//' /kb/deployment/services/Transform/start_service;\
        sed -i 's/--daemonize//' /kb/deployment/services/*/start_service;\
        sed -i 's/--error-log [^ "]*//' /kb/deployment/services/*/start_service;\
        sed -i 's/--pid [^ "]*//' /kb/deployment/services/*/start_service;\
        sed -i 's/\/kb\/runtime\/sbin\/daemonize .*\/kb/\/kb/' /kb/deployment/services/*/start_service;\
        sed -i 's/>.*//' /kb/deployment//services/*/start_service;\
        sed -i 's/nohup //' /kb/deployment//services/*/start_service;\
        sed -i 's/start_service &/start_service/' /root/dt/perl/KBDeploy.pm

# Add URI::Dispatch for Invocation (can delete this later)
#RUN wget http://search.cpan.org/CPAN/authors/id/M/MN/MNF/URI-Dispatch-v1.4.1.tar.gz;\
#    tar xzf URI-Dispatch-v1.4.1.tar.gz;\
#    cd URI-Dispatch-v1.4.1; \
#    /kb/runtime/bin/perl ./Makefile.PL ; \
#    make; \
#    make install; \
#    cd ..; \
#    rm -rf URI-Dispatch-v1.4.1; \
#    yes|/kb/runtime/bin/cpan install Modern::Perl; \
#    /kb/runtime/bin/cpan install Ouch; \
#    /kb/runtime/bin/cpan install MooseX::Declare

RUN \
        cd /kb/dev_container/modules;\
        git clone https://github.com/kbase/ui-common -b staging;\
        git clone https://github.com/scanon/narrative -b docker

ONBUILD ENV USER root

ONBUILD ADD cluster.ini /root/dt/cluster.ini
ONBUILD ADD ssl /root/dt/ssl
# This run command does several things including:
# - Changing the memory size for the workspace
# - Change memory for other glassfish services
# - Deploy the nginx config (setup_www)
# - Run postporcess for shock and awe
# - Clones special versions of ui-common and narrative
#       cd modules/auth_service;cat /root/dt/auth.fix |patch -p0;make deploy;\

ONBUILD RUN cp ./cluster.ini /kb/deployment/deployment.cfg;\
        cd /kb/dev_container/;. ./user-env.sh;\
        cd /root/dt; \
        sed -i 's/10000/256/' /kb/deployment/services/workspace/start_service && \
        sed -i 's/15000/384/' /kb/deployment/services/workspace/start_service && \
        sed -i 's/--Xms 1000 --Xmx 2000/--Xms 384 --Xmx 512/' /kb/deployment/services/*/start_service && \
        cd config;NOSTART=1 MYSERVICES=www ./setup_www;cd ../;\
        ./config/postprocess_shock;\
        ./config/postprocess_awe;\
        sed -i 's/ssl_verify = True/ssl_verify = False/' /kb/deployment/lib/biokbase/Transform/script_utils.py;\
        MYSERVICES=Transform ./config/postprocess_Transform;\
        [ -e /mnt/Shock/logs ] || mkdir -p /mnt/Shock/logs;

# We need to refix start
ONBUILD RUN sed -i 's/start_service &/start_service/' /root/dt/perl/KBDeploy.pm

ONBUILD ENTRYPOINT [ "./scripts/entrypoint.sh" ]
ONBUILD CMD [ ]
