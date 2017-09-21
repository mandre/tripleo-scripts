#!/bin/bash

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

cat > ~/.ssh/config <<EOF
Host *
User heat-admin
StrictHostkeyChecking no
UserKnownHostsFile /dev/null
EOF
chmod 600 ~/.ssh/config

LOCAL_IP=192.168.24.1

cat >/home/stack/custom.yaml <<-EOF
parameter_defaults:
  EC2MetadataIp: $LOCAL_IP
  ControlPlaneDefaultRoute: $LOCAL_IP
  DockerNamespace: $LOCAL_IP:8787/tripleoupstream
  DockerNamespaceIsRegistry: true
  MonitoringRabbitHost: 10.10.10.10
  MonitoringRabbitPort: 5672
  MonitoringRabbitUserName: sensu
  MonitoringRabbitPassword: sensu
  MonitoringRabbitUseSSL: false
  MonitoringRabbitVhost: "/sensu"
  SensuClientCustomConfig:
    api:
      warning: 10
      critical: 20
EOF

source stackrc
openstack stack delete --yes --wait overcloud
# mistral environment-delete overcloud
# swift delete overcloud
time openstack overcloud deploy \
  --templates /home/stack/tripleo-heat-templates/ \
  -e /home/stack/tripleo-heat-templates/environments/docker.yaml \
  -e /home/stack/tripleo-heat-templates/environments/network-isolation.yaml \
  -e /home/stack/tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
  -e /home/stack/network-environment.yaml \
  -e /home/stack/containers-default-parameters.yaml \
  --libvirt-type qemu
  # -e /home/stack/custom.yaml \
