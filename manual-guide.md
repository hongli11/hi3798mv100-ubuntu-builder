# 手动刷机指南

> 本文档整理了手动为 hi3798mv100 电视盒子构建 Ubuntu 根文件系统并刷机的完整流程。

## 前置准备

### 下载材料

1. **TTL 刷机包** — 从 [ecoo.top](https://www.ecoo.top/download) 下载对应型号的 TTL 包
2. **Ubuntu Base 官方镜像**（armhf）
   ```bash
   wget https://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.5-base-armhf.tar.gz
   ```

### 安装依赖

```bash
sudo apt-get install qemu-user-static
```

## 步骤 1：提取原始根文件系统

```bash
# 解压 TTL 刷机包，找到 rootfs-32.img
# 将 rootfs-32.img 上传到构建主机

# 挂载镜像
sudo mount /home/hongli/rootfs-32.img /mnt/
```

## 步骤 2：创建 Ubuntu 基础系统

```bash
mkdir ubuntu
sudo tar -xpf ubuntu-base-20.04.5-base-armhf.tar.gz -C ubuntu/

# 复制 QEMU 模拟器和 DNS 配置
sudo cp /etc/resolv.conf ubuntu/etc/resolv.conf
sudo cp /usr/bin/qemu-arm-static ubuntu/usr/bin/
```

### 配置软件源

编辑 `ubuntu/etc/apt/sources.list`，内容如下：

```
deb http://repo.huaweicloud.com/ubuntu-ports/ focal main restricted
deb http://repo.huaweicloud.com/ubuntu-ports/ focal-updates main restricted
deb http://repo.huaweicloud.com/ubuntu-ports/ focal universe
deb http://repo.huaweicloud.com/ubuntu-ports/ focal-updates universe
deb http://repo.huaweicloud.com/ubuntu-ports/ focal multiverse
deb http://repo.huaweicloud.com/ubuntu-ports/ focal-updates multiverse
deb http://repo.huaweicloud.com/ubuntu-ports/ focal-backports main restricted universe multiverse
deb http://repo.huaweicloud.com/ubuntu-ports/ focal-security main restricted
deb http://repo.huaweicloud.com/ubuntu-ports/ focal-security universe
deb http://repo.huaweicloud.com/ubuntu-ports/ focal-security multiverse
```

## 步骤 3：进入 Chroot 环境

```bash
# 挂载虚拟文件系统
sudo mount -o bind /proc ubuntu/proc
sudo mount -o bind /dev ubuntu/dev

# 进入 chroot 环境
sudo chroot ubuntu
```

## 步骤 4：在 Chroot 内配置系统

### 安装基础软件包

```bash
apt update
apt install rsyslog systemd
apt install sudo htop vim bash-completion
apt install ssh net-tools ethtool ifupdown iputils-ping network-manager
```

### 配置网络

创建 `/etc/network/interfaces.d/eth0`：

**DHCP 模式：**
```
auto eth0
iface eth0 inet dhcp
pre-up ifconfig eth0 hw ether 10:10:10:10:10:10
```

**静态 IP 模式：**
```
auto eth0
iface eth0 inet static
address 192.168.1.10
netmask 255.255.255.0
gateway 192.168.1.1
dns-nameservers 223.5.5.5
dns-nameservers 223.6.6.6
pre-up ifconfig eth0 hw ether 10:10:10:10:10:20
```

> 静态 IP 地址请根据实际网络环境修改。

### 配置主机名

```bash
echo "hi3798mv100" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "127.0.0.1 hi3798mv100" >> /etc/hosts
```

### 配置时区

```bash
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
```

### 配置 rc-local 服务

```bash
ln -s /lib/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
echo "[Install]" >> /etc/systemd/system/rc-local.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/rc-local.service
echo "Alias=rc-local.service" >> /etc/systemd/system/rc-local.service

systemctl enable rc-local.service
```

### 禁用不必要的服务

```bash
systemctl stop motd-news.timer
systemctl mask motd-news.timer
systemctl stop motd-news.service
systemctl mask motd-news.service
systemctl stop networkd-dispatcher
systemctl mask networkd-dispatcher
```

### 设置 root 密码

```bash
passwd
```

### 允许 root SSH 登录

```bash
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
```

### 退出 Chroot

```bash
exit
```

## 步骤 5：替换刷机包中的根文件系统

### 卸载临时挂载

```bash
sudo umount ubuntu/dev
sudo umount ubuntu/proc
```

### 拷贝到镜像文件

```bash
# 先删除原内容
sudo rm -rf /mnt/*

# 拷贝新系统
sudo cp -R ubuntu/* /mnt/

# 卸载镜像
sudo umount /mnt/
```

将制作好的 `rootfs-32.img` 下载下来，替换原 TTL 刷机包中的同名文件即可。

## 步骤 6：备份分区刷机（可选）

如需通过备份分区刷机：

```bash
# 挂载 backup 分区
mkdir /bak && sudo mount /dev/mmcblk0p8 /bak && cd /bak

# 删除旧备份
rm backup-32.gz

# 将新系统拷贝到 backup-32 文件（方法同步骤 5）
# 使用高压缩率打包
gzip -9 -c rootfs-32.img > backup-32.gz

# 上传 backup-32.gz 到 /bak 目录
# 最后执行命令
recoverbackup
```

## 步骤 7：首次启动

开机后先执行扩展文件系统：

```bash
resize2fs /dev/mmcblk0p9
```

## 附录：安装 Docker

一键安装命令：

```bash
bash <(curl -sSL https://gitee.com/SuperManito/LinuxMirrors/raw/main/DockerInstallation.sh)
```