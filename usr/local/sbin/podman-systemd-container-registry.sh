#! /bin/bash
#
# run this script as user contreg with uid 1314 !!!
#
# https://podman.io/blogs/2020/12/09/podman-systemd-demo.html
# create user:
#     useradd --uid 1314 --home-dir /var/lib/ocireg --comment "system account for oci container registry" ocireg
# remove user and all content:
#     killall -9 -u ocireg; userdel ocireg; rm -rf /var/lib/ocireg; rm -rf /run/user/1314
#
if [[ -z $1 ]]; then
  echo "pass the folder for the new registry as an argument"
  exit
fi

SVC="oci-registry"
USER1="ocireg"
REGFOLDER="$1/$(hostname -s)"

if [[ -z $(getent passwd ${USER1}) ]]; then
   echo "User ${USER1} does not exist. create a user:"
   echo "sudo useradd --uid 1314 --home-dir /var/lib/${USER1} --comment \"system account for container registry\" ${USER1}"
   exit
fi

if [[ -d ${REGFOLDER} ]]; then
  echo "Folder ${REGFOLDER} already exists." 
  echo "Please delete it and ensure the parent folder is owned by user ${USER1}"
  exit
fi
mkdir -p ${REGFOLDER}

if [[ "$(whoami)" != "${USER1}" ]]; then
  echo "You must run this script as user ${USER1} !"
  exit
fi

# create container | systemd fails to start with /var/lib/${USER1}:z
unset XDG_RUNTIME_DIR
podman create --name ${SVC} \
-p 5000:5000 --privileged \
-v ${REGFOLDER}:/var/lib/registry \
docker.io/library/registry:2

# systemd config
loginctl enable-linger ${USER1}
export XDG_RUNTIME_DIR=/run/user/$(id -u)
mkdir -p ~/.config/systemd/user
cd ~/.config/systemd/user
podman generate systemd ${SVC} --restart-policy=always -t 5 -f -n
systemctl enable --user container-${SVC}.service
systemctl start --user container-${SVC}.service
systemctl status --user container-${SVC}.service
