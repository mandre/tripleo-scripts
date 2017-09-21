#!/bin/bash

set -e

TARGET_HOST=$1
TRIPLEO_COMMON_PATH=/home/stack/tripleo-common

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

sudo yum install -y python-virtualenv gcc

cd

# Pull kolla if it isn't there already
if [ ! -d kolla ]; then
  git clone https://github.com/openstack/kolla.git
fi
cd kolla

if [ ! -d ~/kolla-venv ]; then
  virtualenv ~/kolla-venv
  source ~/kolla-venv/bin/activate
  pip install -U pip
  pip install -r requirements.txt
  pip install pyaml
else
  source ~/kolla-venv/bin/activate
fi

cat > /tmp/kolla-build.conf <<-EOF_CAT
[DEFAULT]
base=centos
type=binary
# Comma separated list of .rpm or .repo file(s) or URL(s) to install
# before building containers (list value)
#rpm_setup_config = http://buildlogs.centos.org/centos/7/cloud/x86_64/rdo-trunk-master-tested/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo
# rpm_setup_config = http://trunk.rdoproject.org/centos7/current/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo
rpm_setup_config = http://trunk.rdoproject.org/centos7/current-tripleo/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo
EOF_CAT

cat >/home/stack/kolla_images.sh <<-EOF
#!/usr/bin/env python

import yaml

with open("${TRIPLEO_COMMON_PATH}/container-images/overcloud_containers.yaml",
          'r') as overcloud_images:
    try:
        images = yaml.safe_load(overcloud_images)
        names = [i['imagename'][30:].split(':')[0] for i in images['container_images']]
        print(' '.join(names))
    except yaml.YAMLError as exc:
        print(exc)
EOF
chmod a+x /home/stack/kolla_images.sh

time ./tools/build.py \
  --config-file /tmp/kolla-build.conf \
  --base centos \
  --type binary \
  --namespace tripleoupstream \
  --registry 192.168.24.1:8787 \
  --tag latest \
  --push \
  --template-override ${TRIPLEO_COMMON_PATH}/container-images/tripleo_kolla_template_overrides.j2  \
  $(~/kolla_images.sh)
cd
deactivate
