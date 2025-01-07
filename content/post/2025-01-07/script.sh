#!/bin/bash
# The password for hard drive encryption
ENCPASS='lukspass'
# The root user password
ROOTPASS='simplepass'

# set -x after passwords get set
set -eux

REPO="file:///run/install/repo"
RELEASEVER=$(source /etc/os-release && echo $VERSION_ID)

ESPDISK="/dev/sda"
DISKA="/dev/sdb"
ESPDISKPART1="${ESPDISK}1"
DISKPART1="${DISKA}1"


# Partition the ESP disk (used for EFI).
sgdisk --zap-all "$ESPDISK"          \
       --disk-guid=R                 \
       --new=1:0:0 "$ESPDISK"        \
       --change-name=1:EFI-SYSTEM    \
       --typecode=1:C12A7328-F81F-11D2-BA4B-00A0C93EC93B
sgdisk --print "$ESPDISK"
sleep 3
mkfs.fat -F 32 "$ESPDISKPART1"

# Partition the main disk
sgdisk --zap-all "$DISKA"   \
       --disk-guid=R       \
       --new=1:0:0 "$DISKA" \
       --change-name=1:main-luks-disk
sgdisk --print "$DISKA"
# Run partprobe to update kernel on partition table changes
partprobe

# encrypt & unlock the harddrive
# This needs to be luks header format v1 for now
# https://cryptsetup-team.pages.debian.net/cryptsetup/encrypted-boot.html
# https://savannah.gnu.org/bugs/?55093
set +x
echo -n $ENCPASS | cryptsetup luksFormat --type luks1 "$DISKPART1" --key-file -
echo -n $ENCPASS | cryptsetup luksOpen "$DISKPART1" cryptodisk --key-file -
set -x

# Create VG and LVs
vgcreate vgroot /dev/mapper/cryptodisk
lvcreate --size=4G --name swap vgroot
lvcreate -l 100%FREE --name root vgroot

# Format swap
mkswap /dev/vgroot/swap

# Format and mount btrfs filesystem
mkfs.btrfs /dev/vgroot/root
mkdir -p /mnt/sysimage
mount /dev/vgroot/root /mnt/sysimage/

# Install dnf5 in Anaconda environment (in F41 Anaconda hadn't switched over yet)
dnf install -y --releasever=$RELEASEVER --repofrompath "local,${REPO}" \
               --setopt=gpgcheck=0 --repo=local dnf5

# Install the base system
/usr/bin/dnf5 install -y --releasever=$RELEASEVER --repofrompath "local,${REPO}" \
               --setopt=gpgcheck=0 --repo=local --installroot=/mnt/sysimage filesystem

# make /var/lib/portables directory so a BTRFS subvolume won't be
# created by systemd-tmpfiles
mkdir /mnt/sysimage/var/lib/portables

# Mount special filesystems
mount -v -o bind /dev /mnt/sysimage/dev/
mount -v -o bind /run /mnt/sysimage/run/
mount -v -t proc proc /mnt/sysimage/proc/
mount -v -t sysfs sys /mnt/sysimage/sys/

# Install more stuff now
/usr/bin/dnf5 install -y --releasever=$RELEASEVER --repofrompath "local,${REPO}" \
               --setopt=gpgcheck=0 --repo=local --installroot=/mnt/sysimage \
               @core @standard kernel btrfs-progs lvm2 grub2-tools shim-x64 grub2-efi-x64

# Set root user password
set +x
echo -n $ROOTPASS | chroot /mnt/sysimage passwd --stdin root
set -x

# Chroot into the system
chroot /mnt/sysimage bash <<'ENDCHROOT'
set -eux

# Set up unlocking the encrypted device on boot
# Derive the parent device name from the set up cryptodisk
eval $(lsblk -o NAME,PKNAME --pairs | grep 'NAME="cryptodisk"')
UUID=$(blkid -s UUID -o value "/dev/${PKNAME}")
cat <<EOF > /etc/crypttab
cryptodisk /dev/disk/by-uuid/$UUID -
EOF

# Write fstab
cat <<EOF > /etc/fstab
/dev/vgroot/root / btrfs defaults 1 1
/dev/vgroot/swap swap swap defaults 0 0
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
# And fix the context on it so checking the existence of the file
# won't fail
chcon -t etc_runtime_t /.autorelabel

# Write out some var for grub.conf and generate grub.cfg
cat <<EOF >> /etc/default/grub
GRUB_ENABLE_CRYPTODISK=y
SUSE_BTRFS_SNAPSHOT_BOOTING=true
GRUB_ENABLE_BLSCFG=true
EOF
grub2-mkconfig -o /boot/grub2/grub.cfg

# Generate initramfs
KERNELVRA=$(rpm -q kernel --qf %{V}-%{R}.%{ARCH})
dracut --kver $KERNELVRA --force
ENDCHROOT


# Add our EFI files and the pointer grub.cfg on our ESP disk
# We could copy the files that already got installed to our
# main disk but I want this process to be copy/pastable so
# we'll do it from scratch (grab/extract RPMs etc).
#
# The final layout of important files on the ESP disk will
# look something like:
#
# - EFI/BOOT/BOOTX64.EFI
#   - shim signed by microsoft, in the fallback efi location
# - EFI/fedora/grubx64.efi
#   - grub loaded by shim (BOOTX64.EFI), signed by Fedora Project
# - EFI/fedora/grub.cfg
#   - loaded by grubx64.efi, points to encrypted disk grub.cfg
#
# Note that if using these steps to re-make a disk and we don't know
# the UUID of the encrypted disk then `cryptomount -a` should work
# to mount all encrypted disks.
#
mkdir -p /tmp/workdir/boot/efi
mount "$ESPDISKPART1" /tmp/workdir/boot/efi
pushd /tmp/workdir
/usr/bin/dnf5 download -y --releasever=$RELEASEVER --repofrompath "local,${REPO}" \
               --setopt=gpgcheck=0 --repo=local shim-x64 grub2-efi-x64
for f in ./*rpm; do
    rpm2cpio ${f} | cpio -idv
    rm -f ${f}
done
popd
# Generate the grub.cfg that will point to the encrypted disk
UUID=$(blkid -s UUID -o value "$DISKPART1")
cat >/tmp/workdir/boot/efi/EFI/fedora/grub.cfg <<EOF
set default=0
set timeout=3
menuentry "Load grub.cfg From Encrypted Disk" {
    insmod part_gpt
    insmod cryptodisk
    insmod luks
    insmod gcry_rijndael
    insmod gcry_sha256
    insmod lvm
    insmod btrfs
    cryptomount -u $UUID
    configfile (lvm/vgroot-root)/boot/grub2/grub.cfg
}
menuentry 'UEFI Firmware Settings' {
    fwsetup
}
EOF

# umount mounted filesystems and reboot
sync
umount /mnt/sysimage/{dev,run,sys,proc}
umount /mnt/sysimage/
umount /tmp/workdir/boot/efi
reboot
