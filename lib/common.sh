#!/bin/bash
# ============================================================
# lib/common.sh — hi3798mv100 纯净 Ubuntu rootfs 构建核心
# TTL 版与 USB 版共用，由 build_rootfs.sh / build_usb_rootfs.sh 调用
#
# 可配置环境变量（均有默认值）：
#   MODE            ttl | usb                    （由包装脚本设置）
#   UBUNTU_VERSION  Ubuntu Base 版本号           （默认 20.04.5）
#   BASE_URL        Ubuntu Base 下载目录         （默认 cdimage.ubuntu.com 官方）
#   MIRROR          apt 软件源镜像               （默认华为云）
#   HOSTNAME        主机名                        （默认 hi3798mv100）
#   ROOT_PASSWORD   root 密码                     （默认 root123，生产请改!）
#   TIMEZONE        时区                          （默认 Asia/Shanghai）
#   LOCALES         生成的 locale（空格分隔）     （默认 en_US.UTF-8 zh_CN.UTF-8）
#   ROOTFS_DIR      输出目录                      （默认 ./pure_rootfs 或 ./usb_pure_rootfs）
# ============================================================
set -euo pipefail

MODE="${MODE:?请通过 build_rootfs.sh (ttl) 或 build_usb_rootfs.sh (usb) 调用}"
UBUNTU_VERSION="${UBUNTU_VERSION:-20.04.5}"
BASE_URL="${BASE_URL:-https://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release}"
MIRROR="${MIRROR:-http://repo.huaweicloud.com/ubuntu-ports}"
HOSTNAME="${HOSTNAME:-hi3798mv100}"
ROOT_PASSWORD="${ROOT_PASSWORD:-root123}"
TIMEZONE="${TIMEZONE:-Asia/Shanghai}"
LOCALES="${LOCALES:-en_US.UTF-8 zh_CN.UTF-8}"

case "$MODE" in
  ttl) DEFAULT_ROOTFS_DIR="$(pwd)/pure_rootfs" ;;
  usb) DEFAULT_ROOTFS_DIR="$(pwd)/usb_pure_rootfs" ;;
  *)   echo "❌ 未知 MODE: $MODE（仅支持 ttl / usb）" >&2; exit 1 ;;
esac
ROOTFS_DIR="${ROOTFS_DIR:-$DEFAULT_ROOTFS_DIR}"
BASE_TARBALL="ubuntu-base-${UBUNTU_VERSION}-base-armhf.tar.gz"
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 已有 root 权限则直接执行，否则走 sudo
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
  $SUDO -v 2>/dev/null || { echo "❌ 需要 root 权限或可用 sudo" >&2; exit 1; }
fi

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

log() { echo "==> $*"; }

# 脚本退出（含失败/中断）时自动卸载所有挂载点，避免残留
cleanup_mounts() {
  for m in tmp var/cache/apt/archives dev/pts dev sys proc; do
    $SUDO umount -lf "$ROOTFS_DIR/$m" 2>/dev/null || true
  done
}
trap cleanup_mounts EXIT INT TERM

# ---------- 下载 Ubuntu Base 并做 SHA256 完整性校验 ----------
fetch_base() {
  log "下载 Ubuntu Base $UBUNTU_VERSION (armhf)..."
  mkdir -p cache
  (
    cd cache
    wget -q -c --tries=5 --timeout=60 "$BASE_URL/$BASE_TARBALL" || exit 1
    if wget -q --tries=3 --timeout=30 -O SHA256SUMS "$BASE_URL/SHA256SUMS" 2>/dev/null; then
      if grep -F "$BASE_TARBALL" SHA256SUMS | sha256sum -c - >/dev/null 2>&1; then
        echo "✅ SHA256 校验通过"
      else
        echo "❌ SHA256 校验失败，下载可能不完整" >&2
        exit 1
      fi
    else
      echo "⚠️  未获取到 SHA256SUMS，跳过完整性校验"
    fi
  )
}

# ---------- 准备目录并解压 ----------
prepare_rootfs() {
  log "准备目录: $ROOTFS_DIR"
  $SUDO rm -rf "$ROOTFS_DIR"
  mkdir -p "$ROOTFS_DIR"
  log "解压 Ubuntu Base..."
  $SUDO tar --numeric-owner -xpf "cache/$BASE_TARBALL" -C "$ROOTFS_DIR"
}

# ---------- 准备 Chroot 环境（QEMU 模拟 + 虚拟文件系统） ----------
setup_chroot_env() {
  log "准备 Chroot 环境（QEMU 模拟 + 虚拟文件系统）..."
  if [ ! -f /usr/bin/qemu-arm-static ]; then
    echo "❌ 未找到 /usr/bin/qemu-arm-static，请先安装: sudo apt-get install qemu-user-static" >&2
    exit 1
  fi
  $SUDO cp /usr/bin/qemu-arm-static "$ROOTFS_DIR/usr/bin/"
  # 有 binfmt 支持时确保注册（GitHub Runner / Docker 环境下一般已注册）
  command -v update-binfmts >/dev/null 2>&1 && $SUDO update-binfmts --enable qemu-arm 2>/dev/null || true
  $SUDO cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"
  $SUDO mkdir -p "$ROOTFS_DIR"/{proc,sys,dev,dev/pts,tmp,var/cache/apt/archives}
  $SUDO mount -t proc proc "$ROOTFS_DIR/proc"
  $SUDO mount -t sysfs sysfs "$ROOTFS_DIR/sys"
  $SUDO mount -o bind /dev "$ROOTFS_DIR/dev"
  $SUDO mount -o bind /dev/pts "$ROOTFS_DIR/dev/pts"
}

# ---------- 拷贝 chroot 内配置脚本 ----------
write_inner_script() {
  log "生成 Chroot 内配置脚本..."
  chmod +x "$LIB_DIR/rootfs_inner.sh"
  $SUDO cp "$LIB_DIR/rootfs_inner.sh" "$ROOTFS_DIR/tmp/rootfs_inner.sh"
}

# ---------- 执行 chroot 安装配置 ----------
run_inner() {
  log "在 Chroot 中执行安装配置（耗时较长，请耐心等待）..."
  $SUDO chroot "$ROOTFS_DIR" /usr/bin/env \
    MODE="$MODE" MIRROR="$MIRROR" HOSTNAME="$HOSTNAME" \
    ROOT_PASSWORD="$ROOT_PASSWORD" TIMEZONE="$TIMEZONE" LOCALES="$LOCALES" \
    /bin/bash /tmp/rootfs_inner.sh
}

# ---------- 收尾：卸载、清理、输出 ----------
finish() {
  cleanup_mounts
  $SUDO rm -f "$ROOTFS_DIR/tmp/rootfs_inner.sh" "$ROOTFS_DIR/usr/bin/qemu-arm-static" 2>/dev/null || true
  local SIZE
  SIZE="$($SUDO du -sh "$ROOTFS_DIR" | cut -f1)"
  echo "=============================================="
  echo "✅ ${MODE} 版纯净根文件系统构建完成: $ROOTFS_DIR ($SIZE)"
  echo "=============================================="
}

main() {
  log "开始构建 ${MODE} 版纯净根文件系统"
  fetch_base
  prepare_rootfs
  setup_chroot_env
  write_inner_script
  run_inner
  finish
}