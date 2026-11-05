# Termux-packages JNI 库编译说明（arm64-v8a）

<p align="center">
<a href="jniLibs.md">English</a> | **简体中文**
</p>

本文档记录了使用 `Nriver/termux-packages` 仓库交叉编译 Android JNI 所需原生库的完整流程。

## 编译步骤

### 1. 克隆仓库

```bash
git clone https://github.com/Nriver/termux-packages.git
cd termux-packages
```

### 2. 启动 Docker 交叉编译环境

```bash
./scripts/run-docker.sh
```

### 3. 进入容器并切换目录

```bash
sudo -i
cd /home/builder/termux-packages
```

### 4. 设置 NDK 环境变量

```bash
export ANDROID_NDK_HOME=/home/builder/lib/android-ndk-r30
export NDK=/home/builder/lib/android-ndk-r30
export TERMUX_NDK=/home/builder/lib/android-ndk-r30
```

### 5. （可选）设置代理

如果无法连接网络，可设置代理。把 `192.168.1.100` 换成**宿主机实际的局域网 IP**，端口保持 `20809`（容器内不能用 `127.0.0.1`）：

```bash
export ALL_PROXY=http://192.168.1.100:20809
export HTTP_PROXY=http://192.168.1.100:20809
export HTTPS_PROXY=http://192.168.1.100:20809

git config --global --replace-all http.proxy 'http://192.168.1.100:20809'
git config --global --replace-all https.proxy 'http://192.168.1.100:20809'
```

如果之前设置过其它 IP，务必用上面的 `--replace-all` 覆盖旧的 `git` 代理配置，否则克隆源码时仍会走旧代理。

### 6. 移除不需要的包（推荐）

```bash
# 注释掉 virglrenderer-android 等不需要的包
sed -i '/pull_package virglrenderer-android/ s/^/#/' ./scripts/generate-bootstraps.sh
```

### 7. 开始编译

```bash
./scripts/generate-bootstraps.sh
```

> **注意**：编译时间较长（可能十几分钟到半小时），请耐心等待。

## 编译结果处理

编译完成后会生成大量 `.deb` 包。

### 需要提取的文件（arm64-v8a）

从对应 deb 包中提取以下 `.so` 文件，并**去掉版本号后缀**：

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

### 最终放置目录（Android 项目）

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
