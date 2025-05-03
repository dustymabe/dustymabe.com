---
title: "Fedora 22 Updates-Testing Atomic Tree"
tags:
date: "2015-06-23"
draft: false
---

.. Fedora 22 Updates-Testing Atomic Tree
.. =====================================

It has generally been difficult to test new updates for the
``rpm-ostree`` or ``ostree`` packages for Atomic Host. This is because in
the past you had to build your own tree in order to test them.
Now, however, Fedora has starting building a tree based off the
*updates-testing* yum repositories. This means that you can easily
test updates by simply running Fedora Atomic Host and rebasing to the
``fedora-atomic/f22/x86_64/testing/docker-host`` ref::

    # rpm-ostree rebase fedora-atomic:fedora-atomic/f22/x86_64/testing/docker-host
    # reboot

After reboot you are now (*hopefully*) booted into the tree with
updates baked in. You can do your tests and report your results back
upstream. If you ever want to go back to following the stable branch
then you can do that by running::

    # rpm-ostree rebase fedora-atomic:fedora-atomic/f22/x86_64/docker-host
    # reboot

Testing updates this way can apply to any of the packages within
Atomic Host. Since Atomic Host has a small footprint the package you want to
test might not be included, but if it is then this is a
great way to test things out.

| Dusty
