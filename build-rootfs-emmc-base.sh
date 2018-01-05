#!/bin/bash

set -e

TARGET=target/emmc
OUTPUT=output

rm -rf ${TARGET}
mkdir ${TARGET}

# create the empty directory
mkdir -p ${TARGET}/wisnuc

tar xzf assets/ubuntu-base-16.04.3-base-amd64.tar.gz -C ${TARGET}
cp assets/linux-image-4.3.3.001+_001_amd64.deb ${TARGET}
cp assets/sources.list ${TARGET}/etc/apt/sources.list

touch ${TARGET}/etc/firstboot

cat <<EOF > ${TARGET}/lib/systemd/system/wisnuc-firstboot.service
[Unit]
Description=Wisnuc First Boot
Conflicts=shutdown.target
ConditionPathExists=/etc/firstboot

[Service]
Type=oneshot
# localectl does not work even in login shell
ExecStartPre=/usr/bin/timedatectl set-timezone "Asia/Shanghai"
ExecStart=/usr/bin/timedatectl set-ntp true
ExecStartPost=/bin/rm /etc/firstboot

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > ${TARGET}/etc/systemd/timesyncd.conf
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See timesyncd.conf(5) for details.

[Time]
#NTP=
FallbackNTP=ntp.ubuntu.com
EOF

cp assets/wisnuc-bootstrap-update.service ${TARGET}/lib/systemd/system/wisnuc-bootstrap-update.service
cp assets/wisnuc-bootstrap-update.timer ${TARGET}/lib/systemd/system/wisnuc-bootstrap-update.timer
cp assets/wisnuc-bootstrap.service ${TARGET}/lib/systemd/system/wisnuc-bootstrap.service
cp assets/wetty.service ${TARGET}/lib/systemd/system/wetty.service

cat <<EOF > ${TARGET}/etc/systemd/network/wired.network
[Match]
Name=en*
[Network]
DHCP=ipv4
EOF

# This is a temporary setting for chroot
cat <<EOF > ${TARGET}/etc/resolv.conf
nameserver 127.0.1.1
EOF

cat <<EOF > ${TARGET}/etc/hosts
127.0.0.1 localhost
127.0.1.1 wisnuc

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# replaced by systemd-firstboot.service
# reverted
cat <<EOF > ${TARGET}/etc/hostname
wisnuc
EOF

# chroot_setup
mount -o bind   /dev  ${TARGET}/dev
mount -t proc   proc  ${TARGET}/proc
mount -t sysfs  sys   ${TARGET}/sys

chroot ${TARGET} /bin/bash -c "apt update"
chroot ${TARGET} /bin/bash -c "apt -y install sudo initramfs-tools openssh-server parted vim-common tzdata net-tools iputils-ping"
chroot ${TARGET} /bin/bash -c "apt -y install avahi-daemon avahi-utils btrfs-tools udisks2"
chroot ${TARGET} /bin/bash -c "apt -y install libimage-exiftool-perl imagemagick ffmpeg"
chroot ${TARGET} /bin/bash -c "apt -y install samba rsyslog minidlna"


chroot ${TARGET} /bin/bash -c "useradd wisnuc -b /home -m -s /bin/bash"
chroot ${TARGET} /bin/bash -c "echo wisnuc:wisnuc | chpasswd"
chroot ${TARGET} /bin/bash -c "adduser wisnuc sudo"

chroot ${TARGET} /bin/bash -c "dpkg -i linux-image-4.3.3.001+_001_amd64.deb"

chroot ${TARGET} /bin/bash -c "apt-mark hold linux-image-generic"
chroot ${TARGET} /bin/bash -c "apt-mark hold linux-headers-generic"

# This does not work in chroot-ed environment.
# chroot ${TARGET} /bin/bash -c "timedatectl timedatectl set-timezone Asia/Shanghai"
# see https://wiki.archlinux.org/index.php/time
# This does not work either.
# chroot ${TARGET} /bin/bash -c "ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"

chroot ${TARGET} /bin/bash -c "systemctl enable systemd-networkd"
chroot ${TARGET} /bin/bash -c "systemctl enable systemd-resolved"
chroot ${TARGET} /bin/bash -c "systemctl enable wisnuc-firstboot"
chroot ${TARGET} /bin/bash -c "systemctl enable wisnuc-bootstrap-update.timer"
chroot ${TARGET} /bin/bash -c "systemctl enable wisnuc-bootstrap"
chroot ${TARGET} /bin/bash -c "systemctl enable wetty"
chroot ${TARGET} /bin/bash -c "systemctl disable smbd nmbd minidlna"

ln -s vmlinuz-4.3.3.001+ ${TARGET}/boot/bzImage
ln -s initrd.img-4.3.3.001+ ${TARGET}/boot/ramdisk
echo "console=tty0 console=ttyS0,115200 root=/dev/mmcblk0p1 rootwait" > ${TARGET}/boot/cmdline
echo "/dev/mmcblk0p1 / ext4 errors=remount-ro 0 1" > ${TARGET}/etc/fstab

chroot ${TARGET} /bin/bash -c "apt clean"

umount ${TARGET}/sys
umount ${TARGET}/proc
umount ${TARGET}/dev

rm -rf ${TARGET}/linux-image-4.3.3.001+_001_amd64.deb

# remove resolv.conf used in chroot
rm ${TARGET}/etc/resolv.conf
# create symbolic link as systemd-resolved requires.
ln -sf /run/systemd/resolve/resolv.conf ${TARGET}/etc/resolv.conf

tar czf ${OUTPUT}/ws215i-rootfs-emmc-base.tar.gz -C ${TARGET} .

echo done







