#!/bin/bash
#
# Only for use on a docker system with no images.
#
IMGS=($(docker images -q))
if (( ${#IMGS[@]} )) ; then
    echo "ERROR: requires an empty docker system to run!"
    exit 1
fi

# docker rmi -f $(docker images -q)
docker pull alpine:latest
docker pull hello-world
docker images
./docker-resize-img-mac.sh -s 60G -a

