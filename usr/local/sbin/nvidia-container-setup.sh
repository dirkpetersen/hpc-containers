#! /bin/bash

# based on:
# https://www.redhat.com/en/blog/how-use-gpus-containers-bare-metal-rhel-8
# https://github.com/NVIDIA/libnvidia-container
# https://nvidia.github.io/libnvidia-container/

MYGPU=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader --id=0 | sed -e 's/ /-/g')

if [[ -z ${MYGPU} ]]; then
  echo "No Nvidia GPU detected, make sure nvidia-smi is setup correctly"
  exit
fi

#DIST=$(. /etc/os-release;echo $ID$VERSION_ID)
DIST="rhel8.5"
curl -s -L https://nvidia.github.io/libnvidia-container/$DIST/libnvidia-container.repo | tee /etc/yum.repos.d/libnvidia-container.repo

dnf clean expire-cache --refresh

dnf install -y libnvidia-container1
dnf install -y libnvidia-container-tools
