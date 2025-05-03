---
title: "Fedora Cloud Vagrant Boxes in Atlas"
tags:
date: "2015-11-08"
draft: false
---

.. Fedora Cloud Vagrant Boxes in Atlas 
.. ===================================

*Cross posted with this_ fedora magazine post*

.. _this: https://fedoramagazine.org/fedora-cloud-vagrant-boxes-atlas/

Since the release of Fedora 22, Fedora began creating Vagrant boxes
for cloud images in order to make it easier to set up a local
environment for development or testing.
In the Fedora 22 release cycle we worked out quite a
few kinks and we are again releasing *libvirt* and *virtualbox* Vagrant
boxes for Fedora 23. 

Additionally, for Fedora 23, we are making it easier for the users
to grab these boxes by having them indexed in Hashicorp's Atlas_. 
Atlas is essentially an index of Vagrant boxes that makes it easy to 
distribute them (think of it like a Docker registry for virtual machine images).
By indexing the Fedora boxes in Atlas, users now have the option of using
the ``vagrant`` software to download and add the boxes automatically, rather than 
the user having to go grab the boxes directly from the mirrors_ first (although this is 
still an option).

.. _Atlas: https://atlas.hashicorp.com/fedora
.. _mirrors: https://download.fedoraproject.org/pub/fedora/linux/releases/23/Cloud/x86_64/Images/

In order to get started with the Fedora cloud base image, run the
following command::

    # vagrant init fedora/23-cloud-base && vagrant up

Alternatively, to get started with Fedora Atomic host, run this
command::

    # vagrant init fedora/23-atomic-host && vagrant up

The above commands will grab the latest indexed images in Atlas and
start a virtual machine without the user having to go download the image first. 
This will make it easier for Fedora users to develop and
test on Fedora! If you haven't delved into Vagrant yet then you can get started
by visiting the `Vagrant page`_ on the `Fedora Developer Portal`_.
Let us know on the Fedora Cloud `mailing list`_ if you have any trouble. 

.. _Vagrant page: https://developer.fedoraproject.org/tools/vagrant/about.html
.. _Fedora Developer Portal: https://developer.fedoraproject.org/
.. _mailing list: https://admin.fedoraproject.org/mailman/listinfo/cloud

Dusty
