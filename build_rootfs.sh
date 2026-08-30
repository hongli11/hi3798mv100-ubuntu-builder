#!/bin/bash
# build_rootfs.sh — TTL 版纯净根文件系统构建入口
# 产物用于替换 TTL 刷机包中的 rootfs-32.img
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MODE=ttl
source "$SCRIPT_DIR/lib/common.sh"
main