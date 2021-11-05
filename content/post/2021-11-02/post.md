---
title: 'Running FCOS on your Raspberry Pi 4'
author: dustymabe
date: 2021-11-02
tags: [ coreos fedora aarch64 ]
published: true
---

Note: A more permanent version of this tutorial exists in the [Fedora CoreOS documentation](https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-raspberry-pi4/).

Fedora CoreOS recently started producing 64-bit ARM (`aarch64`) artifacts. These images can be used as the Operating System for the Raspberry Pi 4 device. Before trying to get FCOS up and running on your Raspberry Pi4 you'll want to [Update the EEPROM](#Updating-EEPROM-on-Raspberry-Pi4) to the latest version and choose how you want to boot the Raspberry Pi 4. There are two options:

- [Installing FCOS and Booting via U-Boot](#Installing-FCOS-and-Booting-via-U-Boot)
- [Installing FCOS and Booting via UEFI](#Installing-FCOS-and-Booting-via-UEFI)

U-Boot is the way the Raspberry Pi 4 has traditionally been booted. The [UEFI Firmware](https://rpi4-uefi.dev/about/) is an effort to provide a layer that will make RPi4 ServerReady (SBBC compliant) similar to most larger 64-bit ARM servers.

## Updating EEPROM on Raspberry Pi 4 {#Updating-EEPROM-on-Raspberry-Pi4}

The Raspberry Pi 4 uses an EEPROM to boot the system. For the best experience getting FCOS to run on the RPi4 please update the EEPROM to the latest version. To check if you have the latest version you can go to the [raspberrypi/rpi-eeprom releases page](https://github.com/raspberrypi/rpi-eeprom/releases) and make sure the version reported by your Raspberry Pi on boot is from around the same date as the last release.

NOTE: Ignore the October 8th 2021 release as it was just a repackaging of a previous release.

The [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/computers/raspberry-pi.html#updating-the-bootloader) recommends using the Raspberry Pi Imager for creating a boot disk that can be used to update the EEPROM. If you're on a flavor Fedora Linux the Raspberry Pi Imager is packaged up and available in the repositories. You can install it like: 

```
dnf install rpi-imager
```

NOTE: This also works inside a `toolbx` container.

If not on Fedora Linux you'll need to follow the documentation for obtaining the imager. Once you have the imager up and running (on Fedora you can run with `rpi-imager` on the command line). You'll see the imager application load:

![image](/2021-11-02/raspberry-pi-imager.png)                                                                                                                              

At this point you can follow [the documentation](https://www.raspberrypi.org/documentation/computers/raspberry-pi.html#updating-the-bootloader) for how to create the disk and then update your Raspberry Pi 4.

## Installing FCOS and Booting via U-Boot {#Installing-FCOS-and-Booting-via-U-Boot}

To run FCOS on a Raspberry Pi 4 via U-Boot the SD card or USB disk needs to be prepared on another system and then the disk moved to the RPi4. After writing FCOS to the disk a few more files will need to be copied in place on the EFI partition of the FCOS disk. Check out the [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/computers/configuration.html#boot-folder-contents) to read more about what these files are for.

In this case we can grab these files from the `uboot-images-armv8`, `bcm283x-firmware`, `bcm283x-overlays` RPMs from the Fedora Linux repositories. First download them and store them in a temporary directory on your system:

```
RELEASE=34 # The target Fedora Release. Use the same one that current FCOS is based on.
mkdir -p /tmp/RPi4boot/boot/efi/
sudo dnf install -y --downloadonly --release=$RELEASE --forcearch=aarch64 --destdir=/tmp/RPi4boot/  uboot-images-armv8 bcm283x-firmware bcm283x-overlays
```

Now extract the contents of the RPMs and copy the proper `u-boot.bin` for the RPi4 into place:

```
for rpm in /tmp/RPi4boot/*rpm; do rpm2cpio $rpm | sudo cpio -idv -D /tmp/RPi4boot/; done
sudo mv /tmp/RPi4boot/usr/share/uboot/rpi_4/u-boot.bin /tmp/RPi4boot/boot/efi/rpi4-u-boot.bin
```

Run `coreos-installer` to install to the target disk. There are [various ways](https://coreos.github.io/coreos-installer/getting-started/) to run `coreos-installer` and install to a target disk. We won't cover them all here, but this workflow most closely mirrors the ["Installing from the container"](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/#_installing_from_the_container) documentation.

```
FCOSDISK=/dev/sdX
sudo coreos-installer install --architecture=aarch64 -i config.ign $FCOSDISK
```

NOTE: Make sure you provide an [Ignition config](https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/) when you run `coreos-installer`.

Now mount up the EFI partition and copy the files over:

```
mkdir /tmp/FCOSEFIpart
sudo mount ${FCOSDISK}2 /tmp/FCOSEFIpart
sudo rsync -avh --ignore-existing /tmp/RPi4boot/boot/efi/ /tmp/FCOSEFIpart/
sudo umount ${FCOSDISK}2
```

Now take the USB/SD card and attach it to the RPi4 and boot.

TIP: It can take some time to boot, especially if the disk is slow. Be patient. You may not see anything on the screen for 20-30 seconds.


## Installing FCOS and Booting via UEFI {#Installing-FCOS-and-Booting-via-UEFI}

There is a UEFI firmware implementation for the RPi4 ([pftf/RPi4](https://github.com/pftf/RPi4/)) that attempts to make the RPi4 ServerReady (SBBC compliant) and allows you to pretend that the RPi4 is just like any other server hardware with UEFI.

You can write the firmware to a disk (USB or SD card) and then boot/install FCOS as you would on any bare metal server. However, the firmware files need to be on an SD card or USB disk and will take up either the SD card slot or a USB slot. Depending on your needs this may be acceptable or not. Depending on the answer you have a few options:

- Separate UEFI Firmware Disk (aka "separate disk mode")
- Combined Fedora CoreOS + UEFI Firmware Disk (aka "combined disk mode")

These options are covered in the following sections. Regardless of which option you choose you'll want to consider if you need to either [Change the 3G RAM limit](#UEFI-Firmware-Changing-the-3G-limit) or [Enable DeviceTree Boot](#UEFI-Firmware-GPIO-via-DeviceTree).


### UEFI: Separate UEFI Firmware Disk Mode

In separate disk mode the UEFI firmware will take up either the SD card slot or a USB slot on your RPi4. Once the firmware disk is attached to the system you'll be able to follow the [bare metal install documentation](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/) and pretend like the RPi4 is any other server hardware.

To create a disk (SD or USB) with the firmware on it you can do something like:

```
VERSION=v1.32  # use latest one from https://github.com/pftf/RPi4/releases
UEFIDISK=/dev/sdX
sudo mkfs.vfat $UEFIDISK
mkdir /tmp/UEFIdisk
sudo mount $UEFIDISK /tmp/UEFIdisk
pushd /tmp/UEFIdisk
sudo curl -LO https://github.com/pftf/RPi4/releases/download/${VERSION}/RPi4_UEFI_Firmware_${VERSION}.zip
sudo unzip RPi4_UEFI_Firmware_${VERSION}.zip
sudo rm RPi4_UEFI_Firmware_${VERSION}.zip
popd
sudo umount /tmp/UEFIdisk
```

Attaching this disk to your Pi4 you can now install FCOS as you would on any bare metal server.

NOTE: The separate UEFI firmware disk will need to stay attached permanently for future boots to work.

### UEFI: Combined Fedora CoreOS + UEFI Firmware Disk

In combined disk mode the UEFI firmware will live inside the EFI partition of Fedora CoreOS, allowing for a single disk to be used for the UEFI firmware and FCOS.

There are a few ways to achieve this goal:

- Install Directly on RPi4
- Prepare Pi4 Disk on Alternate Machine


#### UEFI: Combined Disk Mode Direct Install

When performing a direct install, meaning you boot (via the UEFI firmware) into the Fedora CoreOS live environment (ISO or PXE) and run `coreos-installer`, you can mount the EFI partition (2nd partition) of the installed FCOS disk after the install is complete and copy the UEFI firmware files over:

```
UEFIDISK=/dev/mmcblkX or /dev/sdX
FCOSDISK=/dev/sdY
mkdir /tmp/mnt{1,2}
sudo mount $UEFIDISK /tmp/mnt1
sudo mount ${FCOSDISK}2 /tmp/mnt2
sudo rsync -avh /tmp/mnt1/ /tmp/mnt2/
sudo umount /tmp/mnt1 /tmp/mnt2
```

Now you can remove the extra disk from the RPi4 and reboot the machine.

TIP: It can take some time to boot, especially if the disk is slow. Be patient. You may not see anything on the screen for 20-30 seconds.

#### UEFI: Combined Disk Mode Alternate Machine Disk Preparation

When preparing the RPi4 disk from an alternate machine (i.e. creating the disk from your laptop) then you can mount up the 2nd partition **after** running `coreos-installer` and pull down the UEFI firmware files.

First, run `coreos-installer` to install to the target disk:

```
FCOSDISK=/dev/sdX
sudo coreos-installer install --architecture=aarch64 -i config.ign $FCOSDISK
```

Now you can mount up the 2nd partition and pull down the UEFI firmware files:

```
mkdir /tmp/FCOSEFIpart
sudo mount ${FCOSDISK}2 /tmp/FCOSEFIpart
pushd /tmp/FCOSEFIpart
VERSION=v1.32  # use latest one from https://github.com/pftf/RPi4/releases
sudo curl -LO https://github.com/pftf/RPi4/releases/download/${VERSION}/RPi4_UEFI_Firmware_${VERSION}.zip
sudo unzip RPi4_UEFI_Firmware_${VERSION}.zip
sudo rm RPi4_UEFI_Firmware_${VERSION}.zip
popd
sudo umount /tmp/FCOSEFIpart
```

Now take the USB/SD card and attach it to the RPi4 and boot.

TIP: It can take some time to boot, especially if the disk is slow. Be patient. You may not see anything on the screen for 20-30 seconds.

### UEFI Firmware: Changing the 3G limit {#UEFI-Firmware-Changing-the-3G-limit}

If you have a Pi4 with more than 3G of memory you'll most likely want to disable the 3G memory limitation. In the UEFI firmware menu go to 

- `Device Manager` -> `Raspberry Pi Configuration` -> `Advanced Configuration` -> `Limit RAM to 3GB` -> `Disabled`
- `F10` to save -> `Y` to confirm
- `Esc` to top level menu and select `reset` to cycle the system.

### UEFI Firmware: GPIO via DeviceTree {#UEFI-Firmware-GPIO-via-DeviceTree}

With the UEFI Firmware in ACPI mode (the default) you won't get access to GPIO (i.e. no Pi HATs will work). To get access to GPIO pins you'll need to change the setting to DeviceTree mode in the UEFI menus.

- `Device Manager` -> `Raspberry Pi Configuration` -> `Advanced Configuration` -> `System Table Selection` -> `DeviceTree`
- `F10` to save -> `Y` to confirm
- `Esc` to top level menu and select `reset` to cycle the system.

After boot you should see entries under `/proc/device-tree/` and also see `/dev/gpiochip1` and `/dev/gpiochip2`:

```
[core@localhost ~]$ ls /proc/device-tree/ | wc -l
35
[core@localhost ~]$ ls /dev/gpiochip* 
/dev/gpiochip0  /dev/gpiochip1
```
