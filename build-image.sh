#!/bin/bash

# this cannot be used for fdisk will fail
# set -e

UUID=7dec5069-3524-4a8f-b838-ee00613cd30b
MNT=tmp/mnt
TMP=tmp/imagify
OUTPUT=output

mkdir -p tmp
rm -rf $TMP
mkdir $TMP

echo "argument $1"

if [ "$1" == "--debug" ] || [ "$1" == "-d" ]; then
  COUNT=2048
  IMAGEFILE=tmp/imagefile-debug
else
  COUNT=1024
  IMAGEFILE=tmp/imagefile
fi

losetup -d /dev/loop0

rm -rf $TMP
mkdir -p $TMP
mkdir -p $MNT

echo "untar $OUTPUT/ws215i-rootfs-emmc-base.tar.gz into $TMP dir"
tar xzf $OUTPUT/ws215i-rootfs-emmc-base.tar.gz -C $TMP

echo "cp $OUTPUT/wisnuc into $TMP dir"
cp -r $OUTPUT/wisnuc $TMP

echo "tar $OUTPUT/ws215i-rootfs-emmc.tar.gz"
tar czf $OUTPUT/ws215i-rootfs-emmc.tar.gz -C $TMP .

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

if [ "$1" == "--debug" ] || [ "$1" == "-d" ]; then
  echo "untar $OUTPUT/ws215i-rootfs-burn-base-debug.tar.gz" 
  tar xzf $OUTPUT/ws215i-rootfs-burn-base-debug.tar.gz -C $MNT
else
  echo "untar $OUTPUT/ws215i-rootfs-burn-base.tar.gz" 
  tar xzf $OUTPUT/ws215i-rootfs-burn-base.tar.gz -C $MNT
fi

echo "cp $OUTPUT/ws215i-rootfs-emmc.tar.gz" 
cp $OUTPUT/ws215i-rootfs-emmc.tar.gz ${MNT}/wisnuc 

sync
umount $MNT
losetup -d /dev/loop0

# for node version
# readlink output/wisnuc/node/base  -> eg. 8.9.3
NODEVER=$(readlink output/wisnuc/node/base)

# for extracting appifi version
# ls output/wisnuc/appifi-tarballs | awk -F "-" '{print $2}' -> 1.0.11
APPIFIVER=$(ls output/wisnuc/appifi-tarballs | awk -F "-" '{print $2}')

# for append build timestamp
# date +"%y%m%d-%H%M%S" -> 180104-164540
TIMESTAMP=$(date +"%y%m%d-%H%M%S")

if [ "$1" == "--debug" ] || [ "$1" == "-d" ]; then
  FILENAME=ws215i-ubuntu-16.04.3-node-${NODEVER}-appifi-${APPIFIVER}-build-${TIMESTAMP}-debug.img
else
  FILENAME=ws215i-ubuntu-16.04.3-node-${NODEVER}-appifi-${APPIFIVER}-build-${TIMESTAMP}.img
fi

mv $IMAGEFILE $OUTPUT/$FILENAME

echo "$OUTPUT/$FILENAME successfully created"

tree $OUTPUT -L 3



