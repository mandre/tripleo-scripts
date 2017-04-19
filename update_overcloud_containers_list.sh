#!/bin/bash

DOCKER_DIR=/home/martin/dev/openstack/tripleo-heat-templates/docker

CONTAINER_IMAGES=$(grep -R -o -h "centos-binary-[^'\"]*" $DOCKER_DIR | sort -u)

echo "container_images:"
for image in $CONTAINER_IMAGES; do
	echo "- imagename: tripleoupstream/$image"
done
