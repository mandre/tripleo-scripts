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

mkdir -p $HOME/tripleo

cd $HOME/tripleo
if [ ! -d tripleo-ci ]; then
	git clone https://github.com/openstack-infra/tripleo-ci.git
fi

cd tripleo-ci
git checkout master
git pull origin master

cd

./tripleo/tripleo-ci/scripts/tripleo.sh --overcloud-pingtest
