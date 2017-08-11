---
# Used for fedmag blog post
# Updated with notes from paul frields
title: 'Fedora 25->26 Atomic Host Upgrade Guide'
published: false
---


# Introduction

In July the Atomic Working Group put out the
[first](http://www.projectatomic.io/blog/2017/07/fedora-atomic-26-release/)
and
[second](http://www.projectatomic.io/blog/2017/07/fedora-atomic-july-25/)
releases of Fedora 26 Atomic Host. This article shows you how to
prepare an existing Fedora 25 Atomic Host system for Fedora 26 and do the upgrade.

If you really don't want to upgrade to Fedora 26 see the later section: *Fedora 25 Atomic Host Life Support*.

# Preparing for Upgrade

Before you perform an update to Fedora 26 Atomic Host,
check the filesystem to verify that at least a few GiB of
free space exists in the root filesystem. The update to
Fedora 26 may retrieve more than 1GiB of new content (not
shared with Fedora 25) and thus needs plenty of free space.

Luckily Upstream OSTree has implemented some
[filesystem checks](https://github.com/ostreedev/ostree/pull/987)
to ensure an upgrade stops before it fills up the
filesystem.

The example here is a Vagrant box. First, check the free space
available:

```nohighlight
[vagrant@host ~]$ sudo df -kh /
Filesystem                 Size  Used Avail Use% Mounted on
/dev/mapper/atomicos-root  3.0G  1.4G  1.6G  47% /
```

Only `1.6G` free means the root filesystem probably needs to be
expanded to make sure there is plenty of space. Check the
free space by running the following commands:

```nohighlight
[vagrant@host ~]$ sudo vgs
  VG       #PV #LV #SN Attr   VSize  VFree
  atomicos   1   2   0 wz--n- 40.70g 22.60g
[vagrant@host ~]$ sudo lvs
  LV          VG       Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  docker-pool atomicos twi-a-t--- 15.09g             0.13   0.10                            
  root        atomicos -wi-ao----  2.93g                                                    
```

The volume group on the system in question has `22.60g` free and the `atomicos/root`
logical volume is `2.93g` in size. Increase the
size of the root volume group by 3 GiB:

```nohighlight
[vagrant@host ~]$ sudo lvresize --size=+3g --resizefs atomicos/root
  Size of logical volume atomicos/root changed from 2.93 GiB (750 extents) to 5.93 GiB (1518 extents).
  Logical volume atomicos/root successfully resized.
meta-data=/dev/mapper/atomicos-root isize=512    agcount=4, agsize=192000 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1 spinodes=0 rmapbt=0
         =                       reflink=0
data     =                       bsize=4096   blocks=768000, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal               bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 768000 to 1554432
[vagrant@host ~]$ sudo lvs
  LV          VG       Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  docker-pool atomicos twi-a-t--- 15.09g             0.13   0.10                            
  root        atomicos -wi-ao----  5.93g                                                    
```

The `lvresize` command above alsoe reseid the filesystem all in
one shot. To confirm check the filesystem usage:

```nohighlight
[vagrant@host ~]$ sudo df -kh /
Filesystem                 Size  Used Avail Use% Mounted on
/dev/mapper/atomicos-root  6.0G  1.4G  4.6G  24% /
```

# Upgrading

Now the system should be ready for upgrade. If you do this on a
production system, you may need to prepare services for downtime.

If you use an orchestration platform, there are a few things
to note. If you use Kubernetes, refer to the later
section on Kubernetes: *Upgrading Systems with Kubernetes*.
If you use OpenShift Origin (i.e. via being set
up by the [openshift-ansible installer](http://www.projectatomic.io/blog/2016/12/part1-install-origin-on-f25-atomic-host/)),
the upgrade should not need any preparation.

Currently the system is on Fedora 25 Atomic Host using the
`fedora-atomic/25/x86_64/docker-host` ref.

```nohighlight
[vagrant@host ~]$ rpm-ostree status
State: idle
Deployments:
● fedora-atomic:fedora-atomic/25/x86_64/docker-host
                Version: 25.154 (2017-07-04 01:38:10)
                 Commit: ce555fa89da934e6eef23764fb40e8333234b8b60b6f688222247c958e5ebd5b
```


In order to do the upgrade the location of
the Fedora 26 repository needs to be added as a new remote
(like a git remote) for `ostree` to know about:

```nohighlight
[vagrant@host ~]$ sudo ostree remote add --set=gpgkeypath=/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-26-primary fedora-atomic-26 https://kojipkgs.fedoraproject.org/atomic/26
```
It can be seen from the command that a new remote known as
`fedora-atomic-26` was added with a remote url of `https://kojipkgs.fedoraproject.org/atomic/26`.
The `gpgkeypath` variable was also set in the configuration for
the remote. This tells OSTree that it should verify commit signatures
when downloading from a remote.This is something new that was
enabled for Fedora 26 Atomic Host.

Now that the system has the `fedora-atomic-26` remote the
upgrade can be performed:

```nohighlight
[vagrant@host ~]$ sudo rpm-ostree rebase fedora-atomic-26:fedora/26/x86_64/atomic-host

Receiving metadata objects: 0/(estimating) -/s 0 bytes
Signature made Sun 23 Jul 2017 03:13:09 AM UTC using RSA key ID 812A6B4B64DAB85D
  Good signature from "Fedora 26 Primary <fedora-26-primary@fedoraproject.org>"

Receiving delta parts: 0/27 5.3 MB/s 26.7 MB/355.4 MB
Signature made Sun 23 Jul 2017 03:13:09 AM UTC using RSA key ID 812A6B4B64DAB85D
  Good signature from "Fedora 26 Primary <fedora-26-primary@fedoraproject.org>"

27 delta parts, 9 loose fetched; 347079 KiB transferred in 105 seconds                                                                                                                                            
Copying /etc changes: 22 modified, 0 removed, 58 added
Transaction complete; bootconfig swap: yes deployment count change: 1
Upgraded:
  GeoIP 1.6.11-1.fc25 -> 1.6.11-1.fc26
  GeoIP-GeoLite-data 2017.04-1.fc25 -> 2017.06-1.fc26
  NetworkManager 1:1.4.4-5.fc25 -> 1:1.8.2-1.fc26
  ...
  ...
  setools-python-4.1.0-3.fc26.x86_64
  setools-python3-4.1.0-3.fc26.x86_64
Run "systemctl reboot" to start a reboot
[vagrant@host ~]$ sudo reboot
Connection to 192.168.121.217 closed by remote host.
Connection to 192.168.121.217 closed.
```

After reboot the status looks like:

```nohighlight
$ vagrant ssh
[vagrant@host ~]$ rpm-ostree status
State: idle
Deployments:
● fedora-atomic-26:fedora/26/x86_64/atomic-host
                Version: 26.91 (2017-07-23 03:12:08)
                 Commit: 0715ce81064c30d34ed52ef811a3ad5e5d6a34da980bf35b19312489b32d9b83
           GPGSignature: 1 signature
                         Signature made Sun 23 Jul 2017 03:13:09 AM UTC using RSA key ID 812A6B4B64DAB85D
                         Good signature from "Fedora 26 Primary <fedora-26-primary@fedoraproject.org>"

  fedora-atomic:fedora-atomic/25/x86_64/docker-host
                Version: 25.154 (2017-07-04 01:38:10)
                 Commit: ce555fa89da934e6eef23764fb40e8333234b8b60b6f688222247c958e5ebd5b
[vagrant@host ~]$ cat /etc/fedora-release
Fedora release 26 (Twenty Six)
```

The system is now on Fedora 26 Atomic Host. If this were a production system
now would be a good time to check services, most likely running in containers,
to see if they still work. If a service didn't come up as expected, you
can use the rollback command: `sudo rpm-ostree rollback`.

To track updated commands for upgrading Atomic Host between releases,
visit [this wiki page](https://fedoraproject.org/wiki/Atomic_Host_upgrade).

# Upgrading Systems with Kubernetes

Fedora 25 Atomic Host ships with Kubernetes **v1.5.3**, and Fedora 26
Atomic Host ships with Kubernetes **v1.6.7**. **Before** you 
upgrade systems participating in an existing Kubernetes cluster
from 25 to 26, you must make a few configuration changes.

## Node Servers

In Kubernetes 1.6, the `--config` argument is no longer valid. If
systems exist that have the `KUBELET_ARGS` variable in `/etc/kubernetes/kubelet`
that point to the manifests directory using the `--config` argument, 
you must change the argument name to `--pod-manifest-path`. 
Also in `KUBELET_ARGS`, add an additional argument: `--cgroup-driver=systemd`.

For example, if the `/etc/kubernetes/kubelet` file started with the
following:

```nohighlight
KUBELET_ARGS="--kubeconfig=/etc/kubernetes/kubelet.kubeconfig --config=/etc/kubernetes/manifests --cluster-dns=10.254.0.10 --cluster-domain=cluster.local"
```

Then change it to:

```nohighlight
KUBELET_ARGS="--kubeconfig=/etc/kubernetes/kubelet.kubeconfig --pod-manifest-path=/etc/kubernetes/manifests --cluster-dns=10.254.0.10 --cluster-domain=cluster.local --cgroup-driver=systemd"
```

## Master Servers

### Staying With etcd2

From Kubernetes 1.5 to 1.6 upstream
[shifted](https://kubernetes.io/docs/tasks/administer-cluster/upgrade-1-6/)
from using version 2 of the etcd API to version 3. The
[Kubernetes documentation](https://github.com/kubernetes/kubernetes/blob/93b144c/CHANGELOG.md#internal-storage-layer-1)
instructs users to **add** two arguments to the `KUBE_API_ARGS` variable
in the `/etc/kubernetes/apiserver` file:

```nohighlight
--storage-backend=etcd2 --storage-media-type=application/json
```

This ensures that Kubernetes continues to find any pods, services
or other objects stored in etcd once the upgrade has been completed.

### Moving To etcd3

You can migrate etcd data to the v3 API later. First,
stop the etcd and kube-apiserver services. Then, assuming
the data is stored in `/var/lib/etcd`, run the following command to migrate to etcd3:

```nohighlight
# ETCDCTL_API=3 etcdctl --endpoints https://YOUR-ETCD-IP:2379 migrate --data-dir=/var/lib/etcd
```

After the data migration, remove the `--storage-backend=etcd2`
and `--storage-media-type=application/json` arguments from the
`/etc/kubernetes/apiserver` file and then restart etcd and
kube-apiserver services.

# Fedora 25 Atomic Host Life Support

The Atomic WG [decided](https://pagure.io/atomic-wg/issue/303)
to keep updating the `fedora-atomic/25/x86_64/docker-host`
ref every day when Bodhi runs within Fedora. A new update
is created every day. However, it is recommended you upgrade
systems to Fedora 26 because future testing and development focus on Fedora 26
Atomic Host. Fedora 25 OSTrees won't be explicitly tested.

# Conclusion

The transition to Fedora 26 Atomic Host should be a smooth process.
If you have issues or want to be involved in the future direction of Atomic
Host, please join us in IRC (#atomic on
[freenode](https://freenode.net/))
or on the [atomic-devel](https://lists.projectatomic.io/mailman/listinfo/atomic-devel)
mailing list.
