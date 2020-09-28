---
title: 'OpenShift OKD on Fedora CoreOS on DigitalOcean Part 3: Upgrading'
author: dustymabe
date: 2020-09-27
tags: [ kubernetes, openshift, okd, fedora, coreos, digitalocean ]
published: true
---

# Introduction

**NOTE**: The third post of this series is available [here](/2020/08/23/openshift-okd-on-fedora-coreos-on-digitalocean-part-2-configuration/).

This blog post is the fourth in a series that illustrates how to 
set up an [OpenShift OKD](https://www.okd.io/) cluster on 
[DigitalOcean](https://www.digitalocean.com/). The third post in the
series covered further configuration of a cluster once it's already
up and running. At this point you should have a cluster up and running
and configured with custom TLS certificates and user login's
outsourced to some other identity management service.

In this post we'll briefly cover how to view and perform upgrades on
the cluster now that it's set up.

# Performing an Upgrade of OKD

Assuming you have both access to the web console of the machine and
also access from the command line via the `oc` client we can check out
the status of the cluster with both.

First, in the web console you can see information about the current version of
the cluster and available updates when you first log in:

![image](/2020-09-27/cluster-overview.png)

When you click on the update button a popup will open where you can view the
options and click `Update` to start the process.

![image](/2020-09-27/cluster-update.png)

Similarly, via the CLI you can view the same information:


```nohighlight
$ oc adm upgrade
Cluster version is 4.5.0-0.okd-2020-07-14-153706-ga

Updates:

VERSION                       IMAGE
4.5.0-0.okd-2020-07-29-070316 registry.svc.ci.openshift.org/origin/release@sha256:6565b6eb19a82f4c9230641286c27f003625b79984ed8e733b011c72790a5eb3
```

And kick off the update:

```nohighlight
$ oc adm upgrade --to-latest=true
Updating to latest version 4.5.0-0.okd-2020-07-29-070316
```

The update will take a while but it can be monitored in several ways.
`oc adm upgrade` and `oc get clusterversion` will both show progress
in the form of percentage complete meter:

```nohighlight
$ oc adm upgrade
info: An upgrade is in progress. Working towards 4.5.0-0.okd-2020-07-29-070316: 18% complete

No updates available. You may force an upgrade to a specific release image, but doing so may not be supported and result in downtime or data loss.

$ oc get clusterversion
NAME      VERSION                            AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.5.0-0.okd-2020-07-14-153706-ga   True        True          67s     Working towards 4.5.0-0.okd-2020-07-29-070316: 18% complete
```

You can also watch the clusteroperators each progress through the update:

```nohighlight
watch -n5 oc get clusteroperators
```

As part of the upgrade each node will reboot. If the update includes a
new version of Fedora CoreOS (this particular update did not) then you
can view the version change of each node:

```nohighlight
$ oc get nodes -o wide
NAME            STATUS   ROLES    AGE    VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                        KERNEL-VERSION           CONTAINER-RUNTIME
okd-control-0   Ready    master   136m   v1.18.3   104.131.65.160   <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
okd-control-1   Ready    master   136m   v1.18.3   104.131.65.164   <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
okd-control-2   Ready    master   136m   v1.18.3   104.131.65.194   <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
okd-worker-0    Ready    worker   130m   v1.18.3   104.131.65.218   <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
okd-worker-1    Ready    worker   130m   v1.18.3   104.131.66.14    <none>        Fedora CoreOS 32.20200629.3.0   5.6.19-300.fc32.x86_64   cri-o://1.18.2
```

Once the upgrade is done `oc adm upgrade` and `oc get clusterversion`
will show the new version and also that there are not updates
available:

```nohighlight
$ oc adm upgrade
Cluster version is 4.5.0-0.okd-2020-07-29-070316

No updates available. You may force an upgrade to a specific release image, but doing so may not be supported and result in downtime or data loss.
  
$ oc get clusterversion
NAME      VERSION                         AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.5.0-0.okd-2020-07-29-070316   True        False         38s     Cluster version is 4.5.0-0.okd-2020-07-29-070316
```

And the web console will show similar information.

# Conclusion

This post goes through how to upgrade your OKD cluster once you've got it
up and running. Happy updating!
