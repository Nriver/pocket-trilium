import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

//default values
class D {

  static const String triliumPackage = "trilium.tar.xz";

  // Trilium 可选版本列表
  static const List<Map<String, dynamic>> triliumVersions = [
    {
      'name': '0.63.7-cn',
      'suffix': '(Built-in)',
      'url': 'built-in',
      'filename': 'assets/trilium.tar.xz',
      'lang': 'zh-only',
    },
    {
      'name': '0.102.2',
      'suffix': '(GitHub)',
      'url': 'https://github.com/TriliumNext/Trilium/releases/download/v0.102.2/TriliumNotes-Server-v0.102.2-linux-arm64.tar.xz',
      'lang': 'multi',
    },
    {
      'name': '0.102.2',
      'suffix': '(Gitee)',
      'url': 'https://gitee.com/nriver/pocket-trilium/releases/download/v1/TriliumNotes-Server-v0.102.2-linux-arm64.tar.xz',
      'lang': 'multi',
    },
    {
      'name': '0.102.1',
      'suffix': '(GitHub)',
      'url': 'https://github.com/TriliumNext/Trilium/releases/download/v0.102.1/TriliumNotes-Server-v0.102.1-linux-arm64.tar.xz',
      'lang': 'multi',
    },
    {
      'name': '0.102.1',
      'suffix': '(Gitee)',
      'url': 'https://gitee.com/nriver/pocket-trilium/releases/download/v1/TriliumNotes-Server-v0.102.1-linux-arm64.tar.xz',
      'lang': 'multi',
    },
    {
      'name': '0.102.0',
      'suffix': '(GitHub)',
      'url': 'https://github.com/TriliumNext/Trilium/releases/download/v0.102.0/TriliumNotes-Server-v0.102.0-linux-arm64.tar.xz',
      'lang': 'multi',
    },
    {
      'name': '0.102.0',
      'suffix': '(Gitee)',
      'url': 'https://gitee.com/nriver/pocket-trilium/releases/download/v1/TriliumNotes-Server-v0.102.0-linux-arm64.tar.xz',
      'lang': 'multi',
    },
    {
      'name': '0.101.3',
      'suffix': '(GitHub)',
      'url': 'https://github.com/TriliumNext/Trilium/releases/download/v0.101.3/TriliumNotes-Server-v0.101.3-linux-arm64.tar.xz',
      'lang': 'multi',
    },
    {
      'name': '0.101.3',
      'suffix': '(Gitee)',
      'url': 'https://gitee.com/nriver/pocket-trilium/releases/download/v1/TriliumNotes-Server-v0.101.3-linux-arm64.tar.xz',
      'lang': 'multi',
    },
    {
      'name': '0.63.7',
      'suffix': '(GitHub)',
      'url': 'https://github.com/Nriver/pocket-trilium-resources/releases/download/v1/trilium-0.63.7.tar.xz',
      'lang': 'en-only',
    },
    {
      'name': '0.63.7',
      'suffix': '(Gitee)',
      'url': 'https://gitee.com/nriver/pocket-trilium/releases/download/v1/trilium-0.63.7.tar.xz',
      'lang': 'en-only',
    },
  ];

  static const String containerName = "Pocket Trilium by Nriver";

  // 启动前先杀掉旧的trilium进程, 防止快速多次关闭启动app时旧的进程没有退出导致的问题
  // 判断挂载到手机内部存储的默认数据路径如果无法写入，则写入到app内部目录
  static const String triliumStartCommand = r"""
#pkill -9 node 

export TRILIUM_PORT=8080

cd /home/pocket/trilium

if [ -d "/home/pocket/trilium-data" ] && [ -w "/home/pocket/trilium-data" ]; then
    export TRILIUM_DATA_DIR="/home/pocket/trilium-data"
    echo "Data dir: /home/pocket/trilium-data"
else
    export TRILIUM_DATA_DIR="/home/pocket/.local/share/trilium-data"
    echo "Data dir: /home/pocket/.local/share/trilium-data"
    mkdir -p /home/pocket/.local/share/trilium-data
fi

# use tcmalloc
#export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4
# use jemalloc
export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2

LOG=/tmp/trilium.log
for i in {1..10}; do
    : > "$LOG"
    echo "Starting trilium..."
    ./trilium.sh 2>&1 | tee "$LOG"
    if grep -q "double free or corruption" "$LOG"; then
        echo "Retrying due to 'double free or corruption' ($i/10)"
    else
        exit
    fi
done

sleep 10
""";

