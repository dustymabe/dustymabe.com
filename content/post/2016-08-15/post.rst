---
title: "None"
tags: [ "1", "2" ]
date: "2012-02-09"
published: false
---

.. Booting Lenovo T460s after Fedora 24 Updates
.. ============================================

Introduction
------------

I recently picked up a new Lenovo T460s work laptop. It is fairly
light and has 20G of memory, which is great for running Virtual
Machines. One of the first things I did on this new laptop was install
Fedora 24 onto the system. After installing from the install media I
was up and running and humming along. 

Soon after installing I updated the system to get all bugfixes and
security patches. I updated everything and rebooted and::

    Probing EDD (edd=off to disable)... OK

Yep, the system wouldn't even boot. The GRUB menu would appear and you
could select different entries, but the system would not boot.

The Problem
-----------

It was time to hit the internet. After some futile attempts on Google 
searches I decided to ask on Fedora's `devel list`_. I got a quick 
response that led to two bug reports (1351943_, 1353103_) about the 
issue. It turns out that the newer kernel + microcode that we had updated
to had some sort of incompatibility with the existing system firmware.
According to the comments from 1353103_ there was most likely an assumption
the microcode was making that wasn't true.

.. _devel list: https://lists.fedoraproject.org/archives/list/devel@lists.fedoraproject.org/message/ODBVB4UWXNKPYB4YOR2BH5VVWGUCG5DB/
.. _1351943: https://bugzilla.redhat.com/show_bug.cgi?id=1351943
.. _1353103: https://bugzilla.redhat.com/show_bug.cgi?id=1353103

The Solution
------------

The TL;DR on the fix for this is that you need to update the BIOS on
the T460s. I did this by going to the T460s support page (at the time of this
writing the link is here_) and downloading the ISO image with
the BIOS update (n1cur06w.iso). 

.. _here: https://support.lenovo.com/us/en/products/Laptops-and-netbooks/ThinkPad-T-Series-laptops/ThinkPad-T460s?LinkTrack=Solr

Now what was I going to do with an ISO image? The laptop doesn't have
a cd-rom drive, so burning a cd wouldn't help us one bit. There is a
`helpful article` about how to take this ISO image and update the BIOS. 

.. _helpful article: https://workaround.org/article/updating-the-bios-on-lenovo-laptops-from-linux-using-a-usb-flash-stick/

Here are the steps that I took.

- First, boot the laptop into the older kernel so you can actually get
  to a Linux environment. 
  
- Next, install the geteltorito software so that we can create an image to
  ``dd`` onto the USB key

::

    $ sudo dnf install geteltorito 

- Next use the software to create the image and write it to a flash
  drive. Note, ``/dev/sdg`` wsa the USB key on my system. Please be
  sure to change that to the device corresponding to your USB key.

::

    $ geteltorito -o bios.img n1cur06w.iso 
    Booting catalog starts at sector: 20 
    Manufacturer of CD: NERO BURNING ROM
    Image architecture: x86
    Boot media type is: harddisk
    El Torito image starts at sector 27 and has 47104 sector(s) of 512 Bytes

    Image has been written to file "bios.img".

    $
    $ sudo dd if=bios.img of=/dev/sdg bs=1M
    23+0 records in
    23+0 records out
    24117248 bytes (24 MB, 23 MiB) copied, 1.14576 s, 21.0 MB/s


- Next, reboot the laptop. 

- After the Lenovo logo appears press ENTER.

- Press F12 to make your laptop boot from something else than your HDD.

- Select the USB stick.

- Make sure your laptop has its power supply plugged in. (It will refuse
  to update otherwise.)

- Follow the instructions.

- Select number 2: Update system program

- Once finished reboot the laptop and remove the USB key.


Done! I was now happily booting Fedora again. I hope this helps others who hit the same problem!

| - Dusty

