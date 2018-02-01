---
title: "802.11ac on Linux With NetGear A6100 (RTL8811AU) USB Adapter"
tags:
date: "2016-01-24"
published: true
---

.. 802.11ac on Linux With NetGear A6100 (RTL8811AU) USB Adapter
.. ============================================================

**UPDATE - 2018-02-01:** I was informed by `@nmccrina`_ that the repo linked to in
this post is no longer maintained. Please use https://github.com/paspro/rtl8812au 
instead.

.. _@nmccrina: https://twitter.com/nmccrina

**NOTE:** Most of the content from this post comes from a `blog post`_ I found
that concentrated on getting the driver set up on Fedora 21. I did
mostly the same steps with a few tweaks.

.. _blog post: https://opensysnotes.wordpress.com/2015/03/09/rtl8812-dkms-driver-install-for-fedora-21/

Intro
-----

Driver support for 802.11ac in Linux is spotty especially if you are
using a USB adapter. I picked up the `NetGear A6100` that has the
Realtek **RTL8811AU** chip inside of it. Of course, when I plug it in I can
see the device, but no support in the kernel I'm using (kernel-4.2.8-200.fc22.x86_64). 

On my system I currently have the built in wireless adapter, as well
as the USB plugged in. From the output below you can see only one wireless
NIC shows up::

    # lspci | grep Network
    00:19.0 Ethernet controller: Intel Corporation 82579LM Gigabit Network Connection (rev 04)
    03:00.0 Network controller: Intel Corporation Centrino Ultimate-N 6300 (rev 3e)
    $ lsusb | grep NetGear
    Bus 001 Device 002: ID 0846:9052 NetGear, Inc. A6100 AC600 DB Wireless Adapter [Realtek RTL8811AU]
    # ip -o link | grep wlp | cut -d ' ' -f 2
    wlp3s0:

The ``wlp3s0`` is my built in wifi device.


The Realtek Driver
------------------

You can find the Realtek driver for the **RTL8811AU** at a couple of
the sites for the many_ vendors that incorporate the chip:

    - Archer T4UH
        - `product page <http://www.tp-link.se/download/Archer-T4UH.html#Driver>`_
        - `download link <http://www.tp-link.se/res/down/soft/Archer_T4UH_V1_150821.zip>`_
    - D-Link DWA-182
        - `product page <http://support.dlink.com/ProductInfo.aspx?m=DWA-182>`_
        - `download link <ftp://ftp2.dlink.com/PRODUCTS/DWA-182/REVC/DWA-182_REVC_DRIVER_4.3.2_LINUX.ZIP>`_

.. _many: https://wikidevi.com/w/index.php?title=Special:Ask&offset=0&limit=500&q=%5B%5BChip1+model%3A%3ARTL8812AU%5D%5D&p=format%3Dbroadtable%2Flink%3Dall%2Fheaders%3Dshow%2Fsearchlabel%3D%E2%80%A6-20further-20results%2Fclass%3Dsortable-20wikitable-20smwtable&po=%3FInterface%0A%3FForm+factor%3DFF%0A%3FInterface+connector+type%3DUSB+conn.%0A%3FFCC+ID%0A%3FManuf%0A%3FManuf+product+model%3DManuf.+mdl%0A%3FVendor+ID%0A%3FDevice+ID%0A%3FChip1+model%0A%3FSupported+802dot11+protocols%3DPHY+modes%0A%3FMIMO+config%0A%3FOUI%0A%3FEstimated+year+of+release%3DEst.+year%0A&order=ASC&eq=yes

These drivers often vary in version and often don't compile on newer
kernels, which can be frustrating when you just want something to
work.


Getting The RTL8811AU Driver Working
------------------------------------

Luckily some people in the community unofficially manage code repositories 
with fixes to the Realtek driver to allow it to compile on newer
kernels. From the `blog post` I mentioned earlier there is a linked
`GitHub repository`_ where the Realtek driver is reproduced with some
patches on top. This repository makes it pretty easy to get set up and
get the USB adapters working on Linux.

.. _GitHub repository: https://github.com/Grawp/rtl8812au_rtl8821au

**NOTE:** In case the git repo moves in the future I have copied an
archive of it here_ for posterity. The commit id at head at the time
of this use is ``9fc227c2987f23a6b2eeedf222526973ed7a9d63``.

.. _here: /2016-01-24/rtl8812au_rtl8821au-master.zip

The first step is to set up your system for DKMS_ to make it so that
you don't have to recompile the kernel module every time you install a
new kernel. To do this install the following packages and set the
`dkms` service to start on boot::

    # dnf install -y dkms kernel-devel-$(uname -r)
    # systemctl enable dkms

.. _DKMS: https://en.wikipedia.org/wiki/Dynamic_Kernel_Module_Support

Next, clone the git repository and observe the version of the driver:: 

    # mkdir /tmp/rtldriver && cd /tmp/rtldriver
    # git clone https://github.com/Grawp/rtl8812au_rtl8821au.git
    # cat rtl8812au_rtl8821au/include/rtw_version.h 
    #define DRIVERVERSION   "v4.3.14_13455.20150212_BTCOEX20150128-51"
    #define BTCOEXVERSION   "BTCOEX20150128-51"

From the output we can see this is the ``4.3.14_13455.20150212``
version of the driver, which is fairly recent.

Next let's create a directory under ``/usr/src`` for the source code to
live and copy it into place::

    # mkdir /usr/src/8812au-4.3.14_13455.20150212
    # cp -R  ./rtl8812au_rtl8821au/* /usr/src/8812au-4.3.14_13455.20150212/

