#!/bin/bash
set -ex
# The password for hard drive encryption
ENCPASS='lukspass'
# The root user password
ROOTPASS='rootpass'

# Format the hard drive
fdisk /dev/sda <<EOF
o
n
p
1
2048

w
EOF

# encrypt the harddrive
echo -n $ENCPASS | cryptsetup luksFormat /dev/sda1 --key-file -

# unlock the harddrive
echo -n $ENCPASS | cryptsetup luksOpen /dev/sda1 cryptodisk --key-file -

# Create VG and LVs  
vgcreate vgroot /dev/mapper/cryptodisk
lvcreate --size=4G --name lvswap vgroot
lvcreate -l 100%FREE --name lvroot vgroot

# Format swap
mkswap /dev/vgroot/lvswap

# Format and mount btrfs filesystem
mkfs.btrfs /dev/vgroot/lvroot
mkdir -p /mnt/sysimage
mount /dev/vgroot/lvroot /mnt/sysimage/

# Create a yum repo file for the dvd
mkdir /etc/yum.repos.d
cat <<EOF > /etc/yum.repos.d/dvd.repo
[dvd]
name=dvd
baseurl=file:///run/install/repo
enabled=1
gpgcheck=0
EOF

# Install the base system
dnf install -y --releasever=24 --installroot=/mnt/sysimage filesystem

# Mount special filesystems
mount -v -o bind /dev /mnt/sysimage/dev/
mount -v -o bind /run /mnt/sysimage/run/
mount -v -t proc proc /mnt/sysimage/proc/ 
mount -v -t sysfs sys /mnt/sysimage/sys/

# Copy over the dvd repo into the new sysroot
cp /etc/yum.repos.d/dvd.repo /mnt/sysimage/etc/yum.repos.d/

# Install more stuff now
dnf install -y --installroot=/mnt/sysimage --disablerepo=* --enablerepo=dvd @core @standard kernel btrfs-progs lvm2

# Now install the special grub packages that I have compiled
dnf install -y --installroot=/mnt/sysimage --disablerepo=* --enablerepo=dvd \
https://github.com/dustymabe/fedora-grub-boot-btrfs-default-subvolume/raw/master/fedora24/rpmbuild/RPMS/x86_64/grub2-2.02-0.28.fc24.dusty.x86_64.rpm \
https://github.com/dustymabe/fedora-grub-boot-btrfs-default-subvolume/raw/master/fedora24/rpmbuild/RPMS/x86_64/grub2-tools-2.02-0.28.fc24.dusty.x86_64.rpm

# Remove the dvd repo. We don't want it to be on the installed system
rm /mnt/sysimage/etc/yum.repos.d/dvd.repo

# Set root user password
echo -n $ROOTPASS | chroot /mnt/sysimage passwd --stdin root

# Chroot into the system 
chroot /mnt/sysimage bash <<'ENDCHROOT'

# Set up unlocking the encrypted device on boot
UUID=$(blkid -s UUID -o value /dev/sda1)
cat <<EOF > /etc/crypttab
cryptodisk /dev/disk/by-uuid/$UUID -
EOF

# Write fstab
cat <<EOF > /etc/fstab
/dev/vgroot/lvroot / btrfs defaults 1 1
/dev/vgroot/lvswap swap swap defaults 0 0
EOF

# Anaconda writes out /etc/sysconfig/kernel here:
# https://github.com/rhinstaller/anaconda/blob/7477c6f7a1d22c2f107b66b0d906dfae91ac2117/pyanaconda/bootloader.py#L2355
# If we don't have this file then we have to update grub.cfg
# everytime we do a kernel update:
# https://bugzilla.redhat.com/show_bug.cgi?id=1242315
cat <<EOF > /etc/sysconfig/kernel 
# UPDATEDEFAULT specifies if new-kernel-pkg should make
# new kernels the default
UPDATEDEFAULT=yes

# DEFAULTKERNEL specifies the default kernel package type
DEFAULTKERNEL=kernel-core
EOF

# configure relabel on first boot
touch /.autorelabel

# Write out some var for grub.conf and generate grub.cfg
cat <<EOF >> /etc/default/grub 
GRUB_ENABLE_CRYPTODISK=y
SUSE_BTRFS_SNAPSHOT_BOOTING=true
EOF
grub2-mkconfig -o /boot/grub2/grub.cfg

# Install grub
grub2-install /dev/sda

# Generate initramfs
KERNELVRA=$(rpm -q kernel --qf %{V}-%{R}.%{ARCH})
dracut --kver $KERNELVRA --force
ENDCHROOT

# umount mounted filesystems and reboot
umount /mnt/sysimage/{dev,run,sys,proc}
umount /mnt/sysimage/
reboot
