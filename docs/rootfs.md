# Building a Minimal Node.js Debian rootfs (arm64) in Termux

<p align="center">
** English ** | <a href="rootfs_CN.md">简体中文</a>
</p>

A step-by-step guide to create a lightweight Debian rootfs with Node.js 18.20.4 in Termux, suitable for packaging into Android apps.

## 1. Preparation

```bash
# Update and install required tools
pkg update -y && pkg upgrade -y
pkg install -y proot debootstrap wget tar xz-utils
```

## 2. Create Working Directory

```bash
mkdir -p ~/minimal-node-rootfs
cd ~/minimal-node-rootfs
```

## 3. Create Minimal Debian rootfs using debootstrap

```bash
debootstrap --arch=arm64 \
  --variant=minbase \
  --include=apt,coreutils,dash,libc-bin,ca-certificates \
  stable ./rootfs https://mirrors.tuna.tsinghua.edu.cn/debian/
```

## 4. Create Directories and Add pocket User

```bash
mkdir -p ./rootfs/home/pocket
mkdir -p ./rootfs/root
mkdir -p ./rootfs/var/log

# Manually create pocket user (UID/GID 1000)
echo "pocket:x:1000:1000::/home/pocket:/bin/dash" >> ./rootfs/etc/passwd
echo "pocket:x:1000:" >> ./rootfs/etc/group
```

## 5. Install Node.js v18.20.4

```bash
curl -O https://nodejs.org/dist/v18.20.4/node-v18.20.4-linux-arm64.tar.xz

tar -xJf node-v18.20.4-linux-arm64.tar.xz -C ./rootfs/usr/local --strip-components=1
```

## 6. Create Startup Scripts

### 6.1 Root User Script (`start.sh`)

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

### 6.2 Regular User Script (`pocket_login.sh`) — Recommended

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

## 7. Enter rootfs and Test Node.js

```bash
# Login as pocket user
./pocket_login.sh
```

Inside the rootfs, run:

```bash
/usr/local/bin/node -v
/usr/local/bin/node -e "console.log('Hello Node!')"
```

After testing, clean and exit:

```bash
/bin/apt clean
exit
```

## 8. Clean up rootfs (Reduce Size)

```bash
# Run these commands in Termux
rm -rf ./rootfs/usr/local/share/doc
rm -rf ./rootfs/usr/local/share/man
rm -rf ./rootfs/usr/share/locale/
rm -rf ./rootfs/var/lib/apt/lists/*
rm -rf ./rootfs/var/cache/apt/archives/*.deb

# Optional: remove the downloaded Node.js archive
# rm node-v18.20.4-linux-arm64.tar.xz
```

## 9. Package the rootfs

```bash
rm -f debian.tar.xz

tar -Jcpvf debian.tar.xz --exclude=".l2s.*" -C ./rootfs \
  bin boot etc home lib media mnt opt root run sbin sd srv tmp usr var
```

## 10. Copy to Internal Storage

```bash
cp debian.tar.xz ~/storage/shared/debian.tar.xz
```

Transfer `debian.tar.xz` to your computer and place it in your Flutter project:

```
~/AndroidStudioProjects/tiny_computer/assets/
```

## 11. Split File on Computer (Flutter Asset Limit)

```bash
# Split into 98MB chunks
split -b 98M debian.tar.xz

# Clean and rebuild Flutter project
flutter clean
flutter pub get
```
