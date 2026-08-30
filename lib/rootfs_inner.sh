#!/bin/bash
# lib/rootfs_inner.sh — 在 chroot 内执行的系统配置脚本
# 所需变量由 common.sh 通过 /usr/bin/env 传入：
#   MODE MIRROR HOSTNAME ROOT_PASSWORD TIMEZONE LOCALES
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C LANG=C
export SYSTEMD_OFFLINE=1

echo "==> [${MODE} 模式] 构建期挂载 tmpfs（省磁盘、防空间不足）"
mount -t tmpfs tmpfs /tmp 2>/dev/null || true
mkdir -p /var/cache/apt/archives
mount -t tmpfs tmpfs /var/cache/apt/archives 2>/dev/null || true

echo "==> 配置软件源: $MIRROR"
cat > /etc/apt/sources.list << SOURCES
deb $MIRROR focal main restricted universe multiverse
deb $MIRROR focal-updates main restricted universe multiverse
deb $MIRROR focal-security main restricted universe multiverse
deb $MIRROR focal-backports main restricted universe multiverse
SOURCES

echo "==> 更新软件源并安装核心软件包（--no-install-recommends 精简体积）"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  systemd systemd-sysv dbus udev \
  ifupdown iproute2 net-tools iputils-ping ethtool procps \
  openssh-server ssh sudo \
  e2fsprogs ca-certificates \
  vim-tiny less htop wget curl cron rsyslog bash-completion \
  locales tzdata

echo "==> 基础系统配置"
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1 localhost
127.0.1.1 $HOSTNAME
HOSTS
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1 || true
echo "root:$ROOT_PASSWORD" | chpasswd
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

echo "==> 网络配置 (DHCP)"
mkdir -p /etc/network/interfaces.d
cat > /etc/network/interfaces.d/eth0 << ETH0
auto eth0
iface eth0 inet dhcp
ETH0

echo "==> 生成 locale: $LOCALES"
locale-gen $LOCALES >/dev/null 2>&1 || true
update-locale LANG=en_US.UTF-8 >/dev/null 2>&1 || true

echo "==> 预生成 machine-id 与 SSH 主机密钥（首次开机免等待）"
systemd-machine-id-setup 2>/dev/null || true
ssh-keygen -A 2>/dev/null || true

echo "==> 服务优化（低配盒子减负）"
systemctl enable ssh networking systemd-timesyncd 2>/dev/null || true
systemctl mask motd-news.timer motd-news.service 2>/dev/null || true
systemctl mask apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
systemctl set-default multi-user.target 2>/dev/null || true

echo "==> Shell 体验优化"
cat > /root/.bashrc << 'BASHRC'
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc
[ -f /etc/bash_completion ] && . /etc/bash_completion
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
BASHRC

echo "==> DNS 兜底配置（DHCP 分配后会被覆盖）"
cat > /etc/resolv.conf << 'RESOLV'
nameserver 223.5.5.5
nameserver 223.6.6.6
RESOLV

echo "==> 深度清理"
apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* /root/.cache 2>/dev/null || true
rm -rf /usr/share/man /usr/share/info /usr/share/lintian /usr/share/linda 2>/dev/null || true
rm -f /usr/bin/qemu-arm-static

echo "✅ Chroot 内配置完成"