# wisnuc installer

本项目包含制作如下内容的工具：
1. 预安装文件，即目标系统上`/wisnuc`目录下的内容，对ws215i和64bit X86 PC来说是一样的；
2. ws215i设备
   1. emmc上的文件系统
   2. 烧录U盘
3. 64bit X86 PC（包括Intel和AMD处理器）
   1. 基于Ubuntu Server的安装光盘




本项目的运行环境为Ubuntu Desktop，开发者在16.04.3 LTS上使用，理论上新版本的Ubuntu Desktop也可以使用，但未测试过。




## ws215i
本项目包含ws215i的rootfs和系统烧录U盘的制作工具。

开发者也可以修改本项目代码自行制作：

1. 定制的ws215i rootfs和烧录U盘镜像
2. 定制的ws215i系统U盘（即操作系统运行在U盘上，而不是mmc上）


本项目以Ubuntu Base 16.04.3 LTS版本为基础，该rootfs压缩包已经包含在本项目中。


### Quick Start

```bash
# 中华人民共和国境内开发者，执行下面3个命令时建议使用VPN
$ git clone https://github.com/wisnuc/wisnuc-installer
$ cd wisnuc-installer
$ npm i
$ node prepare-wisnuc.js

# 中华人民共和国境内开发者，执行下面3个命令时建议关闭VPN
$ sudo ./build-rootfs-emmc-base.sh
$ sudo ./build-burn-base.sh
$ sudo ./build-image.sh
```

输出文件位于output目录下
```
$ tree output -L 3
output
├── wisnuc
│   ├── appifi-tarballs
│   │   └── appifi-1.0.11-9007103-17d1249d.tar.gz
│   ├── node
│   │   ├── 8.9.3
│   │   └── base -> 8.9.3
│   ├── wetty
│   ├── wisnuc-bootstrap
│   └── wisnuc-bootstrap-update
├── ws215i-rootfs-burn-base.tar.gz
├── ws215i-rootfs-emmc-base.tar.gz
├── ws215i-rootfs-emmc.tar.gz
└── ws215i-ubuntu-16.04.3-node-8.9.3-appifi-1.0.11-build-180104-180015.img
```
其中扩展名为`img`的文件为镜像文件，可以直接`dd`到U盘上使用。




### 合成过程

`wisnuc.js`脚本文件用于生成目标系统上的预部署目录`/wisnuc`；

`build-rootfs-emmc-base.sh`脚本用于生成ws215i的emmc的rootfs，不包含预装的`/wisnuc`目录；

`build-burn-base.sh`脚本用于生成烧录U盘的rootfs，它是最小化的ubuntu，可以在ws215i上boot和执行自动烧录脚本。

`imagify.sh`脚本会把这些内容组合起来。首先把ws215i的base rootfs和wisnuc目录合成为`ws215i-rootfs-emmc.tar.gz`文件，它是完整的rootfs；然后imagify会使用loop device挂载imagefile，把用于usb的rootfs展开进去，把emmc rootfs的压缩文件放进去，即获得可用于烧录ws215i的U盘镜像。

图示如下：

```
prepare-wisnuc.js     build-rootfs-emmc-base.sh           build-burn-base.sh
   |                            |                             |
   v                            v                             |
output/wisnuc dir + output/ws215i-rootfs-emmc-base.tar.gz     |
                  |                                           |
                  | build-image.sh                            |
                  v                                           v
 output/ws215i-rootfs-emmc.tar.gz   +   output/ws215i-rootfs-burn-base(-debug).tar.gz
                                    |
                                    | build-image.sh
                                    v
                                (example)
  output/ws215i-ubuntu-16.04.3-node-8.9.3-appifi-1.0.11-build-180104-171627.img
```



### prepare-wisnuc.js

该脚本合成在目标系统上预部署的`/wisnuc`目录，包括：

1. 建立目录结构
2. 安装node
3. wisnuc-bootstrap
4. wisnuc-bootstrap-update
5. wetty
6. appifi

输出为当前目录的`output/wisnuc`目录。

运行该脚本无须root权限。

该脚本支持参数`--appifi-only`。

```bash
node wisnuc.js                  # 更新全部
node wisnuc.js --appifi-only    # 仅更新appifi
node wisnuc.js -a               # --appifi-only
```



### build-rootfs-emmc-base.sh

该脚本创建ws215i的rootfs (emmc)压缩包文件，但不包含预装的`/wisnuc`目录。

执行该脚本需要root权限（`sudo`）。

过程如下：

1. 创建`target/emmc`目录
2. 在目录下安装ubuntu base
3. 修改apt源为中国镜像
4. 创建如下systemd unit
   1. firstboot
   2. timesyncd
   3. wisnuc-bootstrap-update，包括timer和service
   4. wisnuc-bootstrap
   5. wetty
   6. wired.network
   7. resolv.conf，先放入一个临时版本，在chroot最后更新其为生产环境版本
   8. hosts
   9. hostname
5. chroot
   1. 安装deb包
   2. 创建wisnuc用户，加入sudo
   3. 安装ws215i内核并阻止内核升级
   4. 使能所有需要的systemd服务，禁用samba和minidlna服务
   5. 创建ws215i启动需要的boot文件（包括符号链）
   6. 修改fstab
