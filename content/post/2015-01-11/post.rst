---
title: "qemu-img Backing Files: A Poor Man's Snapshot/Rollback"
tags:
date: "2015-01-11"
draft: false
url: "/2015/01/11/qemu-img-backing-files-a-poor-mans-snapshotrollback/"
---

.. qemu-img Backing Files: A Poor Man's Snapshot/Rollback
.. ======================================================


I often like to formulate detailed steps when trying to reproduce a bug or a
working setup. VMs are great for this because they can be manipulated easily. 
To manipulate their disk images I use ``qemu-img`` to create new disk images
that use other disk images as a *backing store*. This is what I like to call a
*"poor man's"* way to do snapshots because the snapshotting process is a bit manual,
but that is also why I like it; I don't touch the original disk image at all so 
I have full confidence I haven't compromised it. 

**NOTE**: I use QEMU/KVM/Libvirt so those are the tools used in this example:


Taking A Snapshot
-----------------

In order to take a snapshot you should first shutdown the VM and then simply 
create a new disk image that uses the original disk image as a *backing store*::


    $ sudo virsh shutdown F21server
    Domain F21server is being shutdown
    $ sudo qemu-img create -f qcow2 -b /guests/F21server.img /guests/F21server.qcow2.snap
    Formatting '/guests/F21server.qcow2.snap', fmt=qcow2 size=21474836480 backing_file='/guests/F21server.img' encryption=off cluster_size=65536 lazy_refcounts=off


This new disk image is a COW snapshot of the original image, which means any 
writes will go into the new image but any reads of non-modified blocks will be 
read from the original image. A benefit of this is that the size of the new file 
will start off at 0 and increase only as modifications are made.

To get the virtual machine to pick up and start using the new COW disk image
we will need to modify the libvirt XML to point it at the new file::

    $ sudo virt-xml F21server --edit target=vda --disk driver_type=qcow2,path=/guests/F21server.qcow2.snap --print-diff
    --- Original XML
    +++ Altered XML
    @@ -27,8 +27,8 @@
       <devices>
         <emulator>/usr/bin/qemu-kvm</emulator>
         <disk type="file" device="disk">
    -      <driver name="qemu" type="raw"/>
    -      <source file="/guests/F21server.img"/>
    +      <driver name="qemu" type="qcow2"/>
    +      <source file="/guests/F21server.qcow2.snap"/>
           <target dev="vda" bus="virtio"/>
           <address type="pci" domain="0x0000" bus="0x00" slot="0x07" function="0x0"/>
         </disk>
    $ 
    $ sudo virt-xml F21server --edit target=vda --disk driver_type=qcow2,path=/guests/F21server.qcow2.snap
    Domain 'F21server' defined successfully.


You can now start your VM and make changes as you wish. Be destructive if
you like; the original disk image hasn't been touched. 

After making a few changes I had around 15M of differences between the original
image and the snapshot::

    $ du -sh /guests/F21server.img 
    21G     /guests/F21server.img
    $ du -sh /guests/F21server.qcow2.snap 
    15M     /guests/F21server.qcow2.snap


Going Back
----------

To go back to the point you started you must first delete the file that you
created (``/guests/F21server.qcow2.snap``) and then you have two options:

- Again create a disk image using the origin as a backing file.
- Go back to using the original image.

If you want to continue testing and going back to your starting point then you 
will want to delete and recreate the COW snapshot disk image::

    $ sudo rm /guests/F21server.qcow2.snap 
    $ sudo qemu-img create -f qcow2 -b /guests/F21server.img /guests/F21server.qcow2.snap
    Formatting '/guests/F21server.qcow2.snap', fmt=qcow2 size=21474836480 backing_file='/guests/F21server.img' encryption=off cluster_size=65536 lazy_refcounts=off 

If you want to go back to your original setup then we'll also need to change back
the xml to what it was before::

    $ sudo rm /guests/F21server.qcow2.snap 
    $ sudo virt-xml F21server --edit target=vda --disk driver_type=raw,path=/guests/F21server.img
    Domain 'F21server' defined successfully.


Committing Changes
------------------

If you happen to decide that the changes you have made are some that you want
to carry forward then you can commit the changes in the COW disk image 
into the backing disk image. In the case below I have 15M worth of changes that 
get committed back into the original image. I then edit the xml accordingly and
can start the guest with all the changes baked back into the original disk
image::

    $ sudo qemu-img info /guests/F21server.qcow2.snap
    image: /guests/F21server.qcow2.snap
    file format: qcow2
    virtual size: 20G (21474836480 bytes)
    disk size: 15M
    cluster_size: 65536
    backing file: /guests/F21server.img
    $ sudo qemu-img commit /guests/F21server.qcow2.snap
    Image committed.
    $ sudo rm /guests/F21server.qcow2.snap
    $ sudo virt-xml F21server --edit target=vda --disk driver_type=raw,path=/guests/F21server.img
    Domain 'F21server' defined successfully.


Fin
---

This *backing file* approach is useful because it's much more 
convenient than making multiple copies of huge disk image files, but it can be
used for much more than just snapshotting/reverting changes. It can 
also be used to start 100 virtual machines from a common backing image, thus
saving space...etc.. Go ahead and try it!  

| Happy Snapshotting!
| Dusty
