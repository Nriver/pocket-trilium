# Termux-packages JNI Library Compilation Guide (arm64-v8a)

<p align="center">
** English ** | <a href="jniLibs_CN.md">简体中文</a>
</p>

This guide explains how to cross-compile the required native libraries from the `Nriver/termux-packages` repository for Android JNI (arm64-v8a).

## Compilation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/Nriver/termux-packages.git
cd termux-packages
```

### 2. Start Docker Cross-Compilation Environment

```bash
./scripts/run-docker.sh
```

### 3. Enter Root and Switch Directory

```bash
sudo -i
cd /home/builder/termux-packages
```

### 4. Set NDK Environment Variables

```bash
export ANDROID_NDK_HOME=/home/builder/lib/android-ndk-r29
export NDK=/home/builder/lib/android-ndk-r29
export TERMUX_NDK=/home/builder/lib/android-ndk-r29
```

### 5. (Optional) Set Proxy

If you have network issues, configure the proxy:

```bash
export ALL_PROXY=http://192.168.1.100:20809
export HTTP_PROXY=http://192.168.1.100:20809
export HTTPS_PROXY=http://192.168.1.100:20809

git config --global --replace-all http.proxy 'http://192.168.1.100:20809'
git config --global --replace-all https.proxy 'http://192.168.1.100:20809'
```

### 6. Remove Unnecessary Packages (Recommended)

```bash
# Comment out packages you don't need
sed -i '/pull_package virglrenderer-android/ s/^/#/' ./scripts/generate-bootstraps.sh
```

### 7. Start Compilation

```bash
./scripts/generate-bootstraps.sh
```

> **Note**: The compilation may take a long time (10–30+ minutes). Please be patient.

## Post-Compilation Processing

After compilation, many `.deb` packages will be generated.

### Required Files to Extract

Extract the following `.so` files from the corresponding `.deb` packages and **remove the version suffix** (e.g., `libpcre2-8.so.0` → `libpcre2-8.so`):

```bash
libacl.so
libandroid-selinux.so
libattr.so
libbusybox.so
libcharset.so
libexec_busybox.so
libexec_proot.so
libexec_tar.so
libiconv.so
libpcre2-8.so
libproot-loader.so
libtalloc.so
```

### Final Directory in Android Project

Place the files in:

```
src/main/jniLibs/arm64-v8a/
├── libacl.so
├── libandroid-selinux.so
├── libattr.so
├── libbusybox.so
├── libcharset.so
├── libexec_busybox.so
├── libexec_proot.so
├── libexec_tar.so
├── libiconv.so
├── libpcre2-8.so
├── libproot-loader.so
└── libtalloc.so
```