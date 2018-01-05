#!/bin/bash

set -e

CDIMAGE=tmp/cd-image
ISOMNT=tmp/iso-mnt
ISO=ubuntu-16.04.3-server-amd64.iso
OUTPUT=output

rm -rf $CDIMAGE $ISOMNT 
mkdir -p $CDIMAGE/wisnuc $ISOMNT
mount -o loop $ISO $ISOMNT
cp -rT $ISOMNT $CDIMAGE
umount $ISOMNT

chmod a+w $CDIMAGE/preseed/ubuntu-server.seed
chmod a+w $CDIMAGE/isolinux/isolinux.bin

cp assets/wisnuc-bootstrap-update.service $CDIMAGE/wisnuc
cp assets/wisnuc-bootstrap-update.timer $CDIMAGE/wisnuc
cp assets/wisnuc-bootstrap.service $CDIMAGE/wisnuc
cp assets/wetty.service $CDIMAGE/wisnuc

# there's limit in file path length on cdrom
# cp -r $OUTPUT/wisnuc $CDIMAGE/wisnuc/wisnuc 
tar cf $CDIMAGE/wisnuc/wisnuc.tar -C $OUTPUT/wisnuc .

cat << EOF >> $CDIMAGE/preseed/ubuntu-server.seed

# Individual additional packages to install
d-i pkgsel/include string avahi-daemon avahi-utils btrfs-tools udisks2 libimage-exiftool-perl imagemagick ffmpeg samba minidlna

# Install wisnuc files
d-i preseed/late_command string \\
mkdir -p /target/wisnuc; tar xf /cdrom/wisnuc/wisnuc.tar -C /target/wisnuc; \\
cp /cdrom/wisnuc/wisnuc-bootstrap-update.service /target/lib/systemd/system; \\
cp /cdrom/wisnuc/wisnuc-bootstrap-update.timer /target/lib/systemd/system; \\
cp /cdrom/wisnuc/wisnuc-bootstrap.service /target/lib/systemd/system; \\
cp /cdrom/wisnuc/wetty.service /target/lib/systemd/system; \\
in-target systemctl stop smbd nmbd; \\
in-target systemctl disable smbd nmbd; \\
in-target systemctl enable wisnuc-bootstrap wisnuc-bootstrap-update.timer wetty
EOF

# for node version
# readlink output/wisnuc/node/base  -> eg. 8.9.3
NODEVER=$(readlink output/wisnuc/node/base)

# for extracting appifi version
# ls output/wisnuc/appifi-tarballs | awk -F "-" '{print $2}' -> 1.0.11
APPIFIVER=$(ls output/wisnuc/appifi-tarballs | awk -F "-" '{print $2}')

# for append build timestamp
# date +"%y%m%d-%H%M%S" -> 180104-164540
TIMESTAMP=$(date +"%y%m%d-%H%M%S")


FILENAME=ubuntu-16.04.3-node-${NODEVER}-appifi-${APPIFIVER}-build-${TIMESTAMP}.iso

dd if=$ISO bs=512 count=1 of=$CDIMAGE/isolinux/isohdpfx.bin
xorriso -as mkisofs -r \
  -V "UBUNTU_WISNUC" \
  -o $OUTPUT/$FILENAME \
  -isohybrid-mbr $CDIMAGE/isolinux/isohdpfx.bin \
  -cache-inodes -J -l \
  -c isolinux/boot.cat \
  -b isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
  $CDIMAGE

ls -l $OUTPUT/*.iso
