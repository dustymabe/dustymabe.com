---
title: "Vagrant: Sharing Folders with vagrant-sshfs"
tags:
date: "2016-04-05"
draft: false
---

.. Vagrant: Sharing Folders with vagrant-sshfs
.. ===========================================

*cross posted from this_ fedora magazine post*

.. _this: https://fedoramagazine.org/vagrant-sharing-folders-vagrant-sshfs/

Introduction
------------

We're trying to focus more on developer experience in the Red Hat ecosystem.
In the process we've started to incorporate the Vagrant into our standard 
offerings. As part of that effort, we're seeking a shared folder solution 
that doesn't include a bunch of if/else logic to figure out exactly which 
one you should use based on the OS/hypervisor you use under Vagrant. 

The current options for Vagrant shared folder support can
make you want to tear your hair out when you try to figure out which
one you should use in your environment. This led us to look for a
better answer for the user, so they no longer have to make these
choices on their own based on their environment.

Current Synced Folder Solutions
-------------------------------

"So what is the fuss about? Is it really that hard?" Well it's
certainly doable, but we want it to be easier. Here are the currently 
available synced folder options within vagrant today:

- `virtualbox`_
    - This synced folder type uses a kernel module from the VirtualBox
      Guest Additions software to talk to the hypervisor. It requires 
      you to be running on top of the Virtualbox hypervisor, and that
      the VirtualBox Guest Additions are installed in the Vagrant Box 
      you launch. Licensing can also make distribution of the compiled
      Guest Additions problematic. 
    - Hypervisor Limitation: VirtualBox
    - Host OS Limitation: None
- `nfs`_
    - This synced folder type uses NFS mounts. It requires you to be 
      running on top of a Linux or Mac OS X host.
    - Hypervisor Limitation: None
    - Host OS Limitation: Linux, Mac
- `smb`_
    - This synced folder type uses Samba mounts. It requires you to be
      running on top of a Windows host and to have Samba client
      software in the guest.
    - Hypervisor Limitation: None
    - Host OS Limitation: Windows
- `9p`_
    - This synced folder implementation uses 9p file sharing within
      the libvirt/KVM hypervisor. It requires the hypervisor to be
      libvirt/KVM and thus also requires Linux to be the host OS.
    - Hypervisor Limitation: Libvirt
    - Host OS Limitation: Linux
- `rsync`_
    - This synced folder implementation simply syncs folders between
      host and guest using rsync. Unfortunately this isn't actually
      shared folders, because the files are simply copied back and
      forth and can become out of sync.
    - Hypervisor Limitation: None
    - Host OS Limitation: None

.. _virtualbox: https://www.vagrantup.com/docs/synced-folders/virtualbox.html
.. _nfs: https://www.vagrantup.com/docs/synced-folders/nfs.html
.. _smb: https://www.vagrantup.com/docs/synced-folders/smb.html
.. _9p: https://github.com/pradels/vagrant-libvirt#synced-folders
.. _rsync: https://www.vagrantup.com/docs/synced-folders/rsync.html


So depending on your environment you are rather limited in which
options work. You have to choose carefully to get something working
without much hassle.


What About SSHFS?
-----------------

As part of this discovery process I had a simple question: "why not
**`sshfs`_**?" It turns out that `Fabio Kreusch`_ had a similar idea a while
back and `wrote a plugin`_ to do mounts via SSHFS. 

.. _sshfs: https://github.com/libfuse/sshfs
.. _Fabio Kreusch: https://github.com/fabiokr
.. _wrote a plugin: https://github.com/fabiokr/vagrant-sshfs

When I first found this I was excited because I thought I had the
answer in my hands and someone had already written it! Unfortunately
the old implementation didn't implement a synced folder plugin
like all of the other synced folder plugins within Vagrant. In other
words, it didn't inherit the synced folder class and implement the functions.
It also, by default, mounted a guest folder onto the host rather
than the other way around like most synced folder implementations do.

One goal I have is to actually have SSHFS be a supported synced folder
plugin within Vagrant and possibly get it committed back up into
Vagrant core one day. So I reached out to Fabio to find out if he would 
be willing to accept patches to get things working more along the lines 
of a traditional synced folder plugin. He kindly let me know he 
didn't have much time to work on vagrant-sshfs these days, and he 
no longer used it. I volunteered to take over.


The vagrant-sshfs Plugin
------------------------

To make the plugin follow along the traditional synced folder plugin
model I decided to rewrite the plugin. I based most of the original
code off of the NFS synced folder plugin code. The new code repo is 
`here on Github`_.

.. _here on Github: https://github.com/dustymabe/vagrant-sshfs

So now we have a plugin that will do SSHFS mounts of host folders into
the guest. It works without any setup on the host, but it requires that 
the ``sftp-server`` software exist on the host. ``sftp-server`` is usually 
provided by OpenSSH and thus is easily available on Windows/Mac/Linux.

To compare with the other implementations on environment restrictions
here is what the SSHFS implementation looks like:

- `sshfs`_
    - This synced folder implementation uses SSHFS to share folders
      between host and guest. The only requirement is that the
      ``sftp-server`` executable exist on the host.
    - Hypervisor Limitation: None
    - Host OS Limitation: None

Here are the overall benefits of using ``vagrant-sshfs``:

- Works on any host platform
    - Windows, Linux, Mac OS X
- Works on any type-2 hypervisor
    - VirtualBox, Libvirt/KVM, Hyper-V, VMWare
- Seamlessly Works on Remote Vagrant Solutions
    - Works with vagrant-aws, vagrant-openstack, etc..

Where To Get The Plugin
-----------------------

This plugin is hot off the presses, so it hasn't quite made it into
Fedora yet. There are a few ways you can get it though. First, you can
use Vagrant itself to retrieve the plugin from rubygems::

    $ vagrant plugin install vagrant-sshfs

Alternatively you can get the RPM package from `my copr`_::

    $ sudo dnf copr enable dustymabe/vagrant-sshfs
    $ sudo dnf install vagrant-sshfs

.. _my copr: https://copr.fedorainfracloud.org/coprs/dustymabe/vagrant-sshfs/

Your First vagrant-sshfs Mount
------------------------------

To use use the plugin, you must tell Vagrant what folder you want
mounted into the guest and where, by adding it to your ``Vagrantfile``.
An example ``Vagrantfile`` is below::

    Vagrant.configure(2) do |config|
      config.vm.box = "fedora/23-cloud-base"
      config.vm.synced_folder "/path/on/host", "/path/on/guest", type: "sshfs"
    end

This will start a Fedora 23 base cloud image and will mount the 
``/path/on/host`` directory from the host into the running vagrant box
under the ``/path/on/guest`` directory. 

Conclusion
----------

We've tried to find the option that is easiest for the user to
configure. While SSHFS may have some drawbacks as compared to the
others, such as speed, we believe it solves most people's use 
cases and is dead simple to configure out of the box.

Please give it a try and let us know how it works for you! Drop a mail
to cloud@lists.fedoraproject.org or open an issue on `Github`_.

.. _Github: https://github.com/dustymabe/vagrant-sshfs/issues

| Cheers! 
| Dusty
