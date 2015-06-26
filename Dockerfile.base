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

ADD ./ /root/dt
WORKDIR /root/dt
ENV TARGET /kb/deployment
ENV PATH ${TARGET}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV MYSERVICES=invocation
RUN ./config/bootstrap_narrative
RUN ./deploy_cluster -s deploy local tagfile
