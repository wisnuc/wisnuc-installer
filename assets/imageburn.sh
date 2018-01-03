#!/bin/bash

IMGFILE=/wisnuc/ws215i-rootfs-emmc.tar.gz
MNT=/run/mmc

if [ ! -f $IMGFILE ]; then
    echo "tarball not found"
    exit 1
fi

# fast blink
echo "PWR_LED 3" > /proc/BOARD_io

(
  set -e

  ! grep /run/mmc /proc/mounts || umount /run/mmc
  dd if=/dev/zero of=/dev/mmcblk0 bs=512 count=1024
  partprobe /dev/mmcblk0

  # fdisk
  (
    echo o # Create a new empty DOS partition table
    echo n # Add a new partition
    echo p # Primary partition
    echo 1 # Partition number
    echo   # First sector (Accept default: 1)
    echo   # Last sector (Accept default: varies)
    echo w # Write changes
  ) | fdisk /dev/mmcblk0

  mkfs.ext4 -F /dev/mmcblk0p1
  mkdir -p $MNT
  mount /dev/mmcblk0p1 $MNT
  echo "untar rootfs onto emmc"
  tar xzf $IMGFILE -C $MNT
  sync
  echo "PWR_LED 1" > /proc/BOARD_io
) || {
  echo "PWR_LED 4" > /proc/BOARD_io
}


