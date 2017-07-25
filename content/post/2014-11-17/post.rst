---
title: "None"
tags: [ "1", "2" ]
date: "2012-02-09"
published: false
---

Test steps for atomic
=====================

Below are some steps to roughly test an atomic host from Project Atomic.


Booting with cloud-init
-----------------------

First step is to start an atomic host using any method/cloud provider
you like. For me I decided to use openstack since I have Juno running
on F21 here in my apartment. I used this user-data for the atomic
host::

    #cloud-config
    password: passw0rd
    chpasswd: { expire: False }
    ssh_pwauth: True
    runcmd:
     - [ sh, -c, 'echo -e "ROOT_SIZE=4G\nDATA_SIZE=10G" > /etc/sysconfig/docker-storage-setup']

Note that the build of atomic I used for this testing resides
`here <https://kojipkgs.fedoraproject.org//work/tasks/8904/8118904/Fedora-Cloud-Atomic-20141112-21.x86_64.qcow2>`_


Verifying docker-storage-setup
------------------------------

**docker-storage-setup** is a service that can be used to configure the 
storage configuration for docker in different ways on instance
bringup. Notice in the user-data above that I decided to set config variables for
**docker-storage-setup**. They basically mean that I want to resize my
**atomicos/root** LV to 4G and I want to create an
**atomicos/docker-data** LV and make it 10G in size.

To verify the storage was set up successfully, log in (as the fedora user) 
and become root (usind sudo su -). Now you can check if **docker-storage-setup**
worked by checking the logs as well as looking at the output from
**lsblk**::

    # journalctl -o cat --unit docker-storage-setup.service
    CHANGED: partition=2 start=411648 old: size=12171264 end=12582912 new: size=41531232,end=41942880
    Physical volume "/dev/vda2" changed
    1 physical volume(s) resized / 0 physical volume(s) not resized
    Size of logical volume atomicos/root changed from 1.95 GiB (500 extents) to 4.00 GiB (1024 extents).
    Logical volume root successfully resized
    Rounding up size to full physical extent 24.00 MiB
    Logical volume "docker-meta" created
    Logical volume "docker-data" created
    #
    # lsblk
    NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    vda                       252:0    0   20G  0 disk 
    ├─vda1                    252:1    0  200M  0 part /boot
    └─vda2                    252:2    0 19.8G  0 part 
      ├─atomicos-root         253:0    0    4G  0 lvm  /sysroot
      ├─atomicos-docker--meta 253:1    0   24M  0 lvm  
      └─atomicos-docker--data 253:2    0   10G  0 lvm


Verifying Docker Lifecycle
--------------------------

To verify Docker runs fine on the atomic host we will perform a simple
run of the busybox docker image. This will contact the docker hub, pull down the
image, and run /bin/true::

    # docker run -it --rm busybox true && echo "PASS" || echo "FAIL"
    Unable to find image 'busybox' locally
    Pulling repository busybox
    e72ac664f4f0: Download complete 
    511136ea3c5a: Download complete 
    df7546f9f060: Download complete 
    e433a6c5b276: Download complete 
    PASS

After the Docker daemon has started the LVs that were created by **docker-storage-setup**
will be used by device mapper as shown in the **lsblk** output below::

    # lsblk
    NAME                              MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    vda                               252:0    0   20G  0 disk 
    ├─vda1                            252:1    0  200M  0 part /boot
    └─vda2                            252:2    0 19.8G  0 part 
      ├─atomicos-root                 253:0    0    4G  0 lvm  /sysroot
      ├─atomicos-docker--meta         253:1    0   24M  0 lvm  
      │ └─docker-253:0-6298462-pool   253:3    0   10G  0 dm   
      │   └─docker-253:0-6298462-base 253:4    0   10G  0 dm   
      └─atomicos-docker--data         253:2    0   10G  0 lvm  
        └─docker-253:0-6298462-pool   253:3    0   10G  0 dm   
          └─docker-253:0-6298462-base 253:4    0   10G  0 dm


Atomic Host: Upgrade
--------------------

