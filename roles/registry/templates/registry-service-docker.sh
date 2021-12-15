#!/bin/bash
images="registry:latest"

containers="hub.images.com"

init() {
    docker load -i {{install_base}}/images/$images.tar.gz
}

stop() {
    docker stop ${containers}
}

clean() {
    docker rm -vf ${containers}
}

start() {
    docker run -d \
        --restart always \
        --name ${containers} \
        -p 5000:5000 \
        -v {{install_base}}/registry:/var/lib/registry \
        hub.images.com:5000/base/registry:latest
}

restart() {
    stop
    clean
    start
}

status() {
    docker ps -a -f name=${containers}
}

case $1 in
init | clean | start | stop | restart | status)
    $1
    ;;
*)
    echo "usage: $0 <init|clean|status|start|stop|restart>"
    ;;
esac
