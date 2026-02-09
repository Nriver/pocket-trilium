# Termux 中构建最小 Node.js Debian rootfs（arm64）

<p align="center">
<a href="rootfs.md">English</a> | **简体中文**
</p>

适用于在 Termux 中构建轻量级、可直接打包进 Android App 的 Debian rootfs（带 Node.js 18.20.4）。

## 1. 准备工作

```bash
# 更新并安装必要工具
pkg update -y && pkg upgrade -y
pkg install -y proot debootstrap wget tar xz-utils
```

## 2. 创建工作目录

```bash
mkdir -p ~/minimal-node-rootfs
cd ~/minimal-node-rootfs
```

## 3. 使用 debootstrap 创建最小 Debian rootfs

```bash
debootstrap --arch=arm64 \
  --variant=minbase \
  --include=apt,coreutils,dash,libc-bin,ca-certificates \
  stable ./rootfs https://mirrors.tuna.tsinghua.edu.cn/debian/
```

## 4. 创建必要目录并添加 pocket 用户

```bash
mkdir -p ./rootfs/home/pocket
mkdir -p ./rootfs/root
mkdir -p ./rootfs/var/log

# 手动创建 pocket 用户（UID/GID 1000）
echo "pocket:x:1000:1000::/home/pocket:/bin/dash" >> ./rootfs/etc/passwd
echo "pocket:x:1000:" >> ./rootfs/etc/group
```

## 5. 安装 Node.js v18.20.4

```bash
curl -O https://nodejs.org/dist/v18.20.4/node-v18.20.4-linux-arm64.tar.xz

tar -xJf node-v18.20.4-linux-arm64.tar.xz -C ./rootfs/usr/local --strip-components=1
```

## 6. 创建启动脚本

### 6.1 root 用户启动脚本（start.sh）

```bash
cat > start.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD
exec proot -0 -r ./rootfs \
  -b /dev -b /proc -b /sys -b /sdcard \
  -w / \
  /bin/dash
EOF

chmod +x start.sh
```

### 6.2 普通用户（pocket）启动脚本（推荐使用）

```bash
cat > pocket_login.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD

mkdir -p rootfs/home/pocket

exec proot --link2symlink \
  -r ./rootfs \
  -b /dev -b /proc -b /sys -b /sdcard \
  -i 1000:1000 \
  -w /home/pocket \
  /bin/dash -c "export HOME=/home/pocket; export USER=pocket; export LOGNAME=pocket; \
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; \
  exec /bin/dash -l"
EOF

chmod +x pocket_login.sh
```

## 7. 进入 rootfs 并测试

```bash
# 使用普通用户登录
./pocket_login.sh
```

进入后执行：

```bash
/usr/local/bin/node -v
/usr/local/bin/node -e "console.log('Hello Node!')"
```

测试完成后退出：

```bash
/bin/apt clean
exit
```

## 8. 清理 rootfs（大幅减小体积）

```bash
# 在 Termux 中执行
rm -rf ./rootfs/usr/local/share/doc
rm -rf ./rootfs/usr/local/share/man
rm -rf ./rootfs/usr/share/locale/
rm -rf ./rootfs/var/lib/apt/lists/*
rm -rf ./rootfs/var/cache/apt/archives/*.deb

# 可选：删除下载的 Node 源码包
# rm node-v18.20.4-linux-arm64.tar.xz
```

## 9. 打包 rootfs

```bash
rm -f debian.tar.xz

tar -Jcpvf debian.tar.xz --exclude=".l2s.*" -C ./rootfs \
  bin boot etc home lib media mnt opt root run sbin sd srv tmp usr var
```

## 10. 复制到内置存储并传到电脑

```bash
cp debian.tar.xz ~/storage/shared/debian.tar.xz
```

然后将 `debian.tar.xz` 传输到电脑，放到 Flutter 项目中：

```
/home/nate/AndroidStudioProjects/tiny_computer/assets/
```

## 11. 在电脑端处理（Flutter 资产限制）

```bash
# 拆分大文件（每份 98MB，解决 Flutter 资产大小限制）
split -b 98M debian.tar.xz

# 清理并重新编译
flutter clean
flutter pub get
```
