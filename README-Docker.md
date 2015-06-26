# Deploying with docker

## Create self-signed certs or copy in certs to ./ssl

    ./scripts/create_certs

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

    ./scripts/setup_mysql
    ./scripts/setup_mongo

## Start services

Use Docker Compose to start things up.

    docker-compose up

## Start workers

Create environment file called .awenv.


    ADMIN_PASS=<password>
    ADMIN_USER=<Kbase/globus username>
    CGROUP=dev
    MYSERVICES=aweworker

Save this to .awenv and start a worker.

    docker run -it --rm --env-file=.awenv --link deploytools_awe_1:awe --link deploytools_www_1:www kbase/depl:1.0.1


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

