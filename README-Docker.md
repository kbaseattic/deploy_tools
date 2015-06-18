# Deploying with docker

## Build images

Make sure kbase/rtmin is available. This is provide by a branch in the bootstrap repo.)

    docker build -t kbase/depl:1.0 .
    docker build -t kbase/depl:1.0.1 -f Dockerfile.depl .
    docker run -it --rm --hostname narrative -v /var/run/docker.sock:/var/run/docker.sock --entrypoint perl kbase/depl:1.0.1 ./config/postprocess_narrative

## Start Base services

Start Mongo and mysql

    docker run --name mongo -d mongo:2.4
    docker run --name mysql -e MYSQL_ROOT_PASSWORD=password -d mysql:5.5

## Initialize Databases

    docker run --rm -it --link mysql:mysql --entrypoint perl --env MYSERVICES=mysql kbase/depl:1.0.1  ./config/setup_mysql
    docker run --rm -it --link mongo:mongo --entrypoint bash --env MYSERVICES=mongo kbase/depl:1.0.1  (run ./config/setup_mongo)

## Start services

Use Docker Compose to start things up.

    docker-compose up

## Start workers

Create environment file.


    ADMIN_PASS=<password>
    ADMIN_USER=<Kbase/globus username>
    CGROUP=dev
    MYSERVICES=aweworker

Save this to .awenv and start a worker.

    docker run -it --rm --env-file=.awenv --link deploytools_awe_1:awe --link deploytools_www_1:www kbase/depl:1.0.1


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

Starting a client container:

    docker run -it --rm --user $(id -u) --name client --workdir $HOME --volume $HOME:$HOME --env HOME=$HOME --link deploytools_www_1:www --entrypoint bash kbase/depl:1.0.1
