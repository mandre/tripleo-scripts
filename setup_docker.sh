#!/bin/bash

set -e

TARGET_HOST=$1

if [ "x$TARGET_HOST" = "x" ]; then
	TARGET_HOST='gouda'
fi

if [ $HOSTNAME = chaource ]; then
	SCRIPT_NAME=$( basename "${BASH_SOURCE[0]}" )
	echo Copying $SCRIPT_NAME to $TARGET_HOST
	SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
	rsync -Pav -e "ssh -F /home/martin/.quickstart-${TARGET_HOST}/ssh.config.ansible" "$SCRIPT_PATH" undercloud:bin/ &> /dev/null
	echo Running $SCRIPT_NAME on $TARGET_HOST
	ssh -F /home/martin/.quickstart-${TARGET_HOST}/ssh.config.ansible undercloud "bin/$SCRIPT_NAME"
	exit 0
fi

# Below runs on $TARGET_HOST

sudo systemctl stop docker docker-storage-setup
sudo rm -rf /var/lib/docker/
sudo sed -i '/OPTIONS=/s/--selinux-enabled//' /etc/sysconfig/docker
echo "STORAGE_DRIVER=overlay" | sudo tee --append /etc/sysconfig/docker-storage-setup

if ! getent group docker >/dev/null; then
    sudo groupadd docker
    sudo gpasswd -a ${USER} docker
fi

sudo systemctl start docker-storage-setup docker
sudo chmod 0666 /run/docker.sock

# Finally, make new group effective
newgrp docker
