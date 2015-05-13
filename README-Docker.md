Build images
- (Make sure kbase/rtmin is available. This is provide by a branch in the bootstrap repo.)
- docker build -t kbase/depl:1.0 . 
- docker build -t kbase/depl:1.0.1 -f Dockerfile.depl .

Start Base services

- docker run --name mongo -d mongo:2.4
- docker run --name mysql -e MYSQL_ROOT_PASSWORD=password -d mysql:5.5

Initialize

docker run --rm -it --link mysql:mysql --entrypoint perl --env MYSERVICES=mysql kbase/depl:1.0.1  ./config/setup_mysql 
docker run --rm -it --link mongo:mongo --entrypoint bash --env MYSERVICES=mongo kbase/depl:1.0.1  (run ./config/setup_mongo)

Compose Up

docker-compose up
