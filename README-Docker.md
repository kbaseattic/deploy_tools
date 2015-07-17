# Deploying with docker

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

## Create a tag file for the versions.  This determines what version of services will be deployed.

    ./deploy_cluster mkhashfile tagfile


## Build images

Make sure kbase/rtmin is available. This is provide by a branch in the bootstrap repo.

    docker build -t kbase/deplbase:1.0 -f Dockerfile.base .
    docker build -t kbase/depl:1.0 .
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
    curl http://localhost:8080/services/shock-api
    curl http://localhost:8080/services/awe-api
    cd ..

## Start workers

Start a worker.

    ./scripts/start_aweworker

## Start Narrative Proxy Engine

    ./scripts/start_narrative

## Starting a client container:

There is a helper script to start a client container.  It will run as your user id using your home directory.

    ./scripts/client.sh

#Debugging Tips

Here are a couple of quick tricks for debugging

UJS

    docker exec deploytools_ujs_1 cat /kb/deployment/services/userandjobstate/glassfish_domain/UserAndJobState/logs/server.log

Workspace:

    docker exec deploytools_ws_1 cat /kb/deployment/services/workspace/glassfish_domain/Workspace/logs/server.log

Shock:

    docker exec deploytools_shock_1 ls /mnt/Shock/logs

Web Proxy:

    docker exec deploytools_www_1 cat /var/log/nginx/error.log^C

