#!/bin/bash

# this cannot be used for fdisk will fail
# set -e

UUID=7dec5069-3524-4a8f-b838-ee00613cd30b
MNT=tmp/mnt
TMP=tmp/imagify

mkdir -p tmp
rm -rf $TMP
mkdir $TMP

if [ -z $1 ]; then
  COUNT=1024
  IMAGEFILE=imagefile
else
  COUNT=1536
  IMAGEFILE=imagefile-debug
fi 

losetup -d /dev/loop0

rm -rf $TMP
mkdir -p $TMP
mkdir -p $MNT


echo "untar rootfs-emmc-base into $TMP dir"
tar xzf ws215i-rootfs-emmc-base.tar.gz -C $TMP

echo "cp wisnuc dir"
cp -r wisnuc $TMP

echo "tar ws215i-rootfs-emmc.tar.gz"
tar czf ws215i-rootfs-emmc.tar.gz -C $TMP .

echo "create $IMAGEFILE"
rm -rf $IMAGEFILE
dd if=/dev/zero of=$IMAGEFILE bs=1M count=${COUNT}

echo "set up loop device"
losetup /dev/loop0 $IMAGEFILE 

echo "fdisk"
(
echo o # Create a new empty DOS partition table
echo n # Add a new partition
echo p # Primary partition
echo 1 # Partition number
echo   # First sector (Accept default: 1)
echo   # Last sector (Accept default: varies)
echo w # Write changes
) | fdisk /dev/loop0

echo "partprobe"
partprobe /dev/loop0

echo "make ext4 file system"
mkfs.ext4 -U $UUID /dev/loop0p1

echo "mount"
mount -t ext4 /dev/loop0p1 $MNT

if [ -z "$1" ]; then
  echo "untar ws215i-rootfs-burn-base.tar.gz" 
  tar xzf ws215i-rootfs-burn-base.tar.gz -C $MNT
else
  echo "untar ws215i-rootfs-burn-debug.tar.gz" 
  tar xzf ws215i-rootfs-burn-debug.tar.gz -C $MNT
fi

echo "cp ws215i-rootfs-emmc.tar.gz" 
cp ws215i-rootfs-emmc.tar.gz ${MNT}/wisnuc 

sync
umount $MNT
losetup -d /dev/loop0

echo "$IMAGEFILE successfully created"

