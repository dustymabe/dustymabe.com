---
title: 'GCP Quickstart Guide for OpenShift OKD'
author: dustymabe
date: 2020-10-07
tags: [ kubernetes, openshift, okd, fedora, coreos, gcp ]
draft: false
---

# Introduction

I recently did a blog post 
[series](/2020/08/13/openshift-okd-on-fedora-coreos-on-digitalocean-part-1-deployment/).
showing how to get started with
[OpenShift OKD](https://www.okd.io/) on Fedora CoreOS for DigitalOcean. For that series
I wrote a script to do most of the heavy lifting because DigitalOcean
isn't a native supported platform by the OpenShift installer.

Today I'll show off how to get started in GCP, which is supported
natively by the OpenShift installer. This makes it much easier to
get started because most of the heavy lifting (including infrastructure
bringup) is done by the installer itself.

As always, when looking for more information in addition to what I'm
showing here today refer to the
[existing documentation](https://docs.okd.io/latest/installing/installing_gcp/installing-gcp-account.html). 


# Grabbing the OKD software                                                        
                                                                                   
To install OKD you'll use a program called `openshift-installer`.
You'll then use the `oc` or `kubectl` binaries to interact with your
cluster. You can grab them all from the latest release on [the
releases page](https://github.com/openshift/okd/releases). Currently
the latest release is `4.5.0-0.okd-2020-09-04-180756`. Follow the
instructions in the [Getting Started](https://github.com/openshift/okd#getting-started)
section to download and verify the software.
                                                                                   
Place `oc`, `kubectl` and `openshift-install` into your `$PATH` so they can
be used by a script we run later. Placing them in `/usr/local/bin/` should suffice.


# Grabbing the gcloud CLI

Before we start the install of OKD we'll use the
[gcloud CLI tool](https://cloud.google.com/sdk/gcloud/) to verify our
access key works and also set up our new project API subscriptions
and Domains. You can use the
[quickstart documentation](https://cloud.google.com/sdk/docs/quickstarts)
to get started. Also note
[there is a container](https://cloud.google.com/sdk/docs/downloads-docker)
if you'd prefer to use that.

Once you get `gcloud` installed you can run `gcloud auth activate-service-account`
to authenticate using a key key that was generated for the service account.
This will come after we create the new project in the next section.


# Starting Fresh in a New Project

One of the things I love most about GCP is the fact that you can
create projects and give out access to just that individual project.
For this tutorial let's start with a brand new project called
`okdtest-dustymabe-com`. This can be done over in the cloud resource
manager in the [GCP web console](https://console.cloud.google.com/cloud-resource-manager). 

Next create some access tokens for the project by browsing to the
[service accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
page. In this case I created one named `okdtest-dustymabe-com` with
the `Project Owner` role so it can do anything to the project.

After creating a key for that service account you can download the
JSON file locally (mine was named `okdtest-dustymabe-com-62204e6b2766.json`)
and use that to manage things from here on out.

For the `gcloud` CLI I used the container and copied my credentials into
it. Then ran the following command to activate my credentials:

```nohighlight
# gcloud auth activate-service-account --key-file=/root/okdtest-dustymabe-com-62204e6b2766.json
Activated service account credentials for: [okdtest-dustymabe-com@okdtest-dustymabe-com.iam.gserviceaccount.com]


To take a quick anonymous survey, run:
  $ gcloud survey

```

Since this is a brand new project we need to enable some APIs that
will be used by the installer and by OKD itself. Let's do that now:

```nohighlight
# export CLOUDSDK_CORE_PROJECT='okdtest-dustymabe-com'
# while read service; do
    gcloud services enable $service
done <<EOF
compute.googleapis.com
cloudapis.googleapis.com
cloudresourcemanager.googleapis.com
dns.googleapis.com
iamcredentials.googleapis.com
iam.googleapis.com
servicemanagement.googleapis.com
serviceusage.googleapis.com
storage-api.googleapis.com
storage-component.googleapis.com
EOF
Operation "operations/acf.e85e44a2-e3a8-4f83-9382-8e9e6300c159" finished successfully.
Operation "operations/acf.0751184b-18c0-434a-b1bf-940686933e6d" finished successfully.
Operation "operations/acf.f921dd54-9e94-4271-9883-40a6ae4c9216" finished successfully.
Operation "operations/acf.aa0fd0ac-0dbb-4570-9d22-a5168593bb96" finished successfully.
Operation "operations/acf.c8795df5-2c6a-4705-911d-b6af4a667688" finished successfully.
```


# Setting up DNS 

Now that we're set up with the `gcloud` CLI let's create a Domain
within GCP that will manage the subdomain I've chosen (`okdtest.dustymabe.com`). 

```nohighlight
# export CLOUDSDK_CORE_PROJECT='okdtest-dustymabe-com'
# gcloud dns managed-zones create okdtest \
      --description=okdtest               \
      --dns-name='dustymabe.com'  \
      --visibility=public
Created [https://dns.googleapis.com/dns/v1/projects/okdtest-dustymabe-com/managedZones/okdtest].

# gcloud dns managed-zones describe okdtest
creationTime: '2020-09-08T21:18:13.958Z'
description: okdtest
dnsName: dustymabe.com.
id: '4438023252962860073'
kind: dns#managedZone
name: okdtest
nameServers:
- ns-cloud-b1.googledomains.com.
- ns-cloud-b2.googledomains.com.
- ns-cloud-b3.googledomains.com.
- ns-cloud-b4.googledomains.com.
visibility: public
```

Now we need to update our registrar for `dustymabe.com` to point the
`okdtest` subdomain at the google servers in the output above. The
entries at my registrar will look like this:

| Type  | Name                   | Value                         |
| :---- | :--------------------: | ----------------------------: |
| NS    | okdtest.dustymabe.com. | ns-cloud-b1.googledomains.com |
| NS    | okdtest.dustymabe.com. | ns-cloud-b2.googledomains.com |
| NS    | okdtest.dustymabe.com. | ns-cloud-b3.googledomains.com |
| NS    | okdtest.dustymabe.com. | ns-cloud-b4.googledomains.com |

We are now effectively done with the `gcloud` CLI. The
`openshift-install` will take care of things from here.


# Create a Working Directory

For the purposes of this tutorial let's create a fresh working
directory for files related to the project. You can use any directory.
I'll use `~/okdtest`.

```nohighlight
$ mkdir ~/okdtest && cd ~/okdtest
```

I'll also place the credentials for the service account into this
directory:

```nohighlight
$ ls ./okdtest-dustymabe-com-62204e6b2766.json
./okdtest-dustymabe-com-62204e6b2766.json
```


# Creating The Cluster

The `openshift-install` program picks up GCP credentials
from `~/.gcp/osServiceAccount.json`. Let's copy our credentials
there first:

```nohighlight
$ mkdir -p ~/.gcp
$ cp okdtest-dustymabe-com-62204e6b2766.json ~/.gcp/osServiceAccount.json
```

Now we can generate our manifests interactively using the
`openshift-install` program:

```nohighlight
$ openshift-install create manifests --dir=generated-files
? Platform gcp
INFO Credentials loaded from file "/home/dustymabe/.gcp/osServiceAccount.json"
? Project ID okdtest-dustymabe-com (okdtest-dustymabe-com)
? Region us-east4
? Base Domain dustymabe.com
? Cluster Name okdtest
? Pull Secret [? for help] **********************************
```

Since this is OKD, we don't need a pull secret. You can just copy
in a fake value of `{"auths":{"fake":{"auth": "bar"}}}` there.

If you'd prefer to not run the program interactively you can use
your own pre-created `install-config.yaml` file. For example you
can start with an `install-config.yaml` of 

```nohighlight
$ cat install-config.yaml 
apiVersion: v1
baseDomain: dustymabe.com
metadata:
  name: okdtest
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 2
controlPlane:
  hyperthreading: Enabled
  name: master 
  replicas: 3
platform:
  gcp:
    projectID: okdtest-dustymabe-com
    region: us-east4
fips: false
pullSecret: '{"auths":{"fake":{"auth": "bar"}}}'
```

And then copy it into the right place before asking
`openshift-install` to create manifests:

```nohighlight
$ mkdir generated-files
$ cp install-config.yaml generated-files/
$ openshift-install create manifests --dir=generated-files
INFO Credentials loaded from file "/home/dustymabe/.gcp/osServiceAccount.json" 
INFO Consuming Install Config from target directory
```

Now we can create the cluster!

```nohighlight
$ openshift-install create cluster --dir=generated-files
INFO Credentials loaded from file "/home/dustymabe/.gcp/osServiceAccount.json"
INFO Consuming Common Manifests from target directory
INFO Consuming Master Machines from target directory
INFO Consuming OpenShift Install (Manifests) from target directory
INFO Consuming Openshift Manifests from target directory
INFO Consuming Worker Machines from target directory
INFO Creating infrastructure resources...
INFO Waiting up to 20m0s for the Kubernetes API at https://api.okdtest.dustymabe.com:6443...
INFO API v1.18.3 up
INFO Waiting up to 40m0s for bootstrapping to complete...
INFO Destroying the bootstrap resources...
INFO Waiting up to 30m0s for the cluster at https://api.okdtest.dustymabe.com:6443 to initialize...
INFO Waiting up to 10m0s for the openshift-console route to be created...
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/dustymabe/okdtest/generated-files/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.okdtest.dustymabe.com
INFO Login to the console with user: "kubeadmin", and password: "SCQhE-ab4Cq-aNMPE-j3tY4"
INFO Time elapsed: 39m13s
```

**NOTE:** You can destroy the cluster and remove all associated resources with
          `openshift-install destroy cluster --dir=generated-files`.

Now I can access the cluster using the username and password in the
output above or I can use the kubeconfig in
`generated-files/auth/kubeconfig`.


# Conclusion

And that's all there is to it. Hopefully others find this useful
in addition to the [existing documentation](https://docs.okd.io/latest/installing/installing_gcp/installing-gcp-account.html).
