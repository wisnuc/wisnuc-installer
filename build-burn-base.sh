#!/bin/bash

set -e

UUID=7dec5069-3524-4a8f-b838-ee00613cd30b

TARGET=target/burn
OUTPUT=output


rm -rf ${TARGET}
mkdir -p ${TARGET}/wisnuc

tar xzf assets/ubuntu-base-16.04.3-base-amd64.tar.gz -C ${TARGET}
cp assets/linux-image-4.3.3.001+_001_amd64.deb ${TARGET}

cp assets/imageburn.sh ${TARGET}/wisnuc

cat <<EOF > ${TARGET}/etc/apt/sources.list
deb http://cn.archive.ubuntu.com/ubuntu/ xenial main restricted
deb http://cn.archive.ubuntu.com/ubuntu/ xenial-updates main restricted
EOF

cat <<EOF > ${TARGET}/etc/systemd/network/wired.network
[Match]
Name=en*
[Network]
DHCP=ipv4
EOF

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

cat <<EOF > ${TARGET}/etc/hostname
wisnuc
EOF

cat <<EOF > ${TARGET}/lib/systemd/system/wisnuc-imageburn.service
[Unit]
Description=wisnuc ws215i imageburn

[Service]
Type=oneshot
ExecStart=/wisnuc/imageburn.sh

[Install]
WantedBy=multi-user.target
EOF

# chroot_setup
mount -o bind   /dev  ${TARGET}/dev
mount -t proc   proc  ${TARGET}/proc
mount -t sysfs  sys   ${TARGET}/sys

chroot ${TARGET} /bin/bash -c "apt update"
chroot ${TARGET} /bin/bash -c "apt -y install initramfs-tools parted"
chroot ${TARGET} /bin/bash -c "dpkg -i linux-image-4.3.3.001+_001_amd64.deb"

# this is not necessary, install kernel will update initramfs automatically
# chroot ${TARGET} /bin/bash -c "update-initramfs -u -k all"

if [ "$1" == "--debug" ] || [ "$1" == "-d" ]; then
  echo "install extra packages"
  chroot ${TARGET} /bin/bash -c "apt -y install sudo openssh-server net-tools iputils-ping parted vim"
  chroot ${TARGET} /bin/bash -c "useradd wisnuc -b /home -m -s /bin/bash"
  chroot ${TARGET} /bin/bash -c "echo wisnuc:wisnuc | chpasswd"
  chroot ${TARGET} /bin/bash -c "adduser wisnuc sudo"
  chroot ${TARGET} /bin/bash -c "systemctl enable systemd-networkd"
  chroot ${TARGET} /bin/bash -c "systemctl enable systemd-resolved"
else
  echo "skip extra packages and enable auto-burn"
  chroot ${TARGET} /bin/bash -c "systemctl enable wisnuc-imageburn"
fi

ln -s vmlinuz-4.3.3.001+ ${TARGET}/boot/bzImage
ln -s initrd.img-4.3.3.001+ ${TARGET}/boot/ramdisk
echo "console=tty0 console=ttyS0,115200 root=UUID=${UUID} rootwait" > ${TARGET}/boot/cmdline
echo "UUID=${UUID} / ext4 errors=remount-ro 0 1" > ${TARGET}/etc/fstab

chroot ${TARGET} /bin/bash -c "apt clean"

umount ${TARGET}/sys
umount ${TARGET}/proc
umount ${TARGET}/dev

rm ${TARGET}/linux-image-4.3.3.001+_001_amd64.deb

if [ "$1" == "--debug" ] || [ "$1" == "-d" ]; then
  TARNAME=ws215i-rootfs-burn-base-debug.tar.gz
else
  TARNAME=ws215i-rootfs-burn-base.tar.gz
fi

echo "tar $OUTPUT/$TARNAME"
tar czf $OUTPUT/$TARNAME -C ${TARGET} .
 
echo "done"

