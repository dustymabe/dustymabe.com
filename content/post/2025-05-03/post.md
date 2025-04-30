---
title: "Transferring files over a serial connection"
tags: [ serial ]
date: "2025-05-03"
draft: false
---

# Problem

Sometimes you just don't have a stable (or even functioning network) to
leverage when dealing with a piece of hardware. In all my years in
Linux admin/development I've always worked around this problem with
some sort of [sneakernet](https://en.wikipedia.org/wiki/Sneakernet),
but there is another way.

Typically when bringing up new hardware one of the most basic
interfaces you have is a serial console connection and I just learned
recently how to transfer files over that serial console connection
rather than requiring a net (tcp/ip) connection.

This can be extremely useful in cases where you've got something
booting, but not quite fully functional. i.e. you're up, but no
network driver.


# Transferring a file over serial

For connecting over serial I've been using [`tio`](https://tio.github.io/)
the past few years as it's a really good serial console client and it
just so happens to support `XMODEM` and `YMODEM` protocols as well. You
can use your existing serial console connection to the machine to send
files this way, but the client does need a piece of software installed
on it on the other side to receive the files.

The [`lrzsz`](http://www.ohse.de/uwe/software/lrzsz.html) software can do
this for us. In Fedora this is provided by the `lrzsz` package. With this
installed and a serial connection active to the remote machine I can
initiate a file transfer using the `rx` command (run on the remote
machine via the serial connection).

Let's first connect via `tio` to the remote machine in question:

```
$ sudo tio -b 115200 /dev/ttyUSB0
Fedora CoreOS 42.20250422.dev.0
Kernel 6.13.0-0.rc4.36.0.riscv64.fc42.riscv64 on riscv64 (ttyS0)

SSH host key: SHA256:jcmPJrfPDiOKw6vJYv5FRar28WvXEr2ptP+HqYX8V0k (ECDSA)
SSH host key: SHA256:/984ZL7Usjje/nWN8xvc4plOC9d7IWo/mL+fT0zkmvE (ED25519)
SSH host key: SHA256:lSoNDXDl2Bz0s2M5xLmwzODmEqVanQDeHBYQOGVCsJw (RSA)
Ignition: ran on 2025/02/16 00:00:39 UTC (this boot)
Ignition: user-provided config was applied
Ignition: wrote ssh authorized keys file for user: core
localhost login: core
Password:

[core@localhost ~]$
```


Let's check that the receiving software is in place:

```
[core@localhost]$ rpm -q lrzsz
lrzsz-0.12.20-74.fc42.riscv64
```

Now we can start the receiver. In this case what I wanted to do was
transfer a new version of `u-boot` over to the target device in order
to flash it to the SPI (so the new version of `u-boot` would be used
for future boots:

```
[core@localhost]$ rx -b -c ./u-boot.itb

rx: ready to receive ./u-boot.itb
CCCCCC
```

The `CCC` are indicators that the software is waiting for the transfer
to start.

On the `tio` side we can `CTRL-t x` to start a transfer. It will ask
you what XMODEM strategy you want to use for the transfer. I just
selected `0` for `XMODEM-1K send` and then chose a file to transfer:

```
[10:40:15.915] Please enter which X modem protocol to use:
[10:40:15.915]  (0) XMODEM-1K send
[10:40:15.915]  (1) XMODEM-CRC send
[10:40:15.915]  (2) XMODEM-CRC receive
[10:40:16.535] Send file with XMODEM-1K
[10:40:22.211] Sending file '/var/b/images/star64/usr/share/uboot/starfive_visionfive2/u-boot.itb'
[10:40:22.211] Press any key to abort transfer
................................................................||
[10:42:12.159] Done
[core@localhost ~]$
```

Now with the file transferred I wanted to validate the transfer using
the checksum:

```
[core@localhost]$ sha256sum u-boot.itb
2ebb46c5317e7eb9a8b85b8de1764a58c10805d00e72bd919d741b9b7010a7b8  u-boot.itb
```

Unfortunately this didn't match the checksum from my host machine:

```
$ sha256sum /var/b/images/star64/usr/share/uboot/starfive_visionfive2/u-boot.itb
fbb89649445f03b277eadc0953cc87b94bdbf2aba130ce6bfeb9702b87794a18  /var/b/images/star64/usr/share/uboot/starfive_visionfive2/u-boot.itb
```

It looks like when transferring it just pads to a 1K boundary for the
file because the size on my host was `1142139`:

```
$ ls -l /var/b/images/star64/usr/share/uboot/starfive_visionfive2/u-boot.itb
-rw-r--r--. 1 dustymabe dustymabe 1142139 Apr 26 16:58 /var/b/images/star64/usr/share/uboot/starfive_visionfive2/u-boot.itb
```

Where the size on the remote was `1142784`:

```
[core@localhost footmp]$ ls -l u-boot.itb
-rw-------. 1 core core 1142784 Apr 29 14:42 u-boot.itb
```

Truncating the file back down to the right size gave me the correct
checksum:

```
[core@localhost]$ truncate -s 1142139 u-boot.itb
[core@localhost]$ ls -l u-boot.itb
-rw-------. 1 core core 1142139 Apr 29 14:52 u-boot.itb
[core@localhost]$ sha256sum u-boot.itb
fbb89649445f03b277eadc0953cc87b94bdbf2aba130ce6bfeb9702b87794a18  u-boot.itb
```

And there the file has been transferred over a serial connection!
