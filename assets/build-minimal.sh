#!/bin/bash

set -e

rm -rf target
mkdir target

tar xvzf assets/ubuntu-base-16.04.3-base-amd64.tar.gz -C target
cp assets/linux-image-4.3.3.001+_001_amd64.deb target

echo "nameserver 127.0.1.1" > target/etc/resolv.conf

mount -t devtmpfs   none target/dev
mount -t proc       none target/proc
mount -t sysfs      none target/sys
mount -t devpts     none target/dev/pts

chroot target /bin/bash -c "apt update"
chroot target /bin/bash -c "apt -y install sudo initramfs-tools openssh-server"

chroot target /bin/bash -c "useradd wisnuc -b /home -m"
chroot target /bin/bash -c "echo wisnuc:wisnuc | chpasswd"
chroot target /bin/bash -c "adduser wisnuc sudo"

chroot target /bin/bash -c "dpkg -i linux-image-4.3.3.001+_001_amd64.deb"
chroot target /bin/bash -c "apt-get -y remove linux-image-4.4"
chroot target /bin/bash -c "apt-get -y remove linux-headers-4.4"
chroot target /bin/bash -c "apt-get -y remove linux-image-generic"
chroot target /bin/bash -c "apt-get -y remove linux-headers-generic"
chroot target /bin/bash -c "apt-mark hold linux-image-generic"
chroot target /bin/bash -c "apt-mark hold linux-headers-generic"
chroot target /bin/bash -c "update-initramfs -u -k all"

ln -s vmlinuz-4.3.3.001+ target/boot/bzImage
ln -s initrd.img-4.3.3.001+ target/boot/ramdisk
echo "console=tty0 console=ttyS0,115200 root=/dev/sda1 rootwait" > target/boot/cmdline

cat <<EOF > target/etc/systemd/network/wired.network
[Match]
Name=en*
[Network]
DHCP=ipv4
EOF

chroot target /bin/bash -c "systemctl enable systemd-networkd"
chroot target /bin/bash -c "systemctl enable systemd-resolved"

umount target/dev/pts
umount target/sys
umount target/proc
umount target/dev

rm -rf target/linux-image-4.3.3.001+_001_amd64.deb

tar cvzf rootfs.tag.gz -C target .
