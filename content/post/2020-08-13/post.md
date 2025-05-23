---
title: 'OpenShift OKD on Fedora CoreOS on DigitalOcean Part 1: Deployment'
author: dustymabe
date: 2020-08-13
tags: [ kubernetes, openshift, okd, fedora, coreos, digitalocean ]
draft: false
---

# Introduction

**NOTE**: The first post of this series is available [here](/2020/07/28/openshift-okd-on-fedora-coreos-on-digitalocean-part-0-preparation/).

This blog post is the second in a series that illustrates how to 
set up an [OpenShift OKD](https://www.okd.io/) cluster on 
[DigitalOcean](https://www.digitalocean.com/). The first post in the
series covered some background information and pre-requisites needed
for deploying a cluster. At this point you should have chosen the domain
for your cluster, set up your registrar to point to DigitalOcean nameservers,
installed all necessary software (`doctl`, `openshift-install`, `oc`, `aws cli`,
etc..), and configured appropriate credentials in your environment
(`DIGITALOCEAN_ACCESS_TOKEN`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).

Now we can move forward with a few final decisions and on to the
actual deployment. To aid in this I've created a script that can be
used to automate the bulk of the cluster setup and deployment. This
script (and relevant files) can be accessed at
[github.com/dustymabe/digitalocean-okd-install](https://github.com/dustymabe/digitalocean-okd-install).


# The Automation Repo

The [digitalocean-okd-install repo](https://github.com/dustymabe/digitalocean-okd-install)
is set up in the following way:

- the `resources` directory
    - holds some template files and fcct configs used during the automation
- the `config` file
    - bash variables (key/value pairs) where user customizations go
- the `digitalocean-okd-install` script
    - used to bring up and tear down a cluster 

Let's look at each one of these in a little more detail.


## The `resources` Directory

The resources directory contains files that aid in the install. Let's
look at a few of the files in the directory.

We'll start with `resources/install-config.yaml.in`:

```nohighlight
$ cat resources/install-config.yaml.in
# The most simple possible OKD install-config.
# BASEDOMAIN, CLUSTERNAME, NUM_OKD_WORKERS, NUM_OKD_CONTROL_PLANE
# will be substituted with runtime values.
apiVersion: v1
baseDomain: BASEDOMAIN
metadata:
  name: CLUSTERNAME
compute:
- hyperthreading: Enabled
  name: worker
  replicas: NUM_OKD_WORKERS
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: NUM_OKD_CONTROL_PLANE
platform:
  none: {}
fips: false
pullSecret: '{"auths":{"fake":{"auth": "bar"}}}'
```

The `resources/install-config.yaml.in` file is a dumb template that
is used to substitute in some custom information into a
[install-config.yaml](https://docs.okd.io/latest/installing/installing_bare_metal/installing-bare-metal.html#installation-initializing-manual_installing-bare-metal)
that is used with `openshift-insall`. If you want to customize your
install config further you can edit this template. For now we have 4
tokens in the file that we replace: `BASEDOMAIN`, `CLUSTERNAME`,
`NUM_OKD_WORKERS`, `NUM_OKD_CONTROL_PLANE`.

The other files in the directory worth mentioning are the
`fcct-{bootstrap,control-plane,worker}.yaml` files. These files are
[Fedora CoreOS Config Transpiler](https://github.com/coreos/fcct)
configs that allow us to customize the generated Ignition configs from
`openshift-install`. This is useful in case there are things we need
to add or bugs we need to workaround temporarily. For example,
[a bug](https://github.com/coreos/fedora-coreos-tracker/issues/538)
in Fedora CoreOS meant that nodes on DigitalOcean were getting a
hostname of `localhost`, which breaks OKD. The current workaround
for that (which won't be needed for long) is to fix it with an
fcct config like:

```nohighlight
$ cat resources/fcct-control-plane.yaml
# This config is an opportunity to make customizations or to workaround bugs
# that may exist for the control plane nodes.
variant: fcos
version: 1.1.0
ignition:
  config:
    merge:
      - local: ./generated-files/master.ign
systemd:
  units:
  # Set the hostname
  # Fixed in testing 32.20200726.2.0+
  # Will be fixed in stable 32.20200726.3.0+
  # https://github.com/coreos/fedora-coreos-tracker/issues/538
  - name: sethostname.service
    enabled: true
    contents: |
      [Unit]
      After=NetworkManager-wait-online.service
      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/run-hostnamectl
      RemainAfterExit=yes
      [Install]
      WantedBy=multi-user.target
storage:
  files:
    - path: /usr/local/bin/run-hostnamectl
      mode: 0755
      contents:
        inline: |
          #!/usr/bin/bash
          hostnamectl set-hostname $(curl -s http://169.254.169.254/metadata/v1/hostname)
```

The `ignition.config.merge` section tells `fcct` to pick up the file
at `./generated-files/master.ign` (generated by the `openshift-install`
program) and merge it with the rest of the file. The rest of the file
defines a systemd service and script to run to permanently set the
hostname on first boot.


## The `config` File

The config file in the toplevel of the repo allows the user to perform
customizations that are needed in order to bring up a cluster. Each
user will need to modify at least one or two variables in this file.
An example `config` file looks like:

```bash
# Set the name/domain you'd like to use for this cluster.
CLUSTERNAME='okdtest'
BASEDOMAIN='example.com'
DOMAIN="${CLUSTERNAME}.${BASEDOMAIN}"

# Determine how many control plane and worker nodes you'd like.
# Minimum workers=0. Minimum control plane=3. If no workers then
# the control pane nodes will be marked as schedulable.
NUM_OKD_WORKERS=2
NUM_OKD_CONTROL_PLANE=3

# Set the region to use. Default to nyc3.
DIGITAL_OCEAN_REGION='nyc3'

# S3 compatible endpoint for SPACES in this region.
SPACES_ENDPOINT="https://${DIGITAL_OCEAN_REGION}.digitaloceanspaces.com"

# Bucket to use. The DOMAIN should be unique enough.
SPACES_BUCKET="s3://${DOMAIN}"

# The ssh keypair id (required to start a droplet)
DROPLET_KEYPAIR='1111111' # `doctl compute ssh-key list` to fine IDs

# The size of the droplets.
DROPLET_SIZE='s-6vcpu-16gb' # `doctl compute size list` for more options

# The location of the Fedora CoreOS image to use. The script takes
# care of the import [1] for you. It will also skip the image import if
# the image with $DROPLET_IMAGE_NAME already exists. You can get the
# URL for the latest DigitalOcean image from the download page [2].
#
# [1] https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-digitalocean/#_creating_a_digitalocean_custom_image
# [2] https://getfedora.org/coreos/download?tab=cloud_operators&stream=stable
FCOS_IMAGE_URL='https://example.com/builds/fedora-coreos-32.20200629.3.0-digitalocean.x86_64.qcow2.gz'

# Keep it simple. Derive the image name from the URL.
DROPLET_IMAGE_NAME="${FCOS_IMAGE_URL##*/}"

# Set a tag to use for all droplets, control plane, and workers
ALL_DROPLETS_TAG="$CLUSTERNAME"
CONTROL_DROPLETS_TAG="${CLUSTERNAME}-control"
WORKER_DROPLETS_TAG="${CLUSTERNAME}-worker"

# The size of the backing volume for the container registry
REGISTRY_VOLUME_SIZE='20' # in GiB
```

Each variable in the file has an accompanying description text. For the cluster
I'll be bringing up today I'll update a few variables:

- `CLUSTERNAME`
    - I'll leave this one at `okdtest` since it fits the `okdtest.dustymabe.com`
      domain I want to use.
- `BASEDOMAIN`
    - Since I want to use `okdtest.dustymabe.com` as my domain I set this to `dustymabe.com`.
- `DROPLET_KEYPAIR`
    - Updated to point to the ID of the keypair I want to use.
- `FCOS_IMAGE_URL`
    - Updated to point to the [`32.20200629.3.0` DigitalOcean Image](https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/32.20200629.3.0/x86_64/fedora-coreos-32.20200629.3.0-digitalocean.x86_64.qcow2.gz).


You may want to change a few others. Notably, you may want to change
the number of control plane and worker nodes (`NUM_OKD_CONTROL_PLANE`
and `NUM_OKD_WORKERS`), the region to use (`DIGITAL_OCEAN_REGION`),
or the size of the droplets to use (`DROPLET_SIZE`).

Regarding droplet size. The documentation does not recommend going
below 16G instances. This means it will cost you at least a few
hundred dollars a month, which means you probably won't be using this
cluster as a hobby. There are some tricks to get the instance size
down, but the cost is still significant.


## The `digitalocean-okd-install` Script

The `digitalocean-okd-install` script is what does all the heavy lifting.
At a high level it:

- Creates a Spaces (s3) bucket to hold the bootstrap Ignition config
- Creates a custom image in DigitalOcean for the linked FCOS image
- Creates a VPC for private network traffic
- Creates a Load Balancer to balance traffic
- Creates a Firewall to block against unwanted traffic
- Generates manifests/configs via `openshift-install`
- Uploads the bootstrap config to spaces to be retrieved by the bootstrap instance
- Creates bootstrap, control plane, and worker droplets
- Creates a DigitalOcean Domain and required DNS records
- Provisions the DigitalOcean block storage CSI driver to the cluster
- Removes the bootstrap droplet and Spaces bucket (no longer needed)


# Doing The Install

Now that we have updated our config and we've set our credentials in
the environment (done in the previous post in the series) we can run
the automation script to bring up the cluster:

```nohighlight
$ ./digitalocean-okd-install

Creating custom image fedora-coreos-32.20200629.3.0-digitalocean.x86_64.qcow2.gz.

Image with name already exists. Skipping image creation.

Creating VPC for private traffic.


Creating load-balancer.

Waiting for load balancer to come up...
Waiting for load balancer to come up...
Waiting for load balancer to come up...

Creating firewall.


Generating manifests/configs for install.

INFO Consuming Install Config from target directory
INFO Consuming Openshift Manifests from target directory
INFO Consuming Common Manifests from target directory
INFO Consuming Master Machines from target directory
INFO Consuming Worker Machines from target directory
INFO Consuming OpenShift Install (Manifests) from target directory

Creating droplets.

ID           Name             Public IPv4       Private IPv4
202509106    bootstrap        157.245.15.149    10.108.0.3
202509108    okd-control-0    104.131.65.160    10.108.0.4
202509109    okd-control-1    104.131.65.164    10.108.0.5
202509110    okd-control-2    104.131.65.194    10.108.0.6
202509111    okd-worker-0     104.131.65.218    10.108.0.7
202509112    okd-worker-1     104.131.66.14     10.108.0.8

Creating domain and DNS records.


Waiting for bootstrap to complete.

INFO Waiting up to 20m0s for the Kubernetes API at https://api.okdtest.dustymabe.com:6443...
INFO API v1.18.3 up
INFO Waiting up to 40m0s for bootstrapping to complete...
INFO It is now safe to remove the bootstrap resources
INFO Time elapsed: 8m10s

Removing bootstrap resources.


Approve CSRs if needed.

Approving all pending CSRs and waiting for remaining requests..
CSR not yet requested for okd-worker-0. Continuing.
Approving all pending CSRs and waiting for remaining requests..
certificatesigningrequest.certificates.k8s.io/csr-rs9n6 approved
CSR not yet requested for okd-worker-0. Continuing.
Approving all pending CSRs and waiting for remaining requests..
CSR not yet requested for okd-worker-0. Continuing.
Approving all pending CSRs and waiting for remaining requests..
certificatesigningrequest.certificates.k8s.io/csr-878mx approved
CSR not yet requested for okd-worker-0. Continuing.
Approving all pending CSRs and waiting for remaining requests..
certificatesigningrequest.certificates.k8s.io/csr-m8vtj approved
CSR not yet requested for okd-worker-0. Continuing.
Approving all pending CSRs and waiting for remaining requests..
CSR not yet approved for okd-worker-0. Continuing.
Approving all pending CSRs and waiting for remaining requests..
certificatesigningrequest.certificates.k8s.io/csr-gx246 approved

Move routers to control plane nodes.

Waiting for ingresscontroller to be created...
Waiting for ingresscontroller to be created...
Waiting for ingresscontroller to be created...

Waiting for install to complete.

INFO Waiting up to 30m0s for the cluster at https://api.okdtest.dustymabe.com:6443 to initialize...
E0803 10:04:24.726704 3932175 reflector.go:307] k8s.io/client-go/tools/watch/informerwatcher.go:146: Failed to watch *v1.ClusterVersion: the server is currently unable to handle the request (get clusterversions.config.openshift.io)
INFO Waiting up to 10m0s for the openshift-console route to be created...
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/path/to/digitalocean-okd-install/generated-files/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.okdtest.dustymabe.com
INFO Login to the console with user: "kubeadmin", and password: "jHJmb-V4QKc-Whcfq-ZoopL"
INFO Time elapsed: 15m37s

Creating DigitalOcean block storage driver.

Warning: oc apply should be used on resource created by either oc create --save-config or oc apply
Warning: oc apply should be used on resource created by either oc create --save-config or oc apply
Warning: oc apply should be used on resource created by either oc create --save-config or oc apply

Fixing the registry storage to use DigitalOcean volume.
```

And that's it. It takes some time to run and bring the cluster fully
up, but you see from the output that we can now access the console at
`https://console-openshift-console.apps.okdtest.dustymabe.com` with
the given username and password.

We can also use the `kubeconfig` file in the files generated by the
installer to browse a bit. Let's look at the currently deployed
cluster version:

```nohighlight
$ export KUBECONFIG=${PWD}/generated-files/auth/kubeconfig
$ oc get clusterversion
NAME      VERSION                            AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.5.0-0.okd-2020-07-14-153706-ga   True        False         107m    Cluster version is 4.5.0-0.okd-2020-07-14-153706-ga
```

We can see the nodes that are a part of the cluster:

```nohighlight
$ oc get nodes -o wide
NAME            STATUS   ROLES    AGE    VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                        KERNEL-VERSION           CONTAINER-RUNTIME
okd-control-0   Ready    master   106m   v1.18.3   104.131.65.160   <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
okd-control-1   Ready    master   106m   v1.18.3   104.131.65.164   <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
okd-control-2   Ready    master   106m   v1.18.3   104.131.65.194   <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
okd-worker-0    Ready    worker   100m   v1.18.3   104.131.65.218   <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
okd-worker-1    Ready    worker   100m   v1.18.3   104.131.66.14    <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
```

And we can see how healthy the cluster is by looking at the `DEGRADED`
status of the cluster operators:

```nohighlight
$ oc get clusteroperators
NAME                                       VERSION                            AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      115m
cloud-credential                           4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      130m
cluster-autoscaler                         4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      120m
config-operator                            4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      120m
console                                    4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      115m
csi-snapshot-controller                    4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      122m
dns                                        4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      126m
etcd                                       4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      126m
image-registry                             4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      104m
ingress                                    4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      121m
insights                                   4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      121m
kube-apiserver                             4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      125m
kube-controller-manager                    4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      125m
kube-scheduler                             4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      125m
kube-storage-version-migrator              4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      122m
machine-api                                4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      121m
machine-approver                           4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      126m
machine-config                             4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      126m
marketplace                                4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      121m
monitoring                                 4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      115m
network                                    4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      127m
node-tuning                                4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      127m
openshift-apiserver                        4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      122m
openshift-controller-manager               4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      121m
openshift-samples                          4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      119m
operator-lifecycle-manager                 4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      126m
operator-lifecycle-manager-catalog         4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      126m
operator-lifecycle-manager-packageserver   4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      105m
service-ca                                 4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      127m
storage                                    4.5.0-0.okd-2020-07-14-153706-ga   True        False         False      121m
```


# Tearing It All Down

You can use the same `digitialocean-okd-install` script to bring the
cluster down and clean up all resources by using the `destruct`
argument. Here is an example of it running:

```
$ ./digitalocean-okd-install destruct
#########################################################
Deleting resources created for OKD. This is a dumb delete
which attempts to delete things without checking if they
exist so you'll need to ignore error messages if some
resources are already deleted.
#########################################################

Deleting Load Balancer.

Deleting Firewall.

Deleting Domain and DNS entries.

Deleting Droplets.

Deleting Spaces (S3) bucket and all contents.
fatal error: An error occurred (NoSuchBucket) when calling the ListObjectsV2 operation: Unknown

remove_bucket failed: Unable to delete all objects in the bucket, bucket will not be deleted.

Deleting VPC.

YOU WILL NEED TO MANUALLY DELETE ANY CREATED VOLUMES OR IMAGES
```

As noted in the script it will clean up everything except for created
block storage volumes and the custom image that was used. 


# Notable Decisions

The automation script does quite a few things. Let's go over some
some pieces that are noteworthy or otherwise worth mentioning.


## Single Load Balancer

To simplify the scripting and slightly lower the cost of the cluster 
I decided to use a single load balancer rather than two separate load 
balancers (one for the control plane and one for the workers). Doing
this required me to move the ingress routers to the control plane nodes.
This might not be ideal if your cluster takes a lot of load.


## DigitalOcean Block Storage

One thing the script did was add the 
[DigitalOcean block storage CSI driver](https://github.com/digitalocean/csi-digitalocean) to the cluster.
This driver will create block storage volumes in DigitalOcean whenever
claims (PVCs) are created. One drawback of this is that the cluster
now stores a secret that is your API key, so the cluster has access to
do anything to your account if compromised.

Additionally, the storage created with this driver is only `RWO` capable,
which means that in order for our registry to be backed by it we needed
to change the PVC to be `RWO`, reduce the number of replicas in our image
registry to `1`, and change the update strategy to `Recreate`. 

Now that the cluster is up we can see the volume that was created by
the storage driver and that it is in the `Bound` state:

```nohighlight
$ oc get pvc -n openshift-image-registry
NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS       AGE
image-registry-storage   Bound    pvc-ddc1a327-4c1d-49eb-ae87-520cf8ba366a   20Gi       RWO            do-block-storage   109m
```


# Conclusion

In this post we analyzed the `digitalocean-okd-install` automation script
and learned how to use it to bring up a cluster in DigitalOcean. In
future posts we'll learn how to do some more configuration and start
using and administering the cluster.

**NOTE**: The next post in this series is available [here](/2020/08/23/openshift-okd-on-fedora-coreos-on-digitalocean-part-2-configuration/).
