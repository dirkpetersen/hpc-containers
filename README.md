# Containers on HPC 

Why you should offer both Podman (Docker) and Apptainer (Singularity) and allow users to create containers in rootless mode with user namespaces on your HPC systems. You can also jump to the [config howto directly](#configuration-of-rootless-containers). 
If you have more questions about containers in general, check out [The Turing Way](https://the-turing-way.netlify.app/reproducible-research/renv/renv-containers.html), an excellent book about reproducible data science. 

  - [Why this article ?](#why-this-article-)
  - [A quick history of HPC containers](#a-quick-history-of-hpc-containers)
  - [Why do we need multiple container technologies ?](#why-do-we-need-multiple-container-technologies-)
    - [Why we need Docker (or Podman)?](#why-we-need-docker-or-podman)
    - [Why we need Apptainer (Singularity)](#why-we-need-apptainer-singularity)
    - [But we don't want to confuse our users](#but-we-dont-want-to-confuse-our-users)
    - [Creating containers is harder than running them](#creating-containers-is-harder-than-running-them)
    - [Interoperability](#interoperability)
  - [Configuration of rootless Containers](#configuration-of-rootless-containers)
    - [User namespaces with /etc/subuid and /etc/subgid](#user-namespaces-with-etcsubuid-and-etcsubgid)
      - [Enable enumeration in SSSD](#enable-enumeration-in-sssd)
    - [Installing container packages](#installing-container-packages)
    - [Configuring Podman](#configuring-podman)
    - [Setup a docker registry on networked storage](#setup-a-docker-registry-on-networked-storage)
    - [Dedicated login node with docker registry](#dedicated-login-node-with-docker-registry)
      - [Creating a Registry on localhost](#creating-a-registry-on-localhost)
      - [Testing the registry](#testing-the-registry)
  - [Summary](#summary)
  - [Appendix](#appendix)
    - [Setting up a test nfs home directory](#setting-up-a-test-nfs-home-directory)
    - [Additional links / resources](#additional-links--resources)
      - [Generic](#generic)
      - [Podman](#podman)
      - [Apptainer / Singularity](#apptainer--singularity)
      - [Docker](#docker)

## Why this article ?

As new HPC users kept asking for Docker in addition to the predominant Apptainer(Singularity) we looked at [Podman](https://podman.io/), a daemon-less Docker clone that looked promising for HPC systems in late 2021.
When attending Supercomputing 21 (SC21) in St.Louis and BioIT World 22 in Boston I learned that most sysadmins had not tried Podman yet. In early 2022 we implemented both Apptainer and Podman as a Docker replacement on a new midsize HPC system running RHEL8. Visiting the International Supercomputing Conference 22 (ISC22) in Hamburg, I learned that many of the large DOE supercomputing sites were also [in the process of adopting Podman](https://www.hpcwire.com/off-the-wire/red-hat-joins-forces-with-doe-laboratories/) in addition to Apptainer(Singularity) but had not gone into production yet. Most midsize HPC sites were not considering Podman and focused on Apptainer(Singularity). I am providing some background why I believe midsize HPC sites should provide both technologies and am sharing the configuration we used when implementing our solution.

## A quick history of HPC containers 

After Docker was introduced nearly 15 years ago, it took only a few years to excite data scientists and data engineers about reproducible containerized pipelines. Well, these job titles did not even exist back then but the HPC community complained for many years that Docker really preferred  their users to be root, which was fine for developers but not for sysadmins. 
It took until 2015 for the HPC community to develop a daemon-less container technology called Singularity which met their security needs but also added a number of HPC specific bells and whistles. Others thought, well this is nice, but millions of users who don't care about HPC have already learned the Docker commands and wrote thousands of howtos and millions of code lines assuming Docker was there to stay. Some site-specific attempts like [Shifter at NERSC](https://docs.nersc.gov/development/shifter/how-to-use/) or [Charliecloud at LANL](https://discover.lanl.gov/news/cloud-technology) were made to bring Docker functionality to HPC users. 
Finally, in 2018 a team at Redhat decided that they still liked the docker interface but not the underbelly and went on to create [Podman](https://podman.io/), a plug-in replacement for Docker that did not require a daemon and could simply work with default Unix security. By this time much of the important core container tech had already been moved to a shared Linux specific container library allowing multiple container technologies to similarly interact with the Linux kernel and a standardized open container format ([OCI](https://github.com/opencontainers/image-spec)), largely based on Docker, had been developed. 
Since then Singularity has been renamed to Apptainer and [adopted by the Linux foundation](https://www.linuxfoundation.org/press-release/new-linux-foundation-project-accelerates-collaboration-on-container-systems-between-enterprise-and-high-performance-computing-environments/) while Podman has reached version 4 in 2022 and has also been added to a [recent Ubuntu LTS release](https://www.techrepublic.com/article/install-podman-ubuntu/). So today we have 2 powerful container technologies that can be used on HPC systems. Does this sound like Coke vs Pepsi, PC vs Mac or Vi vs Emacs?

## Why do we need multiple container technologies ?

Many mid-size HPC centers have told their users to switch from Docker based containers to Apptainer(Singularity) in recent years. However, HPC centers should not just see themselves as providers of fancy technology and clear guidance but also focus on supporting a diverse user population that ranges from lab scientists who just learned SSH logins yesterday to senior particle physicists who have written computer science papers on the intricacies of combining MPI with openMP. 

Another dimension of this diversity is seniority. The more senior a scientist is in their field the more experimental the nature of their work will be. They may want to delegate the build of a stable and reproducible pipeline to a more junior scientist or to a research software engineer and focus on trying immature pieces of code in interactive HPC sessions and ad-hoc testing of many different libraries and even more different versions of these. 

This is the reason why HPC sysadmins provide a plethora of software from legacy libraries to very beta applications through environment modules systems such as Lmod. These applications are typically not offered as containers which does not encourage container usage. HPC documentation focuses on running containers made at other sites but rarely on building containers. Essentially scientists are left to build their own containers and they will need to use the tool that they find most productive to do so.

Another aspect is collaboration. Most scientists are only using HPC systems for part of their work. They collaborate with scientists in other parts of the world that may not even have an HPC system available. OCI containers are a safe way to transport information as all container technologies support reading OCI container images but not all of them support writing them. Particularly enterprise centric midsize HPC centers need to be aware that scientists work with a much larger technology ecosystem than their local infrastructure. 

### Why we need Docker (or Podman)

Even though HPC systems are all very similar (a bunch of mostly RHEL based Linux servers glued together by Slurm, a shared Posix file system and a fast network) it is amazing how long it still takes to onboard new users into productivity even if they gained HPC experience at a previous site. With more Gen Z users we see less tolerance for things that do not work out of the box ("You are right, Gen Z") and more frequent job changes which has been further accelerated by the covid19 pandemic. In the current workplace of permanent on and off-boarding, experienced HPC users should not have to read: `docker: command not found`. Instead they should be productive with their favorite toolset as fast as possible. Sadly Apptainer(Singularity) does not support writing OCI container images and scientists will need to use Docker or Podman to share code with all possible collaborators or if they want to migrate their jobs to cloud computing engines such as AWS batch. 

### Why we need Apptainer (Singularity)

Apptainer is a breeze to work with because your home directory, where you may have your data and code, is naturally part of the execution path: `apptainer mycontainer.sif python3 ~/myscript.py` works magically even though myscript.py is not inside the container but a file in a shared filesystem. So tens of thousands of HPC users have adopted it and would be quite befuddled if one day they had to read `singularity: command not found`. Also we have seen lots and lots of performance optimizations for Apptainer, including GPU computing, after the HPC community has adopted it years ago. The sif container format used by Apptainer helps with reproducibility by supporting cryptographic signatures and an immutable container image format. Apptainer will be the best hpc container technology with the largest momentum for years to come.

### But we don't want to confuse our users 

"But shouldn't we recommend best practices to our users instead of throwing multiple container technologies at them?" Yes, we should indeed give recommendations. We should compare the technologies we offer and document as well as explain the pros and cons of each of them. And we should define a default, for example a quick start document should advise our users which technology we recommend for which use case and which workflow has been successful for most users. Several sites [such as ORNL](https://docs.olcf.ornl.gov/software/containers_on_summit.html) have come to the conclusion that in 2022 Podman is best for creating containers and Apptainer is best for running containers on HPC systems.

However, in some cases one should NOT provide multiple technologies, for example if the functionality of two products is almost identical. One popular example is Gitlab vs Github in life sciences. Github is cited about [11000 times](https://pubmed.ncbi.nlm.nih.gov/?term=github) in publications while Gitlab only about [200 times](https://pubmed.ncbi.nlm.nih.gov/?term=gitlab) which is an almost 60x difference. This should trigger HPC leaders (at least the ones in life sciences) to avoid Gitlab and instead use and document Github wherever possible as Github has become a replacement even for Facebook or LinkedIn for some data scientists. Your users will be a lot less confused and perhaps even thank you if you make Github your default code management tool. As container tools and source code management are connected ,for example when using MLops pipelines you would only have to document 2 workflows instead of 4 (Podman+GitHub, Apptainer+Github, Podman+Gitlab, Apptainer+Gitlab). The Turing Way [seems to agree on Github](https://the-turing-way.netlify.app/collaboration/github-novice.html). Of course, if one does not care about code sharing with others, one could put whatever code management platform in a local data center and hook it up to their enterprise directory but to many this may seem as if Meta would suddenly offer an on-prem version of Facebook.

### Creating containers is harder than running them

Most HPC centers only offer `runtime` support for existing containers but do not allow the creation of new containers on their systems. Users either want to execute something like docker-compose to create containers predefined in a configuration called `docker-compose.yml`. But more often than not data scientists just want to create a container by just running a few `apt install mumble-jumble` commands just as they are used to on their Ubuntu desktop or VM. Currently they have to build their containers on their desktop or a dedicated machine and then copy them over to the HPC system. While this is not too hard, this process becomes annoying when containers need to be re-created too often. 

### Interoperability 

There are some tools such as [Skopeo](https://github.com/containers/skopeo) (>= V. 1.6) that can convert SIF to OCI, however the result is not guaranteed to run on OCI container engines as Apptainer(Singularity) handles environment variables, container startup, default namespace isolation etc. very differently than Podman and other. A direct conversion of a non-trivial Apptainer(Singularity) image is quite likely not to run as expected under an OCI engine. Podman 4 is now able to read SIF images, however it remains to be seen if this can be done reliably even with esoteric configurations. This will be too complex to handle for most end users. Just as mentioned above, the best approach to ensure global reproducibility continues to be generating an OCI container image using Podman and then share it with the world. 

## Configuration of rootless Containers

Here we will discuss the implementation of rootless containers enabled by Linux user name spaces (available since Kernel 3.8) and how to interact with a local docker registry. This enables users to create and manage containers directly on an HPC login node without friction. If would like to dig deeper, "rootless" may be a misnomer as there are different levels of unprivileged containers and if you are into testing nuclear weapons or other serious business you want to be sure to understand the distinction [explained in this paper](https://dl.acm.org/doi/pdf/10.1145/3458817.3476187).

### User namespaces with /etc/subuid and /etc/subgid

user namespaces are required for unprivileged users who would like to create or modify containers for which they must "be root" inside a container.
As an unprivileged user per definition cannot "be root" or have sudo access on the host (outside the container), user namespaces simply map uid 0 (root) inside the container to a higher uid on the host (e.g. the compute or login node) using the config files /etc/subuid and /etc/subgid. They also add an allotted range of 65536 UIDs to the container which is required by any Unix system to function properly.
For example, if we have 2 users with uid 1001 and 1002 on the host we could simply multiply these IDs with 100000 and add 1 to provide a clean namespace with more than 65536 UIDs and /etc/subuid could look like this:

```
1001:100100001:65536
1002:100200001:65536
```

Inside the container we have a full uid range of 0-65535 and uid 0 inside is mapped to the actual user's uid 1001 outside the container on the host, uid 1 is mapped to 100100001 and uid 2 to 100100002.  The host sees that user 1001's containers have an assigned uid range of 100100001 to 100165536 and user 1002 has 100200001 to 100265536 to play with, which is conveniently not overlapping. However, this approach scales only to uid/gid < 42000.

See [this article for more details]( 
https://opensource.com/article/19/2/how-does-rootless-podman-work)

Many sites however have 5 digit UIDs and if we multiply 50000 with 100000 we have a problem because the resulting number of 5 billion is larger than the 32 bit namespace (4.2 billion) supported by Linux. Fortunately, a simple solution is to multiply the uid with only 10000 instead of 100000. Even though we only assign less than 1/6 of the full uid range this will still work as we need to provide 65536 UIDs only *inside* the container but a tiny fraction of those will actually be used on the host, in most cases this will be only root and nobody as rootless. 

The script [/etc/cron.hourly/hpc-user-namespaces](etc/cron.hourly/hpc-user-namespaces) creates and maintains /etc/subuid and /etc/subgid by multiplying each users' uid and gid with 10000. We run it as an hourly cron job to reduce confusion during new user onboarding. It executes `getent passwd` to query for UIDs which requires enumeration to be enabled in sssd.conf if you use a configuration with ActiveDirectory.

Another approach is to [pre-create subuid/subgid for all possible uids](https://rootlesscontaine.rs/getting-started/common/subuid/), however we have not tested this approach as the list is quite long but a variation of this approach would be to take a similar logic by assigning a fixed slot of 65536 for each possible uid >=1000 but only write subuid/gid for users users who exist on the system. This scales up to uid/gid 62000 in our example and is explained in line 51 of the `hpc-user-namespaces` script.

If you don't care if subuid and subgid are identical on each node you could have apptainer or another tool generate the next available range for each new user. With different caching states of ldap/AD servers the list of users may not be presented identically on each node as scripts are executed at different times (see below). You can activate the apptainer option by uncommenting lines 83-85 and commenting lines 71-80 in `hpc-user-namespaces`.

Note that you can either use the format uid:start-range:uid-count or username:start-range:uid-count. If you pre-create subuid/subgid you must use the former option as usernames will not scale.

Apptainer 1.1 is expected to no longer require a setup of subuid/subgid, we have not heard the same from Podman yet.

#### Enable enumeration in SSSD

When using SSSD to integrate with ActiveDirectory or another LDAP service you need to set enumerate=true in section [domain/domainname] of your /etc/sssd/sssd.conf. Note that the SSSD documentation warns you against activating enumeration as it can degrade performance. We asked our ActiveDirectory team to monitor impact on the domain controllers and they did not see any performance degradation. This test was run on 70 nodes with 500 users.
To protect against potential future performance degradation we chose to add 2 more features: 

* a random delay of up to 5 min in the [hpc-user-namespaces](etc/cron.hourly/hpc-user-namespaces) script which causes each node to execute this script at a slightly different time 

* [/etc/cron.daily/hpc-config-shuffler](etc/cron.daily/hpc-config-shuffler) changes the order of a list of ldap servers to prevent that all nodes contact the same ldap server first. Because mocking with sssd.conf is kind of scary it will only edit config files changed in the last 24 hours. If you use tools such as Puppet/Chef/Ansible/Salt you may find more elegant ways to implement such a shuffle. 

This setup will probably scale to more than 10000 users. If you are still concerned about too many servers executing this script you could simply execute this script on your login nodes and then copy /etc/subuid and /etc/subgid to your compute nodes using a cron job or [Puppet](https://forge.puppet.com/modules/southalc/podman)/Chef/[Ansible](https://eengstrom.github.io/musings/generate-non-contiguous-subuid-subgid-maps-for-rootless-podman)/Salt. 

While managing user namespaces is kind of manual at this time adding this feature to openldap / SSSD is in the works 

### Installing container packages

We are installing Podman, Apptainer on RHEL8/Rocky8, for RHEL7/CentOS7 see the advanced install instructions linked below.

install Podman and a docker command as a alias for podman. Optionally you can install docker-compose which works with podman. See [advanced install instructions for other OS](https://podman.io/getting-started/installation)


```
dnf install -y podman podman-docker
touch /etc/containers/nodocker
curl -L $(curl -L -s https://api.github.com/repos/docker/compose/releases/latest | grep -o -E "https://(.*)docker-compose-linux-x86_64" | uniq) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

install Apptainer or see [advanced install instructions for other OS](https://apptainer.org/docs/admin/main/installation.html#install-from-source). Note that Apptainer is expected to be available in EPEL in 2022 which would make installing it much easier. 

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

For unprivileged users podman will store containers in their home directory by default. This will fail on most HPC systems as user home directories are on networked storage systems (NFS, Lustre, etc) for which the extended attribute support (user xattr) required by rootless podman is not yet supported in Linux Kernels < 5.9. (Backporting on RHEL kernels is currently work in progress). Our current workaround is to change `rootless_storage_path` from the default network mounted home directory to a location on the local disk of the login node. Execute this `sed` command after replacing /loc/tmpcontainer with your preferred local folder

```
sed -i '/^# rootless_storage_path =.*/a rootless_storage_path = "\/loc\/tmpcontainer\/\${USER}\/share\/containers\/storage"' /etc/containers/storage.conf
mkdir -p /loc/tmpcontainer && chmod 777 /loc/tmpcontainer
```

if you have not installed the podman-docker package above, you can also setup a global alias to ensure that all users can continue to use docker commands to run podman.

```
echo "alias docker=podman" >> /etc/profile.d/zzz-hpc-users.sh
```

### Setup a docker registry on networked storage

After users created their containers on local disk they want to continue to use them on all nodes of the HPC cluster but also store it longer term in a docker registry as you will eventually have to clean out the local disk on the login node. There are public ones such as quay.io or biocontainers.org, fancy private ones such as https://goharbor.io/ or just [one with simple authentication using Podman](https://www.redhat.com/sysadmin/simple-container-registry)

However, the easiest option that does not require authentication is to create a docker registry on a private/secured login node and to access it via localhost without authentication:  

### Dedicated login node with docker registry  

Many HPC centers offer a condo model where investigators can purchase their own compute nodes which are then managed by the HPC team. If they want to purchase only a couple of nodes there is limited value in offering these resources to a larger community when the node owners are not using them. 
The investigator may prefer to purchase a large memory login node with many CPUs and multiple GPU instead. Such a machine could be used as a beefy development or interactive compute machine with direct access to the HPC cluster and to fast storage. This login node could have several features turning it into an advanced application server:

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

#### Testing the registry

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

## Summary 

With this setup we have achieved multiple benefits:

* Docker users can work with their familiar commands to create containers directly on HPC systems
* On login nodes containers can be created very rapidly which lowers the barriers for users who would otherwise not be inclined to use containers 
* By storing OCI container images instead of apptainer sif images we can share our images with a much larger audience and use them in the cloud as well 
* Using Apptainer may be the best option for running containers as they have some additional features suited for HPC systems and HPC teams have already years of experience with managing and troubleshooting Apptainer

**If you find inaccuracies or have suggestions for improvements please send me a pull request.** 

## Appendix

### Setting up a test nfs home directory

Use these instructions to setup a test environment with NFS mounted home directory for `testuser` on your local machine  

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

### Additional links / resources 

#### Generic

* Supercontainers, enabling containers at Exascale:  
  http://supercontainers.org/

* HPC Containers slack channel: 
  https://hpc-containers.slack.com/

* Minimize Privilege for building HPC containers (LANL)
  https://dl.acm.org/doi/pdf/10.1145/3458817.3476187


#### Podman

* awesome terminal user interface (TUI) for Podman 4
https://github.com/containers/podman-tui

* podman-compose puts all containers in the same pod with a common network unlike docker-compose: 
  https://fedoramagazine.org/manage-containers-with-podman-compose/

* Podman 4 can read Apptainer sif format: https://www.redhat.com/es/blog/expanding-podman-capabilities-deploy-sif-formatted-containers

* building OCI containers from bash scripts if you don't like Dockerfile
  https://github.com/containers/buildah

* converting SIF to OCI and advanced management of image registries 
  https://github.com/containers/skopeo

* User Xattr support for NFS in Kernel 5.9 
  https://kernelnewbies.org/Linux_5.9

* Prometheus exporter to monitor Podman with Grafana
  https://github.com/containers/prometheus-podman-exporter


#### Apptainer / Singularity 

* shpc, allow loading of containers via Lmod:
  https://github.com/singularityhub/singularity-hpc

* creating Docker images from Singularity images:
  https://github.com/singularityhub/singularity2docker


#### Docker

* Docker can also run rootless now: 
  https://thenewstack.io/how-to-run-docker-in-rootless-mode/

