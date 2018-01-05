## Intro

本项目面向玩家和开发者。

本项目用于制作：

1. 用于64位标准X86 PC的闻上NAS系统安装光盘，基于64位Ubuntu Server 16.04.3 LTS；
2. 用于闻上WS215i设备的rootfs和系统烧录U盘；




## 准备

本项目的运行环境为Ubuntu桌面版，项目开发者使用16.04.3版本，理论上更新的版本也可以使用，但未测试过。

此项目需要node.js（ver > 8.0），可自行安装nodejs.org的官方版本，或者使用Ubuntu提供的nodejs。



准备工作包括如下操作：


```bash
# 安装所需命令，如果仅制作用于WS215i的相关工具，xorriso可以不装
$ sudo apt install tree xorriso

# 下载项目代码并安装npm包，中华人民共和国境内开发者，执行此命令时建议开启VPN
$ git clone https://github.com/wisnuc/wisnuc-installer
$ cd wisnuc-installer
$ npm i

# 下载Ubuntu Server安装光盘，如果仅制作用于WS215i的相关工具，此步骤可以忽略
# 使用官方源
$ wget http://releases.ubuntu.com/16.04.3/ubuntu-16.04.3-server-amd64.iso
# 或者，使用163镜像
$ wget http://mirrors.163.com/ubuntu-releases/16.04.3/ubuntu-16.04.3-desktop-amd64.iso
```




## 制作X86 PC安装光盘

```bash
# 中华人民共和国境内开发者，执行此命令时建议开启VPN
$ node prepare-wisnuc.js

# 此命令不联网
$ sudo ./build-iso.sh
```



生成的ISO文件位于`output`目录下，扩展名为`iso`。



## 制作WS215i烧录工具

```bash
# 中华人民共和国境内开发者，执行此命令时建议开启VPN
$ node prepare-wisnuc.js

# 中华人民共和国境内开发者，执行此命令时建议关闭VPN
$ sudo ./build-rootfs-emmc-base.sh
$ sudo ./build-burn-base.sh
$ sudo ./build-image.sh
```



生成的镜像文件位于`output`目录下，扩展名为`img`。