Now on to an atomic upgrade. First let's check what commit we are currently at
and store a file in **/etc/file1** to save it for us::

    # rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME                 REFSPEC
    * 2014-11-12 22:28:04     1877f1fa64     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host     
    # 
    # ostree admin status
    * fedora-atomic-host 1877f1fa64be8bec8adcd43de6bd4b5c39849ec7842c07a6d4c2c2033651cd84.0
        origin refspec: fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    # 
    # cat /ostree/repo/refs/heads/ostree/0/1/0
    1877f1fa64be8bec8adcd43de6bd4b5c39849ec7842c07a6d4c2c2033651cd84
    # 
    # cat /ostree/repo/refs/heads/ostree/0/1/0 > /etc/file1


Now run an upgrade to the latest atomic compose::

    # rpm-ostree upgrade
    Updating from: fedora-atomic:fedora-atomic/f21/x86_64/docker-host

    14 metadata, 19 content objects fetched; 33027 KiB transferred in 16 seconds
    Copying /etc changes: 26 modified, 4 removed, 39 added
    Transaction complete; bootconfig swap: yes deployment count change: 1)
    Updates prepared for next boot; run "systemctl reboot" to start a reboot


And do a bit of poking around right before we reboot::

    # rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME                 REFSPEC                                                
      2014-11-13 10:52:06     18e02c4166     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host     
    * 2014-11-12 22:28:04     1877f1fa64     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host     
    # 
    # ostree admin status
      fedora-atomic-host 18e02c41666ef5f426bc43d01c4ce1b7ffc0611e993876cf332600e2ad8aa7c0.0
        origin refspec: fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    * fedora-atomic-host 1877f1fa64be8bec8adcd43de6bd4b5c39849ec7842c07a6d4c2c2033651cd84.0
        origin refspec: fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    #
    # reboot

.. note:: The * in the above output indicates which tree is currently booted.

After reboot now the new tree should be booted. Let's check things out and make
**/etc/file2** with our new commit hash in it::

    # rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME                 REFSPEC                                                
    * 2014-11-13 10:52:06     18e02c4166     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host     
      2014-11-12 22:28:04     1877f1fa64     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host     
    # 
    # ostree admin status
    * fedora-atomic-host 18e02c41666ef5f426bc43d01c4ce1b7ffc0611e993876cf332600e2ad8aa7c0.0
        origin refspec: fedora-atomic:fedora-atomic/f21/x86_64/docker-host
      fedora-atomic-host 1877f1fa64be8bec8adcd43de6bd4b5c39849ec7842c07a6d4c2c2033651cd84.0
        origin refspec: fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    # 
    # cat /ostree/repo/refs/heads/ostree/1/1/0
    18e02c41666ef5f426bc43d01c4ce1b7ffc0611e993876cf332600e2ad8aa7c0
    # 
    # cat /ostree/repo/refs/heads/ostree/1/1/0 > /etc/file2


As one final item let's boot up a docker container to make sure things still work there::

    # docker run -it --rm busybox true && echo "PASS" || echo "FAIL"
    PASS


Atomic Host: Rollback
--------------------

Atomic host provides the ability to revert to the previous working tree if things go
awry with the new tree. Lets revert our upgrade now and make sure things still work::

    # rpm-ostree rollback
    Moving '1877f1fa64be8bec8adcd43de6bd4b5c39849ec7842c07a6d4c2c2033651cd84.0' to be first deployment
    Transaction complete; bootconfig swap: yes deployment count change: 0)
    Sucessfully reset deployment order; run "systemctl reboot" to start a reboot
    #
    # rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME                 REFSPEC                                                
      2014-11-12 22:28:04     1877f1fa64     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host     
    * 2014-11-13 10:52:06     18e02c4166     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    #
    # reboot

After reboot::

    # rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME                 REFSPEC                                                
    * 2014-11-12 22:28:04     1877f1fa64     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host     
      2014-11-13 10:52:06     18e02c4166     fedora-atomic-host     fedora-atomic:fedora-atomic/f21/x86_64/docker-host     
    # 
    # cat /etc/file1 
    1877f1fa64be8bec8adcd43de6bd4b5c39849ec7842c07a6d4c2c2033651cd84
    # cat /etc/file2
    cat: /etc/file2: No such file or directory

Notice that **/etc/file2** did not exist until after the upgrade so it did not persist during 
the rollback.

And the final item on the list is to make sure Docker still works::

    # docker run -it --rm busybox true && echo "PASS" || echo "FAIL"
    PASS
    
Anddd Boom.. You have just put atomic through some paces. 
