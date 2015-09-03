# Deploying with docker

## Prerequisites

A functioning deployment currently requires around 40GB of disk space available and 8GB of memory in the Docker machine.

## Create a site config.

    cp site.cfg.example site.cfg
    edit site.cfg

## Run the bootstrap script to start things up

    ./scripts/bootstrap.sh

# Detailed steps

These steps are done by the bootstrap.  Advanced users may need to run some steps separately.

## Create self-signed certs or copy in certs to ./ssl.  Create the config from the docker template.

    ./scripts/generate_config
    ./scripts/create_certs

## Build images

Make sure kbase/rtmin is available. This is provide by a branch in the bootstrap repo.

    docker build -t kbase/deplbase:latest .
    docker build -t kbase/depl:1.0 -f Dockerfile.configure .
    ./scripts/build_narrative

## Start Base services

Start Mongo and mysql

    docker run --name mongo -d mongo:2.4
    docker run --name mysql -e MYSQL_ROOT_PASSWORD=password -d mysql:5.5

## Initialize Databases

    ./scripts/initialize.sh

## Start services

Clone kbrouter and use it to start things up

    git clone https://github.com/KBaseIncubator/kbrouter
    cd kbrouter
    cp ../cluster.ini cluster.ini
    docker-compose build
    docker-compose up -d
    curl http://<publichostname>:8080/services/shock-api
    curl http://<publichostname>:8080/services/awe-api
    cd ..

## Start workers

Start a worker.

    ./scripts/start_aweworker

## Start Narrative Proxy Engine

    ./scripts/start_narrative

## Starting a client container:

There is a helper script to start a client container.  It will run as your user id using your home directory.

    ./scripts/client.sh

# Developing Services with Containers (draft)

Create a Dockerfile similar to this...

    FROM kbase/deplbase:latest
    MAINTAINER Pat Smith psmith@mail.org

Build the image and tag it.  You should probably use a tag different from the default.

    docker build -t psmith/myservice:0.1

Modify the kbrouter config (cluster.ini) to include your service.

    # Your service name
    [myservice]
    #required: need to link to the front-end proxy
    service-port=7444
    # Not used in build, but helpful to include
    giturl=https://github.com/psmith/myservice
    host=myservice
    #optional: must match the directory name in /kb/deployment/services/
    #          needed if the directory name is different from the service name
    basedir=myservice
    #services specific paramaters
    myparamter=1.234
    #optional: Used to create the URL path to the service.
    #          Defaults to service name
    urlname=my_service
    #required: should match the tag you specified in the build above
    docker-image=psmith/myservice:0.1
    #optional: can be used to link to other containers, i.e. databases
    docker-links=mongo:mongo               
    #optional: can be used to mount persistent spaces
    docker-volumes=/data/docker/myservice:/mnt/myservice     

Restart the router

    cd kbrouter
    docker-compose restart router

Access your service via the public proxy and service URL

    curl -X POST -k https://public.hostname.org:8443/services/my_service

#Debugging Tips

Here are a couple of quick tricks for debugging

UJS

    docker exec deploytools_ujs_1 cat /kb/deployment/services/userandjobstate/glassfish_domain/UserAndJobState/logs/server.log

Workspace:

    docker exec deploytools_ws_1 cat /kb/deployment/services/workspace/glassfish_domain/Workspace/logs/server.log

Shock:

    docker exec deploytools_shock_1 ls /mnt/Shock/logs

Web Proxy:

    docker exec deploytools_www_1 cat /var/log/nginx/error.log
