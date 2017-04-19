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

cat >/home/stack/kolla_images.sh <<-EOF
#!/usr/bin/env python

import yaml

with open("/usr/share/tripleo-common/contrib/overcloud_containers.yaml",
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
  --base centos \
  --type binary \
  --namespace tripleoupstream \
  --registry 192.168.24.1:8787 \
  --tag latest \
  --push \
  --template-override /usr/share/openstack-tripleo-common/contrib/tripleo_kolla_template_overrides.j2  \
  $(~/kolla_images.sh)
cd
deactivate
