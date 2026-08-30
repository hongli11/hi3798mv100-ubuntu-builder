# hi3798mv100-ubuntu-builder

为海思 hi3798mv100 平台（华为悦盒、EC6108V9 等电视盒子）构建纯净 Ubuntu 根文件系统的自动化工具。

## 特点

- 🧹 **纯净系统** — 基于官方 Ubuntu Base 20.04 (armhf) 构建，无第三方杂质
- 🤖 **CI 自动化** — GitHub Actions 自动构建，下载即用；可自定义刷机包地址 / Ubuntu Base 版本 / 镜像源 / 密码
- 📦 **双模式支持** — TTL 刷机包 / USB 刷机包，核心逻辑共用一套（`lib/`），只留薄包装入口
- 🇨🇳 **国内镜像** — 默认使用华为云镜像源，加速软件包下载
- 🔒 **完整性校验** — 自动下载 SHA256SUMS 校验 Ubuntu Base 镜像，杜绝坏包
- 🧱 **构建更稳** — 失败/中断时自动卸载全部挂载点不留残留；构建期挂载 tmpfs 防小磁盘主机空间不足
- ⚡ **体积更小** — `--no-install-recommends` 安装 + 清理 man/info 手册 + apt 缓存清零
- 🚀 **开箱即用** — 预生成 SSH 主机密钥与 machine-id，首次开机不再等待；屏蔽 motd-news 与 apt 每日定时器，低配盒子更省资源

## 前置依赖

在本地构建需要：

```bash
sudo apt-get install qemu-user-static
```

## 快速开始

### 本地构建

```bash
# 构建 TTL 版根文件系统
chmod +x build_rootfs.sh
sudo ./build_rootfs.sh

# 构建 USB 版根文件系统
chmod +x build_usb_rootfs.sh
sudo ./build_usb_rootfs.sh
```

### 可配置环境变量

两个脚本均支持通过环境变量覆盖默认配置：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `UBUNTU_VERSION` | Ubuntu Base 版本号 | `20.04.5` |
| `BASE_URL` | Ubuntu Base 下载目录 | `https://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release` |
| `MIRROR` | apt 软件源镜像 | `http://repo.huaweicloud.com/ubuntu-ports` |
| `HOSTNAME` | 主机名 | `hi3798mv100` |
| `ROOT_PASSWORD` | root 密码 | `root123` |
| `TIMEZONE` | 时区 | `Asia/Shanghai` |
| `LOCALES` | 生成的 locale（空格分隔） | `en_US.UTF-8 zh_CN.UTF-8` |
| `ROOTFS_DIR` | 输出目录 | `./pure_rootfs` (TTL) / `./usb_pure_rootfs` (USB) |

示例：

```bash
ROOT_PASSWORD='MySecurePass' UBUNTU_VERSION=20.04.6 ./build_rootfs.sh
```

> ⚠️ 生产环境使用请务必修改默认密码！

### CI 构建（推荐）

1. Fork 本仓库
2. 进入 Actions 页面
3. 选择 **Build Pure TTL Package** 或 **Build Pure USB Package**
4. 点击 **Run workflow** — 可在表单中自定义刷机包地址、Ubuntu Base 版本、镜像源、root 密码
5. 等待构建完成，下载 Artifacts

## 输出产物

| 工作流 | 产物格式 | 说明 |
|--------|----------|------|
| Build Pure TTL Package | `TTL-hi3798mv100-32bit-PURE-<日期>.zip` | 替换原 TTL 包中的 `rootfs-32.img` 使用 |
| Build Pure USB Package | `USB-hi3798mv100-mdmo1g-PURE-<日期>.zip` | 替换原 USB 包中的 `www_ecoo_top.ext4` 使用 |

## 手动刷机指南

见 [manual-guide.md](manual-guide.md)

## 文件结构

```
├── build_rootfs.sh                  # TTL 版入口（薄包装）
├── build_usb_rootfs.sh              # USB 版入口（薄包装）
├── lib/
│   ├── common.sh                    # 共用构建核心（下载/校验/chroot/自动清理）
│   └── rootfs_inner.sh              # chroot 内执行的系统配置脚本
├── manual-guide.md                  # 手动刷机指南
├── .github/workflows/
│   ├── build-pure-ttl-package.yml   # TTL 包 CI 工作流
│   └── build-pure-usb-package.yml   # USB 包 CI 工作流
├── .gitignore
└── README.md
```

## 技术细节

- 基于 **Ubuntu Base 20.04.5 (armhf)** 官方镜像（下载后自动 SHA256 校验）
- 使用 **QEMU 用户态模拟**（`qemu-arm-static`）在 x86 主机上构建 armhf 根文件系统
- 通过 **chroot** 进入目标系统环境安装软件包和配置
- 软件源使用 **华为云 Ubuntu Ports 镜像**（`repo.huaweicloud.com`）
- 构建期在 chroot 内挂载 tmpfs 到 `/tmp` 与 apt 缓存目录，避免磁盘空间不足
- 安装使用 `--no-install-recommends`，并清理 man/info 手册与 apt 缓存，减小最终体积
- 已做系统优化：预生成 SSH 主机密钥与 machine-id、启用 systemd-timesyncd、屏蔽 motd-news 与 apt 每日定时器、默认进入 multi-user.target
- 内置包：systemd/udev、网络工具（ifupdown/iproute2/net-tools/ethtool/ping）、openssh-server、e2fsprogs、ca-certificates、locales/tzdata、vim-tiny/less/htop 等

## License

MIT