  static const String webUrl = "http://127.0.0.1:8080";

  //常用链接
  static const links = [
    {"name": "projectUrl", "value": "https://github.com/Nriver/pocket-trilium"},
    {"name": "issueUrl", "value": "https://github.com/Nriver/pocket-trilium/issues"},
    {"name": "discussionUrl", "value": "https://github.com/Nriver/pocket-trilium/discussions"},
  ];

  //默认小键盘
  static const termCommands = [
    {"name": "Esc", "key": TerminalKey.escape},
    {"name": "Tab", "key": TerminalKey.tab},
    {"name": "↑", "key": TerminalKey.arrowUp},
    {"name": "↓", "key": TerminalKey.arrowDown},
    {"name": "←", "key": TerminalKey.arrowLeft},
    {"name": "→", "key": TerminalKey.arrowRight},
    {"name": "Del", "key": TerminalKey.delete},
    {"name": "PgUp", "key": TerminalKey.pageUp},
    {"name": "PgDn", "key": TerminalKey.pageDown},
    {"name": "Home", "key": TerminalKey.home},
    {"name": "End", "key": TerminalKey.end},
    {"name": "F1", "key": TerminalKey.f1},
    {"name": "F2", "key": TerminalKey.f2},
    {"name": "F3", "key": TerminalKey.f3},
    {"name": "F4", "key": TerminalKey.f4},
    {"name": "F5", "key": TerminalKey.f5},
    {"name": "F6", "key": TerminalKey.f6},
    {"name": "F7", "key": TerminalKey.f7},
    {"name": "F8", "key": TerminalKey.f8},
    {"name": "F9", "key": TerminalKey.f9},
    {"name": "F10", "key": TerminalKey.f10},
    {"name": "F11", "key": TerminalKey.f11},
    {"name": "F12", "key": TerminalKey.f12},
  ];

  static const String boot = "\$DATA_DIR/bin/proot -H --change-id=1000:1000 --pwd=/home/pocket --rootfs=\$CONTAINER_DIR --mount=/system --mount=/apex --mount=/sys --mount=/data --kill-on-exit --mount=/storage --sysvipc -L --link2symlink --mount=/proc --mount=/dev --mount=\$CONTAINER_DIR/tmp:/dev/shm --mount=/dev/urandom:/dev/random --mount=/proc/self/fd:/dev/fd --mount=/proc/self/fd/0:/dev/stdin --mount=/proc/self/fd/1:/dev/stdout --mount=/proc/self/fd/2:/dev/stderr --mount=/dev/null:/dev/tty0 --mount=/dev/null:/proc/sys/kernel/cap_last_cap --mount=\$DATA_DIR/trilium:/home/pocket/trilium \$EXTRA_MOUNT /usr/bin/env -i HOSTNAME=POCKET HOME=/home/pocket USER=pocket TERM=xterm-256color TMPDIR=/tmp LANG=zh_CN.UTF-8 SHELL=/bin/bash PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games /bin/bash -l";

  static final ButtonStyle commandButtonStyle = OutlinedButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(0, 0),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2)
  );


  static final ButtonStyle controlButtonStyle = OutlinedButton.styleFrom(
      textStyle: const TextStyle(fontWeight: FontWeight.w400),
      side: const BorderSide(color: Color(0x1F000000)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(0, 0),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4)
  );

  static const MethodChannel androidChannel = MethodChannel("android");

}