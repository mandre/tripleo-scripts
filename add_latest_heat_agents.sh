#!/bin/bash

set -e

# Accept Patch ID and target hostname indifferently
if [[ $1 =~ ^-?[0-9]+$ ]]; then
	PATCH_ID=$1
	TARGET_HOST=$2
else
	TARGET_HOST=$1
	PATCH_ID=$2
fi

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
	ssh -F /home/martin/.quickstart-${TARGET_HOST}/ssh.config.ansible undercloud "bin/$SCRIPT_NAME $PATCH_ID"
	exit 0
fi

# Below runs on $TARGET_HOST

cd $HOME
if [ ! -d heat-agents ]; then
	git clone https://github.com/openstack/heat-agents.git
fi

cd heat-agents

if [ "x$PATCH_ID" != "x" ]; then
	REF=$(curl -s -L https://review.openstack.org/changes/$PATCH_ID/revisions/current/review | sed 1d | jq -r '.revisions [].ref')
	git fetch https://git.openstack.org/openstack/heat-agents $REF && git checkout FETCH_HEAD
else
	git checkout master
	git pull origin master
fi

cd

sudo yum install -y libguestfs-tools
mkdir -p hooks
cp heat-agents/heat-config-docker-cmd/install.d/hook-docker-cmd.py hooks/docker-cmd
cp heat-agents/heat-config-json-file/install.d/hook-json-file.py hooks/json-file
virt-copy-in -a overcloud-full.qcow2 hooks /usr/libexec/heat-config/hooks

source stackrc
openstack overcloud image upload --update-existing
