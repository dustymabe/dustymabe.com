---
title: 'How Do We Create OSTree Repos and Artifacts in Fedora'
author: dustymabe
date: 2017-08-08
tags: [ fedora, atomic ]
published: true
---

# Introduction

**NOTE:** For background on OSTree check out the
          [docs](https://ostree.readthedocs.io/en/latest/).

When you want to create a new OSTree using `rpm-ostree` you usually define
a few yum repos, and then a json file that says what rpms you
want to be composed in the tree. You then run an `rpm-ostree compose
tree` command to create the commit in the ostree repo. Once the
ostree commit has been created you can then create installer images
(ISOs) and cloud/VM images (qcow, etc) from that ostree.

How does Fedora do this? It's a bit complicated, but I'll try to cover
the bases. 

First I'll give you a little high level view of the way things are
built before major release, all using Pungi. I'll then try to dig into
*The LEGOs* that are used to build the artifacts we care about.
Finally, I'll try to explain how things are different after a major
release is out and how we end up getting updated rpms and eventually
two week releases out the door.


# Before Fedora Major Release: Building Everything Using Pungi

Prior to any major release of Fedora the release engineering team *builds the
whole world* every night. This is done using a tool called
[Pungi](https://pagure.io/pungi). A [script](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/nightly.sh)
is called to kick off the nightly run via a [cron job](https://infrastructure.fedoraproject.org/cgit/ansible.git/tree/roles/releng/files/branched). 
The Pungi config that is used is the [fedora.conf](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora.conf)
file from the [pungi-fedora](https://pagure.io/pungi-fedora) git repo. 

For Fedora 26 you can see where the ostree for Atomic Host is defined
in the Pungi config, [here](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora.conf#_710-728),
in the **ostree** section. During a compose you can
see that the ostree will get placed into `"ostree_repo": "/mnt/koji/compose/atomic/26/",`.
After the compose has finished it will get synced to `/mnt/koji/atomic/26/` which corresponds
to the public URL https://kojipkgs.fedoraproject.org/atomic/26/.

During the compose, once the ostree commit has been created, the
installer ISO and the cloud images can get created. The definition for
the [installer ISO](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora.conf#_741-761)
and the [cloud images](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora.conf#_355-383)
are all within the same Pungi config.

# The LEGOs 

There are a few building blocks we need to talk about before we really jump into
how this whole thing is put together. First, we have to talk about how the OSTree
gets created and then the artifacts that are derived from it.

## The RPM OSTree

To create the OSTree Pungi ends up calling out to a [Koji](https://pagure.io/koji)
runroot task. This runroot task essentially runs a command and harvests the results. The
command that eventually gets run is an [rpm-ostree command](https://pagure.io/pungi/blob/381d08a81079581595e9e48174267b7e7bbd263b/f/pungi/ostree/tree.py#_31-32)
that looks something like this:

```nohighlight
rpm-ostree compose tree --repo=/mnt/koji/compose/atomic/26/ \
--write-commitid-to=/mnt/koji/compose/branched/Fedora-26-20170705.n.0/logs/x86_64/Atomic/ostree-2/commitid.log \
/mnt/koji/compose/branched/Fedora-26-20170705.n.0/work/ostree-2/config_repo/fedora-atomic-docker-host.json
```

From the [ostree part of the Pungi config](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora.conf#_710-728)
you can see where some of the arguments for this command came from:

```
ostree = [
    ("^Atomic$", {
        "x86_64": {
            "treefile": "fedora-atomic-docker-host.json",
            "config_url": "https://pagure.io/fedora-atomic.git",
            "config_branch": "f26",
            "source_repo_from": "Everything",
            "ostree_repo": "/mnt/koji/compose/atomic/26/",
            'failable': ['*'],
        }
    }),
```

We store our inputs inputs to `rpm-ostree compose tree` in 
the [fedora-atomic](https://pagure.io/fedora-atomic.git) git repo. The 
[fedora-26.repo](https://pagure.io/fedora-atomic/blob/d79a03ecf213843d2cbff2145c88865d3e898183/f/fedora-26.repo) 
file defines the dnf repositories and the 
[fedora-atomic-host.json]([https://pagure.io/fedora-atomic/blob/d79a03ecf213843d2cbff2145c88865d3e898183/f/fedora-atomic-host.json)
file defines which of those repositories to use, which rpms to pull
from them, and a few other things.


## The Installer ISO

For the installer ISO Pungi again calls out to a Koji runroot task. The
command that eventually gets run is a [lorax](https://github.com/rhinstaller/lorax)
command that looks something like this:

```nohighlight
lorax --product=Fedora --version=26 --release=20170705.n.0 \
--source=http://kojipkgs.fedoraproject.org/compose/branched/Fedora-26-20170705.n.0/compose/Everything/x86_64/os \
--variant=Atomic --nomacboot --volid=Fedora-Atomic-ostree-x86_64-26 \
--installpkgs=fedora-productimg-atomic \
--add-template=/mnt/koji/compose/branched/Fedora-26-20170705.n.0/work/x86_64/Atomic/lorax_templates/ostree-based-installer/lorax-configure-repo.tmpl \
--add-template=/mnt/koji/compose/branched/Fedora-26-20170705.n.0/work/x86_64/Atomic/lorax_templates/ostree-based-installer/lorax-embed-repo.tmpl \
--add-template-var=ostree_install_repo=https://kojipkgs.fedoraproject.org/compose/atomic/26/ \
--add-template-var=ostree_update_repo=https://kojipkgs.fedoraproject.org/atomic/26/ \
--add-template-var=ostree_osname=fedora-atomic \
--add-template-var=ostree_install_ref=fedora/26/x86_64/atomic-host \
--add-template-var=ostree_update_ref=fedora/26/x86_64/atomic-host \
--logfile=/mnt/koji/compose/branched/Fedora-26-20170705.n.0/logs/x86_64/Atomic/ostree_installer-1/lorax.log \
--rootfs-size=3 /mnt/koji/compose/branched/Fedora-26-20170705.n.0/work/x86_64/Atomic/ostree_installer
```

From the [installer ISO](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora.conf#_741-761)
part of the Pungi config you can see some configuration that was set
and eventually translated into the lorax command above.

```
ostree_installer = [
    ("^Atomic$", {
        "x86_64": {
            "source_repo_from": "Everything",
            "release": None,
            "rootfs_size": "3",
            "installpkgs": ["fedora-productimg-atomic"],
            "add_template": ["ostree-based-installer/lorax-configure-repo.tmpl",
                             "ostree-based-installer/lorax-embed-repo.tmpl"],
            "add_template_var": [
                "ostree_install_repo=https://kojipkgs.fedoraproject.org/compose/atomic/26/",
                "ostree_update_repo=https://kojipkgs.fedoraproject.org/atomic/26/",
                "ostree_osname=fedora-atomic",
                "ostree_install_ref=fedora/26/x86_64/atomic-host",
                "ostree_update_ref=fedora/26/x86_64/atomic-host",
            ],
            'template_repo': 'https://pagure.io/fedora-lorax-templates.git',
            'template_branch': 'f26',
            'failable': ['*'],
        }
    }),
```

There are a few lorax templates we are passing in as well as some variables
to those templates. The templates are stored in the [fedora-lorax-templates](https://pagure.io/fedora-lorax-templates.git)
git repo.


## The Cloud Images

For the cloud images Koji has higher level support for building
them than it does for the installer ISO or for creating the ostree.
It doesn't need to run things in a runroot, which is generic, but
rather it can create an ImageBuild task to create an image.

This is still all defined in the Pungi config. The `image-build` sections
for Atomic Host are [here](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora.conf#_355-383)
in the Pungi config. One of these sections looks like:

```
	'image-build': {
			'format': [('qcow2','qcow2'), ('raw-xz','raw.xz')],
			'name': 'Fedora-Atomic',
			'kickstart': 'fedora-atomic.ks',
			'distro': 'Fedora-22',
			'disk_size': 6,
			'arches': ['x86_64'],
			'install_tree_from': 'Cloud',
			'subvariant': 'Atomic',
			'failable': ['*'],
	}
```

You'll notice that we say what kickstart file to use, but we don't define
where to pull the kickstart file from. The git repo for the kickstarts is
defined along with a few other varialbes [earlier in the file](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora.conf#_266-271).

# After Fedora Major Release: Bodhi + Pungi + Release

Once Fedora is officially released for a particular version there is a
*release day* yum/dnf repository that is made from the rpms that were
stable on the day of release. This repository is frozen and will not
change.

There are two more repositories that become significant now. These are
the **updates** and the **updates-testing** repositories. The **updates**
repo contains packages that have passed testing and are available to Fedora users
whenever they run `dnf update`. The **updates-testing** repo is for
packages that have been built and have been submitted as an update for
people to test to make sure nothing is broken before graduating to **updates**.
The **updates-testing** repo is not enabled by default. A user would
have to willingly enable it for the purpose of doing testing.

All of that is to say that there are other repos that exist after
release day that are for updated rpms.

## Bodhi

Within Fedora there is a tool known as [Bodhi](https://bodhi.fedoraproject.org/)
that is responsible for tracking what state particular packages are in
and moving them between the **updates** and **updates-testing** repos.
As part of this, Bodhi is currently responsible for creating the
repositories and also the OSTree commits from the new content that
it just created a repo for. Bodhi was the most logical candidate for
this at the time it was implemented because we wanted to create a new
commit as soon as we could grab new content (right after the
repositories are created).

After creating the OSTree content it gets synced to `fedora/26/x86_64/updates/atomic-host`
ref within the OSTree repository at https://kojipkgs.fedoraproject.org/atomic/26/.
This is a global location/ref that users could pull from for existing
installed systems.

## Pungi

When Bodhi runs and creates a new **updates** repo it also creates a
new OSTree. When we do an official two week release we release other
artifacts (ISOs, Qcows, etc) too. These get built once a day and uses the 
[fedora-atomic.conf](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/fedora-atomic.conf)
Pungi config (which gets called from the 
[twoweek-nightly.sh](https://pagure.io/pungi-fedora/blob/392bc7589ecff19e91e03cef34265a270514745e/f/twoweek-nightly.sh)
script). Basically the config creates repos from the `f26-atomic` Koji tag
which inherits from the `f26` tag (release day tag). It creates some 
repos from rpms in the `Cloud` variant and then builds installer
images and qcows based on those rpms. The installer images and the
qcows actually pull the OSTree from the commit that was generated
by the last Bodhi run, though. So the yum/dnf repository created
during the Pungi run only affects the installer, not the installed 
OSTree in the installed systems.

## Performing A Two Week Atomic Host Release

So with the OSTree created by Bodhi and the other artifacts created by
Pungi we can now test do an official two week Atomic Host release.
This is currently run by a member of releng and the process is
documented by [this](https://docs.pagure.org/releng/sop_two_week_atomic.html)
Standard Operating Procedure guide. It eventually tells the operator
to run [this releng script](https://pagure.io/releng/blob/e1fa88d3937412ca0f3c5d166f1b82c5106b1256/f/scripts/push-two-week-atomic.py)
to do the release. The script does several things but most noteworthy
is updating the `fedora/26/x86_64/atomic-host` ref within the OSTree
repo, syncing out the ISOs/qcows to the mirrors, and updating the
[website](https://getfedora.org/atomic/download/).

# Conclusion

Our processes differ slightly for before and after Fedora release.
The entire pipeline involves Koji, Bodhi, and Pungi, and many tools
underneath the covers. There is a lot of working being done to try to improve these
processes including [calling Pungi from Bodhi](https://pagure.io/atomic-wg/issue/300)
in the short term and possibly [building Atomic Host from a Module](https://pagure.io/atomic-wg/issue/312)
in the longer term. Please reach out to us with any questions about
this whole process in #atomic on freenode.
