#!/bin/sh
set -e

echo "Preparing Packer environment..."
cd ${PACKER_ROOT}
if [ ! -f jenkinsrole.tar ] || [ ! -s jenkinsrole.tar ]; then
  echo "Creating jenkinsrole.tar..."
  cd ${PLAYBOOKS_ROOT}
  tar -cvf jenkinsrole.tar \
    jenkins-setup.yml \
    roles \
    ansible.cfg \
    requirements.yml 2>/dev/null || true
  mv jenkinsrole.tar ${PACKER_ROOT}/ || true
fi
cd ${TF_ROOT}