6. post-install (leave chroot)
   1. 清理内核deb文件
   2. 清理apt
   3. 更新resolv.conf (symlink to systemd resolv.conf)
7. 最后把rootfs打包成`output/ws215i-rootfs-emmc-base.tar.gz`



### build-burn-base.sh

该脚本生成USB烧录盘的最小文件系统，USB烧录盘本身也是一个包含完整rootfs的ubuntu运行系统，不只是ramdisk。其内容和emmc镜像相仿，做了裁剪。

该脚本需要root权限（`sudo`）。

该脚本接受参数`--debug`，debug模式下最终输出的镜像文件会包含openssh server，方便开发者调试。

```bash
sudo ./build-burn-base.sh            # 生成output/ws215i-rootfs-burn-base.tar.gz
sudo ./build-burn-base.sh --debug    # 生成output/ws215i-rootfs-burn-base-debug.tar.gz
```



### build-image.sh

该脚本合成上述内容：

1. 先把emmc rootfs (base)和预置的`/wisnuc`目录合成成为`output/ws215i-rootfs-emmc.tar.gz`压缩包；
2. 创建一个临时文件，用loop device挂载，然后创建分区和ext4文件系统；
3. 展开burn rootfs (base)到目标文件系统上；
4. 装入合成的压缩包；
5. 生成最终的镜像文件。

该脚本需要root权限。

该脚本支持`--debug`参数。如果提供该参数，会使用debug版本的burn rootfs。

输出文件的命名规则如下：


```bash
# 非debug版本
ws215i-ubuntu-16.04.3-node-${Node版本}-appifi-${Appifi版本}-build-${时间戳}.img

# debug版本
ws215i-ubuntu-16.04.3-node-${Node版本}-appifi-${Appifi版本}-build-${时间戳}-debug.img
```

其中时间戳格式为`yymmdd-HHMMSS`，例如`180104-171627`。



### 文件

`assets`目录 下包含：

1. ws215i的内核包（debian格式），内核版本为4.3.3
2. Ubuntu Base压缩包
3. apt的sources.list文件，使用中国源





### 其他问题

1. 该制作过程使用了chroot，mount，loop device等功能，无法在绝大多数云主机上运行；
2. 注意chroot环境下resolv.conf的配置；
3. 因为有chroot和装包过程，所以systemd官方的firstboot服务无法使用，我们自己定义了一个firstboot service；




## 64bit X86 PC

本项目用于制作闻上家用NAS系统的安装光盘，基于Ubuntu 16.04.3 64bit (amd64) Server版。使用其他Ubuntu服务器版理论上也应该可以，但没有实际测试过。



### Quick Start

```bash
# 安装xorriso
$ sudo apt install xorriso tree

# 下载和创建预安装目录
# 中华人民共和国境内开发者，执行下面3个命令时建议使用VPN
$ git clone https://github.com/wisnuc/wisnuc-installer
$ cd wisnuc-installer
$ npm i
$ node prepare-wisnuc.js

# 下载Ubuntu Server安装光盘
# 使用官方源
$ wget http://releases.ubuntu.com/16.04.3/ubuntu-16.04.3-server-amd64.iso

# 使用163镜像
$ wget http://mirrors.163.com/ubuntu-releases/16.04.3/ubuntu-16.04.3-desktop-amd64.iso

# 创建镜像
$ sudo ./build-iso.sh
```



### Trouble-shooting

#### fdisk

To check if an iso is a flat iso9660, a hybrid, with or without UEFI support, use `fdisk` command.

```
$ fdisk -l ubuntu-16.04.3-server-amd64.iso
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x40b1aa35

Device                           Boot  Start     End Sectors  Size Id Type
ubuntu-16.04.3-server-amd64.iso1 *         0 1689599 1689600  825M  0 Empty
ubuntu-16.04.3-server-amd64.iso2      426064  430735    4672  2.3M ef EFI (FAT-12/16/32)

$ fdisk -l ubuntu-16.04.3-server-amd64-wisnuc-station-0.8.7.iso
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x4411db41

Device                                                Boot Start     End Sectors  Size Id Type
ubuntu-16.04.3-server-amd64-wisnuc-station-0.8.7.iso1 *        0 1763327 1763328  861M  0 Empty
ubuntu-16.04.3-server-amd64-wisnuc-station-0.8.7.iso2       7880   12551    4672  2.3M ef EFI (FAT-12/16/32)
```



#### Startup Disk Creator (Ubuntu)

If Ubuntu `Startup Disk Creator` cannot use the generated iso to flash usb drive, it means the iso is not bootable, probably for there is no mbr record.



### Reference

1. https://help.ubuntu.com/community/InstallCDCustomization
2. http://www.syslinux.org/wiki/index.php?title=Isohybrid
3. https://linuxconfig.org/legacy-bios-uefi-and-secureboot-ready-ubuntu-live-image-customization
4. https://askubuntu.com/questions/342365/what-is-the-difference-between-grubx64-and-shimx64

There is no isohdpfx.bin provided in ubuntu iso. It must be cut from iso image. See isohybrid documentation.
