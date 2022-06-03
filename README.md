# Containers on HPC 

Why you should offer both Podman (Docker) and Apptainer (Singularity) and allow users to create containers in rootless mode with user namespaces on your HPC systems and how to implement this easily. If you have more questions about containers, check out [The Turing Way](https://the-turing-way.netlify.app/reproducible-research/renv/renv-containers.html), an excellent book about reproducible data science. 

## Why this article ?

As new HPC users kept asking for Docker in addition to the predominant Apptainer(Singularity) we looked at [Podman](https://podman.io/), a daemon-less Docker clone that looked promising for HPC systems in late 2021.
When attending Supercomputing 21 (SC21) in St.Louis and BioIT World 22 in Boston I learned that most sysadmins had not tried Podman yet. In early 2022 we implemented both Apptainer and Podman as a Docker replacement on a new midsize HPC system running RHEL8. Visiting the International Supercomputing Conference 22 (ISC22) in Hamburg, I learned that the large DOE supercomputing sites were also [in the process of adopting Podman](https://www.theregister.com/2022/06/01/redhat_doe_hpc/) in addition to Apptainer(Singularity) but had not gone into production yet. Most midsize HPC sites were not considering Podman and focused on Apptainer(Singularity). I am providing some background why I believe HPC sites should provide both technologies and am sharing the configuration we used when implementing our solution.

## A quick history of HPC containers 

After Docker was introduced nearly 15 years ago, it took only a few years to excite data scientists and data engineers about reproducible containerized pipelines. Well, these job titles did not even exist back then but the HPC community complained for many years that Docker really preferred  their users to be root, which was fine for developers but not for sysadmins. 
It took until 2015 for the HPC community to develop a daemon-less container technology called Singularity which met their security needs but also added a number of HPC specific bells and whistles. Others thought, well this is nice, but millions of users who don't care about HPC have already learned the Docker commands and wrote thousands of howtos and millions of code lines assuming Docker was there to stay. Some site-specific attempts like [Shifter at NERSC](https://docs.nersc.gov/development/shifter/how-to-use/) or [Charliecloud at LANL](https://discover.lanl.gov/news/cloud-technology) were made to bring Docker functionality to HPC users. 
Finally, in 2018 a team at Redhat decided that they still liked the docker interface but not the underbelly and went on to create [Podman](https://podman.io/), a plug-in replacement for Docker that did not require a daemon and could simply work with default Unix security. By this time much of the important core container tech had already been moved to a shared Linux specific container library allowing multiple container technologies to similarly interact with the Linux operating system and a standardized open container format ([OCI](https://github.com/opencontainers/image-spec)), largely based on Docker, had been developed. 
Since then Singularity has been renamed to Apptainer and [adopted by the Linux foundation](https://www.linuxfoundation.org/press-release/new-linux-foundation-project-accelerates-collaboration-on-container-systems-between-enterprise-and-high-performance-computing-environments/) while Podman has reached version 4 in 2022 and has also been added to a [recent Ubuntu LTS release](https://www.techrepublic.com/article/install-podman-ubuntu/). So today we have 2 powerful container technologies that can be used on HPC systems. Does this sound like Coke vs Pepsi, PC vs Mac or Vi vs Emacs?

## Why do we need multiple container technologies ?

Many HPC centers have told their users to switch to Apptainer(Singularity) in recent years. However, HPC centers should not just see themselves as providers of fancy technology and clear guidance but also focus on supporting a diverse user population that ranges from lab scientists who just learned SSH logins yesterday to senior particle physicists who have written computer science papers on the intricacies of combining MPI with openMP. 
Another dimension of this diversity is seniority. The more senior a scientist is in their field the more experimental the nature of their work will be. They may want to delegate the build of a stable and reproducible pipeline to a more junior scientist or to a research software engineer but focus on ad-hoc trying of immature pieces of code in interactive HPC sessions and testing of many different libraries and even more different versions of these. This is the reason why HPC sysadmins provide a plethora of software from legacy libraries to very beta applications through environment modules systems such as Lmod. These applications are typically not offered as containers which does not encourage container usage. HPC documentation focuses on running containers made at other sites but not building containers. Essentially scientists are left to build their own containers and they will need to use the tool that they find most productive to do so.
Another aspect is collaboration. Most scientists are only using HPC systems for part of their work. They collaborate with scientists in other parts of the world that may not even have an HPC system available. OCI containers are a safe way to transport information as all container technologies support reading OCI container images but not all of them support writing them. HPC centers need to be aware that scientists work with a much larger technology ecosystem than their local infrastructure. 

### Why we need Docker (or Podman)?

Even though HPC systems are all very similar (a bunch of mostly RHEL based Linux servers glued together by Slurm, a shared Posix file system and a fast network) it is amazing how long it still takes to onboard new users into productivity even if they gained HPC experience at a previous site. With more Gen Z users we see less tolerance for things that do not work out of the box ("You are right, Gen Z") and more frequent job changes which has been further accelerated by the covid19 pandemic. In the current workplace of permanent on and off-boarding, experienced HPC users should not have to read: `docker: command not found`. Instead they should be productive with their favorite toolset as fast as possible. Sadly Apptainer(Singularity) does not support writing OCI container images and scientists will need to use Docker or Podman to share code with all possible collaborators.

### Why we need Apptainer (Singularity)

Apptainer is a breeze to work with because your home directory, where you may have your data and code, is naturally part of the execution path: `apptainer mycontainer.sif python3 ~/myscript.py` works magically even though myscript.py is not inside the container but a file in a shared filesystem. So tens of thousands of HPC users have adopted it and would be quite befuddled if one day they had to read `singularity: command not found`. Also we have seen lots and lots of performance optimizations for Apptainer(Singularity), including GPU computing, after the HPC community has adopted it years ago. The sif container format used by Apptainer helps with reproducibility by supporting cryptographic signatures and an immutable container image format. Apptainer will be the best supported hpc container technology for years to come. 

### but we don't want to confuse our users 

"But shouldn't we recommend best practices to our users instead of throwing multiple container technologies at them?" Yes, we should indeed give recommendations. We should compare the technologies we offer and document as well as explain the pros and cons of each technology. And we should define a default, for example in a quick start document we should tell our users which technology we recommend for which use case and which workflow has been successful for most users. Several sites such have come to the conclusion that in 2022 Podman is best for creating containers and Apptainer is best for running containers on HPC systems.
And in some cases one should NOT provide multiple technologies, for example if the functionality is almost identical. One example is Gitlab vs Github in life sciences. Github is cited about [11000 times](https://pubmed.ncbi.nlm.nih.gov/?term=github) while Gitlab about [200 times](https://pubmed.ncbi.nlm.nih.gov/?term=gitlab) which is an almost 60x difference. This should trigger HPC leaders (at least the ones in life sciences) to avoid Gitlab at (almost) all cost and instead use and document Github wherever possible as Github has become an extension or even a replacement for Facebook/Linked-in for data scientists. Your users will be a lot less confused and perhaps even thank you !  

### creating containers is harder than running them. 

Most HPC centers only offer `runtime` support for existing containers but do not allow the creation of new containers on their systems. Users either want to execute something like docker-compose to create containers predefined in a configuration called `docker-compose.yml`. But more often than not data scientists just want to create a container by just running a few `apt install mumble-jumble` commands just as they are used to on their Ubuntu desktop or VM. Currently they have to build their containers on their desktop or a dedicated machine and then copy them over to the HPC system. While this is not too hard, this process becomes annoying when containers need to be re-created too often. 

## Configuration of rootless Containers

Here we will discuss the implementation of rootless containers enabled by Linux user name spaces (available since Kernel 3.8) and how to interact with a local docker registry. This enables users to create and manage containers directly on an HPC login node without friction.   

### user namespaces with /etc/subuid and /etc/subgid

user namespaces are required for unprivileged users who would like to create or modify containers for which must "be root" inside a container.
As an unprivileged user per definition cannot be root or have sudo on the host (outside the container), user namespaces simply map uid 0 (root) inside the container to a higher uid on the host (e.g. the compute or login node) using the config files /etc/subuid and /etc/subgid. They also add an allotted range of 65536 UIDs to the container which is required by any Unix system to function properly.
For example, if we have 2 users with uid 1001 and 1002 on the host we could simply multiply these IDs with 100000 to provide a clean namespace with more than 65536 UIDs and /etc/subuid could look like this:

```
1001:100100000:65536
1002:100200000:65536
```

Inside the container we have a full uid range of 0-65535 and uid 0 inside is mapped to uid 100100000 outside the container on the host. The host sees that user 1001's containers have an assinged uid range of 100100000 to 100165535 and user 1002 has 100200000 to 100265535 to play with, which is conveniently not overlapping.

See [this article for more details]( 
https://opensource.com/article/19/2/how-does-rootless-podman-work)

Many sites however have 5 digit UIDs and if we multiply 50000 with 100000 we have a problem because the resulting number of 5 billion is larger than the 32 bit namespace (4.2 billion) supported by Linux. Fortunately, a simple solution is to multiply the uid with only 10000 instead of 100000. Even though we only assign less than 1/6 of the full uid range this will still work as we need to provide 65536 UIDs only *inside* the container but a tiny fraction of those will actually be used on the host.    

The script [/etc/cron.hourly/hpc-user-namespaces](etc/cron.hourly/hpc-user-namespaces) creates and maintains /etc/subuid and /etc/subgid
by multiplying each users' uid with 10000. We run it as an hourly cron job to reduce confusion during new user onboarding. It executes `getent passwd` to query for UIDs which requires enumeration to be enabled in sssd.conf if you use a configuration with ActiveDirectory. 

Another approach is to [pre-create subuid/subgid for all possible uids](https://rootlesscontaine.rs/getting-started/common/subuid/), however we have not tested this approach as the list is quite long

#### enable enumeration in SSSD

When using SSSD to integrate with ActiveDirectory or another LDAP service you need to set enumerate=true in section [domain/<domainname>] of your /etc/sssd/sssd.conf. Note that the SSSD documentation warns you against activating enumeration as it can degrade performance. We asked our ActiveDirectory team to monitor impact on the domain controllers and they did not see any performance degragation. This test was run on 70 nodes with 500 users.
To protect against potential future performance degragation we chose to add 2 more features: 

* a random delay of up to 5 min in the [hpc-user-namespaces](etc/cron.hourly/hpc-user-namespaces) script which causes each node to execute this script at a slightly different time 

* [/etc/cron.daily/hpc-config-shuffler](etc/cron.daily/hpc-config-shuffler) changes the order of a list of ldap servers to prevent that all nodes contact the same ldap server first. Because mocking with sssd.conf is kind of scary it will only edit config files changed in the last 24 hours. If you use tools such as Puppet/Chef/Ansible/Salt you may find more elegant ways to implement such a shuffle. 

This setup will probably scale to more than 10000 users. If you are still concerned about too many servers executing this script you could simply execute this script on your login nodes and then copy /etc/subuid and /etc/subgid to your compute nodes using a cron job or [Puppet](https://forge.puppet.com/modules/southalc/podman)/Chef/[Ansible](https://eengstrom.github.io/musings/generate-non-contiguous-subuid-subgid-maps-for-rootless-podman)/Salt. 

While managing user namespaces is kind of manual at this time adding this feature to openldap / SSSD is in the works 

### Installing container packages

We are installing Podman, Apptainer on RHEL8/Rocky8, for RHEL7/CentOS7 see advanced install instructions. 

install Podman and a docker command as a alias for podman. Optionally you can install docker-compose which works with podman. See [advanced install instructions for other OS](https://podman.io/getting-started/installation)


```
dnf install -y podman podman-docker
touch /etc/containers/nodocker
curl -L $(curl -L -s https://api.github.com/repos/docker/compose/releases/latest | grep -o -E "https://(.*)docker-compose-linux-x86_64" | uniq) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

install Apptainer or see [advanced install instructions for other OS](https://apptainer.org/docs/admin/main/installation.html#install-from-source)

```
rpm -ivh $(curl -L -s https://api.github.com/repos/apptainer/apptainer/releases/latest | grep -o -E "https://(.*)apptainer-(.*).x86_64.rpm" | grep -v debuginfo)
```

install the nvidia libraries (there is also a [script](usr/local/sbin/nvidia-container-setup.sh) for that)

```
DIST="rhel8.5"
curl -L -s https://nvidia.github.io/libnvidia-container/${DIST}/libnvidia-container.repo | tee /etc/yum.repos.d/libnvidia-container.repo

dnf clean expire-cache --refresh

dnf install -y libnvidia-container1
dnf install -y libnvidia-container-tools
```

and some other required tools, for example for the `hpc-docker-upload` script we will discuss below

```
dnf install -y git curl jq
```

### Configuring Podman 

For unprivileged users podman will store containers in their home directory by default. This will fail on most HPC systems as user home directories are on networked storage systems (NFS, Lustre, etc) for which extended attribute support required by rootless podman is not yet supported in Linux Kernels < 5.9. (Backporting on RHEL kernels is currently work in progress). Our current workaround is to change `rootless_storage_path` from the default network mounted home directory to a location on the local disk of the login node. Execute this `sed` command after replacing /loc/tmpcontainer with your preferred local folder

```
sed -i '/^# rootless_storage_path =.*/a rootless_storage_path = "\/loc\/tmpcontainer\/\${USER}\/share\/containers\/storage"' /etc/containers/storage.conf
mkdir -p /loc/tmpcontainer && chmod 777 /loc/tmpcontainer
```

if you have not installed the podman-docker package above, you can also setup a global alias to ensure to that all users can simply continue to use docker commands.

```
echo "alias docker=podman" >> /etc/profile.d/zzz-hpc-users.sh
```

### setup a docker registry on networked storage.

After users create their containers on local disk they want to continue to use them on all nodes of the cluster but also store it longer term as you will eventually have to clean out the local disk on the login node. There are public ones such as quay.io or biocontainers.org, fancy private ones such as https://goharbor.io/ or just [one with simple authentication using Podman](https://www.redhat.com/sysadmin/simple-container-registry)

However, the easiest option that does not require authentication is to create a docker registry on a private/secured login node and to access it via localhost without authentication:  

### dedicated login node with docker registry  

Many HPC centers offer a condo model where investigators can purchase their own compute nodes which are then managed by the HPC team. If they want to purchase only a couple of nodes there is limited value in offering these resources to a larger community when the owners are not using them. 
The investigator may prefer to purchase a large memory login node with many CPUs and a GPU instead. Such a machine could be used as a beefy development or interactive compute machine with direct access to the cluster and to storage. This login node could have several features turning it into an advanced application server:

* a high performance docker registry listening on localhost that can be quickly accessed by the entire research group without the need to manage credentials  

* allow using podman containers as systemd services enabling users to run powerful web services with access to high performance storage

* sudo access to the "dnf install" command to allow user to self install new standard packages (or install packages for them on request)

* install Github runners that can execute Github based pipelines 

* allow users access to a service account they could use to install web services, etc  

* SMB3 gateway allowing easy access to Lustre storage from Mac and Windows machines 

In this document we will focus on building an easy to use local high performance docker registry. 

#### Creating a Registry on localhost

first you need to use or create a service account to run our OCI container registry for which you should set and document a specific UID. 

```
useradd --uid 1314 --home-dir /var/lib/ocireg --comment "system account for oci container registry" ocireg
```

Then you execute the following steps:

* copy [hpc-users.conf](etc/containers/registries.conf.d/hpc-users.conf) to /etc/containers/registries.conf.d/

* switch to user ocireg `su - ocireg`

* run this command: `echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> ~/.profile`

* execute the script [podman-systemd-container-registry.sh](usr/local/sbin/podman-systemd-container-registry.sh) with a folder in a network share as the only argument (see instructions for creating an nfs share at the end of this article). The ocireg user must have write access to this folder 

```
> podman-systemd-container-registry.sh /mnt/nfs-share/oci-registry
```

once the script is finished you should see something like this : 

```
● container-oci-registry.service - Podman container-oci-registry.service
   Loaded: loaded (/var/lib/ocireg/.config/systemd/user/container-oci-registry.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2022-06-02 23:26:23 UTC; 12ms ago
```

#### testing the registry

now let's pull a python container and add the notorious pandas package to it: 

```
  user@host ~]$ docker run -ti docker://python /bin/bash
  Trying to pull docker.io/library/python:latest...

  root@1fe156b4cbfc:/# pip3 install pandas
  Collecting pandas
    Downloading pandas-1.3.4-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86
```

Next we will use the script [hpc-docker-upload](usr/local/bin/hpc-docker-upload). You can invoke the script with a name for a new image that you would like your last used container to convert to, for example

```
> hpc-docker-upload python-pandas
```

`hpc-docker-upload` executes 4 docker commands for you and really simplifies modifying a container and storing an image to a few simple steps 

```
executed these commands for you:

  docker commit --author JimmyJoe Doe c23e9126eda2 jjd/python-pandas
  docker tag jjd/python-pandas localhost:5000/jjd/python-pandas
  docker push localhost:5000/jjd/python-pandas
  docker image rm localhost/jjd/python-pandas

  Your image has been uploaded to localhost:5000 and permanent storage.

  The container c23e9126eda2 and its image will be deleted from this machine in 7 days

  To run docker image python-pandas please execute the first command
  below on this login node and the second one inside a Slurm batch script on any node.

apptainer pull docker://localhost:5000/dp/python-pandas
apptainer exec /mnt/share/home/dp/python-pandas_latest.sif [command] [script-or-datafile]
```
You can now pull the image and run a container with `apptainer` or just use the docker commands :

```
apptainer exec ~/python-pandas_latest.sif python3 -c 'import pandas; print(pandas.__version__)'
1.4.2
```

### Summary 

With this setup we have achieved multiple benefits:

* Docker users can work with their familiar commands to create containers directly on HPC systems
* On login nodes containers can be created very rapidly which lowers the barriers for users who would otherwise not be inclined to use containers 
* By storing OCI container images instead of apptainer sif images we can share our images with a much larger audience and use them in the cloud as well 
* Using Apptainer may be the best option for running containers as they have some additional features suited for HPC systems and HPC teams have already years of experience with managing and troubleshooting Apptainer

**If you find inaccuracies or have suggestions for improvements please send me a pull request.** 

## Appendix

### setting up a test nfs home directory

Use these instructions to setup a test environment NFS mounted home directry for `testuser` on the local machine 

```
dnf install -y nfs-utils
mkdir /loc/nfs-share/home -p
mkdir /mnt/nfs-share
echo "/loc/nfs-share localhost(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
firewall-cmd --add-service={nfs,nfs3,mountd,rpc-bind} --permanent
systemctl enable --now nfs-server rpcbind
systemctl status nfs-server
mount -t nfs localhost:/loc/nfs-share /mnt/nfs-share
setenforce 0
useradd --home-dir /mnt/nfs-share/home/testuser testuser
```

### additional links / resources 

* Podman 4 can read Apptainer sif format: https://www.redhat.com/es/blog/expanding-podman-capabilities-deploy-sif-formatted-containers

* podman-compose puts all containers in the same pod with a common network unlike docker-compose: https://fedoramagazine.org/manage-containers-with-podman-compose/

* Docker can also run rootless now: 
https://thenewstack.io/how-to-run-docker-in-rootless-mode/

* User Xattr support for NFS in Kernel 5.9 
https://kernelnewbies.org/Linux_5.9