Next we'll create a `dkms.conf` file which will tell `DKMS` how to
manage building this module when builds/installs are requested; run
`man dkms` to view more information on these settings::

    # cat <<'EOF' > /usr/src/8812au-4.3.14_13455.20150212/dkms.conf
    PACKAGE_NAME="8812au"
    PACKAGE_VERSION="4.3.14_13455.20150212"
    BUILT_MODULE_NAME[0]="8812au"
    DEST_MODULE_LOCATION[0]="/kernel/drivers/net/wireless"
    AUTOINSTALL="yes"
    MAKE[0]="'make' all KVER=${kernelver}"
    CLEAN="'make' clean"
    EOF

Note one change from the earlier blog post, which is that I include 
``KVER=${kernelver}`` in the make line. If you don't do this then the
``Makefile`` will incorrectly detect the kernel by calling
``uname``, which is wrong when run during a new kernel installation
because the new kernel is not yet running. If we didn't do this then
every time a new kernel was installed the driver would get compiled for
the previous kernel (the one that was running at the time of
installation).

The next step is to add the module to the `DKMS` system and go ahead
and build it::

    # dkms add -m 8812au -v 4.3.14_13455.20150212

    Creating symlink /var/lib/dkms/8812au/4.3.14_13455.20150212/source ->
                     /usr/src/8812au-4.3.14_13455.20150212

    DKMS: add completed.
    # dkms build -m 8812au -v 4.3.14_13455.20150212

    Kernel preparation unnecessary for this kernel.  Skipping...

    Building module:
    cleaning build area...
    'make' all KVER=4.2.8-200.fc22.x86_64......................
    cleaning build area...

    DKMS: build completed.


And finally install it::

    # dkms install -m 8812au -v 4.3.14_13455.20150212

    8812au:
    Running module version sanity check.
     - Original module
       - No original module exists within this kernel
     - Installation
       - Installing to /lib/modules/4.2.8-200.fc22.x86_64/extra/
    Adding any weak-modules

    depmod....

    DKMS: install completed.


Now we can load the module and see information about it::

    # modprobe 8812au
    # modinfo 8812au | head -n 3
    filename:       /lib/modules/4.2.8-200.fc22.x86_64/extra/8812au.ko
    version:        v4.3.14_13455.20150212_BTCOEX20150128-51
    author:         Realtek Semiconductor Corp.


Does the wireless NIC work now? After connecting to an AC only 
network here are the results::

    # ip -o link | grep wlp | cut -d ' ' -f 2
    wlp3s0:
    wlp0s20u2:
    # iwconfig wlp0s20u2
    wlp0s20u2  IEEE 802.11AC  ESSID:"random"  Nickname:"<WIFI@REALTEK>"
              Mode:Managed  Frequency:5.26 GHz  Access Point: A8:BB:B7:EE:B6:8D   
              Bit Rate:87 Mb/s   Sensitivity:0/0  
              Retry:off   RTS thr:off   Fragment thr:off
              Encryption key:****-****-****-****-****-****-****-****   Security mode:open
              Power Management:off
              Link Quality=95/100  Signal level=100/100  Noise level=0/100
              Rx invalid nwid:0  Rx invalid crypt:0  Rx invalid frag:0
              Tx excessive retries:0  Invalid misc:0   Missed beacon:0

Sweet!!

Keeping it Working After Kernel Updates
---------------------------------------

Let's test out to see if updating a kernel leaves us with a system that
has an updated driver or not. Before the kernel update::

    # tree /var/lib/dkms/8812au/4.3.14_13455.20150212/
    /var/lib/dkms/8812au/4.3.14_13455.20150212/
    ├── 4.2.8-200.fc22.x86_64
    │   └── x86_64
    │       ├── log
    │       │   └── make.log
    │       └── module
    │           └── 8812au.ko
    └── source -> /usr/src/8812au-4.3.14_13455.20150212

    5 directories, 2 files

Now the kernel update and viewing it after::

    # dnf -y update kernel kernel-devel --enablerepo=updates-testing
    ...
    Installed:
      kernel.x86_64 4.3.3-200.fc22
      kernel-core.x86_64 4.3.3-200.fc22
      kernel-devel.x86_64 4.3.3-200.fc22
      kernel-modules.x86_64 4.3.3-200.fc22

    Complete!
    # tree /var/lib/dkms/8812au/4.3.14_13455.20150212/
    /var/lib/dkms/8812au/4.3.14_13455.20150212/
    ├── 4.2.8-200.fc22.x86_64
    │   └── x86_64
    │       ├── log
    │       │   └── make.log
    │       └── module
    │           └── 8812au.ko
    ├── 4.3.3-200.fc22.x86_64
    │   └── x86_64
    │       ├── log
    │       │   └── make.log
    │       └── module
    │           └── 8812au.ko
    └── source -> /usr/src/8812au-4.3.14_13455.20150212

    9 directories, 4 files

And from the log we can verify that the module was built against the right
kernel::

    # head -n 4 /var/lib/dkms/8812au/4.3.14_13455.20150212/4.3.3-200.fc22.x86_64/x86_64/log/make.log
    DKMS make.log for 8812au-4.3.14_13455.20150212 for kernel 4.3.3-200.fc22.x86_64 (x86_64)
    Sun Jan 24 19:40:51 EST 2016
    make ARCH=x86_64 CROSS_COMPILE= -C /lib/modules/4.3.3-200.fc22.x86_64/build M=/var/lib/dkms/8812au/4.3.14_13455.20150212/build  modules
    make[1]: Entering directory '/usr/src/kernels/4.3.3-200.fc22.x86_64'

Success!
