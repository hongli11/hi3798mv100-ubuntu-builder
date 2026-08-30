#!/bin/bash
# build_usb_rootfs.sh — USB 版纯净根文件系统构建入口
# 产物用于替换 USB 刷机包中的 www_ecoo_top.ext4
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MODE=usb
source "$SCRIPT_DIR/lib/common.sh"
main