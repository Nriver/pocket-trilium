import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:tiny_computer/l10n/app_localizations.dart';

import 'package:avnc_flutter/avnc_flutter.dart';
import 'package:x11_flutter/x11_flutter.dart';

import 'fullScreenWebPage.dart';

class Util {

  static Future<void> copyAsset(String src, String dst) async {
    await File(dst).writeAsBytes((await rootBundle.load(src)).buffer.asUint8List());
  }
  static Future<void> copyAsset2(String src, String dst) async {
    ByteData data = await rootBundle.load(src);
    await File(dst).writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }
  static void createDirFromString(String dir) {
    Directory.fromRawPath(const Utf8Encoder().convert(dir)).createSync(recursive: true);
  }

  static Future<int> execute(String str) async {
    Pty pty = Pty.start(
      "/system/bin/sh"
    );
    pty.write(const Utf8Encoder().convert("$str\nexit \$?\n"));
    return await pty.exitCode;
  }

  static void termWrite(String str) {
    G.termPtys[G.currentContainer]!.pty.write(const Utf8Encoder().convert("$str\n"));
  }



  //所有key
  //int defaultContainer = 0: 默认启动第0个容器
  //int defaultAudioPort = 4718: 默认pulseaudio端口(为了避免和其它软件冲突改成4718了，原默认4713)
  //bool autoLaunchVnc = true: 是否自动启动图形界面并跳转 以前只支持VNC就这么起名了
  //String lastDate: 上次启动软件的日期，yyyy-MM-dd
  //bool isTerminalWriteEnabled = false
  //bool isTerminalCommandsEnabled = false 
  //int termMaxLines = 4095 终端最大行数
  //double termFontScale = 1 终端字体大小
  //bool isStickyKey = true 终端ctrl, shift, alt键是否粘滞
  //String defaultFFmpegCommand 默认推流命令
  //bool reinstallBootstrap = false 下次启动是否重装引导包
  //bool wakelock = false 屏幕常亮
  //bool isHidpiEnabled = false 是否开启高分辨率
  //bool useAvnc = false 是否默认使用AVNC
  //bool avncResizeDesktop = true 是否默认AVNC按当前屏幕大小调整分辨率
  //double avncScaleFactor = -0.5 AVNC：在当前屏幕大小的基础上调整缩放的比例。范围-1~1，对应比例4^-1~4^1
  //String defaultHidpiOpt 默认HiDPI环境变量
  //? int bootstrapVersion: 启动包版本
  //String[] containersInfo: 所有容器信息(json)
  //{name, boot:"\$DATA_DIR/bin/proot ...", appStartCommand:"...", webUrl:"...", commands:[{name:"更新和升级", command:"apt update -y && apt upgrade -y"},
  // bind:[{name:"U盘", src:"/storage/xxxx", dst:"/media/meow"}]...]}
  //TODO: 这么写还是不对劲，有空改成类试试？
  static dynamic getGlobal(String key) {
    bool b = G.prefs.containsKey(key);
    switch (key) {
      case "defaultContainer" : return b ? G.prefs.getInt(key)! : (value){G.prefs.setInt(key, value); return value;}(0);
      case "defaultAudioPort" : return b ? G.prefs.getInt(key)! : (value){G.prefs.setInt(key, value); return value;}(4718);
      case "autoLaunchVnc" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(true);
      case "lastDate" : return b ? G.prefs.getString(key)! : (value){G.prefs.setString(key, value); return value;}("1970-01-01");
      case "isTerminalWriteEnabled" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(false);
      case "isTerminalCommandsEnabled" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(false);
      case "termMaxLines" : return b ? G.prefs.getInt(key)! : (value){G.prefs.setInt(key, value); return value;}(4095);
      case "termFontScale" : return b ? G.prefs.getDouble(key)! : (value){G.prefs.setDouble(key, value); return value;}(1.0);
      case "isStickyKey" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(true);
      case "reinstallBootstrap" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(false);
      case "wakelock" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(false);
      case "isHidpiEnabled" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(false);
      // disable avnc to load webpage by default
      case "useAvnc" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(false);
      case "avncResizeDesktop" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(true);
      case "avncScaleFactor" : return b ? G.prefs.getDouble(key)!.clamp(-1.0, 1.0) : (value){G.prefs.setDouble(key, value); return value;}(-0.5);
      case "useX11" : return b ? G.prefs.getBool(key)! : (value){G.prefs.setBool(key, value); return value;}(false);
      case "defaultFFmpegCommand" : return b ? G.prefs.getString(key)! : (value){G.prefs.setString(key, value); return value;}("-hide_banner -an -max_delay 1000000 -r 30 -f android_camera -camera_index 0 -i 0:0 -vf scale=iw/2:-1 -rtsp_transport udp -f rtsp rtsp://127.0.0.1:8554/stream");
      case "defaultHidpiOpt" : return b ? G.prefs.getString(key)! : (value){G.prefs.setString(key, value); return value;}("GDK_SCALE=2 QT_FONT_DPI=192");
      case "containersInfo" : return G.prefs.getStringList(key)!;
    }
  }

  static dynamic getCurrentProp(String key) {
    dynamic m = jsonDecode(Util.getGlobal("containersInfo")[G.currentContainer]);
    if (m.containsKey(key)) {
      return m[key];
    }
    switch (key) {
      case "name" : return (value){addCurrentProp(key, value); return value;}(D.containerName);
      case "boot" : return (value){addCurrentProp(key, value); return value;}(D.boot);
      case "appStartCommand" : return (value){addCurrentProp(key, value); return value;}(D.triliumStartCommand);
      // case "webUrl" : return (value){addCurrentProp(key, value); return value;}("http://localhost:36082/vnc.html?host=localhost&port=36082&autoconnect=true&resize=remote&password=12345678");
      // Trilium homepage
      case "webUrl" : return (value){addCurrentProp(key, value); return value;}(D.webUrl);
      case "vncUri" : return (value){addCurrentProp(key, value); return value;}("vnc://127.0.0.1:5904?VncPassword=12345678&SecurityType=2");
      case "commands" : return (value){addCurrentProp(key, value); return value;}(jsonDecode(jsonEncode(D.commands)));
    }
  }

  //用来设置name, boot, vnc, webUrl等
  static Future<void> setCurrentProp(String key, dynamic value) async {
    await G.prefs.setStringList("containersInfo",
      Util.getGlobal("containersInfo")..setAll(G.currentContainer,
        [jsonEncode((jsonDecode(
          Util.getGlobal("containersInfo")[G.currentContainer]
        ))..update(key, (v) => value))]
      )
    );
  }

  //用来添加不存在的key等
  static Future<void> addCurrentProp(String key, dynamic value) async {
    await G.prefs.setStringList("containersInfo",
      Util.getGlobal("containersInfo")..setAll(G.currentContainer,
        [jsonEncode((jsonDecode(
          Util.getGlobal("containersInfo")[G.currentContainer]
        ))..addAll({key : value}))]
      )
    );
  }

  //限定字符串在min和max之间, 给文本框的validator
  static String? validateBetween(String? value, int min, int max, Function opr) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(G.homePageStateContext)!.enterNumber;
    }
    int? parsedValue = int.tryParse(value);
    if (parsedValue == null) {
      return AppLocalizations.of(G.homePageStateContext)!.enterValidNumber;
    }
    if (parsedValue < min || parsedValue > max) {
      return "请输入$min到$max之间的数字";
    }
    opr();
    return null;
  }

  static Future<bool> isXServerReady(String host, int port, {int timeoutSeconds = 5}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: Duration(seconds: timeoutSeconds));
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> waitForXServer() async {
    const host = '127.0.0.1';
    const port = 7897;
    
    while (true) {
      bool isReady = await isXServerReady(host, port);
      await Future.delayed(Duration(seconds: 1));
      if (isReady) {
        return;
      }
    }
  }

  static String getl10nText(String key, BuildContext context) {
    switch (key) {
      case 'projectUrl':
        return AppLocalizations.of(context)!.projectUrl;
      case 'issueUrl':
        return AppLocalizations.of(context)!.issueUrl;
      case 'discussionUrl':
        return AppLocalizations.of(context)!.discussionUrl;
      default:
        return AppLocalizations.of(context)!.projectUrl;
    }
  }

}

//来自xterms关于操作ctrl, shift, alt键的示例
//这个类应该只能有一个实例G.keyboard
class VirtualKeyboard extends TerminalInputHandler with ChangeNotifier {
  final TerminalInputHandler _inputHandler;

  VirtualKeyboard(this._inputHandler);

  bool _ctrl = false;

  bool get ctrl => _ctrl;

  set ctrl(bool value) {
    if (_ctrl != value) {
      _ctrl = value;
      notifyListeners();
    }
  }

  bool _shift = false;

  bool get shift => _shift;

  set shift(bool value) {
    if (_shift != value) {
      _shift = value;
      notifyListeners();
    }
  }

  bool _alt = false;

  bool get alt => _alt;

  set alt(bool value) {
    if (_alt != value) {
      _alt = value;
      notifyListeners();
    }
  }

  @override
  String? call(TerminalKeyboardEvent event) {
    final ret = _inputHandler.call(event.copyWith(
      ctrl: event.ctrl || _ctrl,
      shift: event.shift || _shift,
      alt: event.alt || _alt,
    ));
    G.maybeCtrlJ = event.key.name == "keyJ"; //这个是为了稍后区分按键到底是Enter还是Ctrl+J
    if (!(Util.getGlobal("isStickyKey") as bool)) {
      G.keyboard.ctrl = false;
      G.keyboard.shift = false;
      G.keyboard.alt = false;
    }
    return ret;
  }
}

//一个结合terminal和pty的类
class TermPty {
  late final Terminal terminal;
  late final Pty pty;

  TermPty() {
    terminal = Terminal(inputHandler: G.keyboard, maxLines: Util.getGlobal("termMaxLines") as int);
    pty = Pty.start(
      "/system/bin/sh",
      workingDirectory: G.dataPath,
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
    );
    pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(terminal.write);
    pty.exitCode.then((code) {
      terminal.write('the process exited with exit code $code');
      if (code == 0) {
        SystemChannels.platform.invokeMethod("SystemNavigator.pop");
      }
      //Signal 9 hint
      if (code == -9) {
        D.androidChannel.invokeMethod("launchSignal9Page", {});
      }
    });
    terminal.onOutput = (data) {
      if (!(Util.getGlobal("isTerminalWriteEnabled") as bool)) {
        return;
      }
      //由于对回车的处理似乎存在问题，所以拿出来单独处理
      data.split("").forEach((element) {
        if (element == "\n" && !G.maybeCtrlJ) {
          terminal.keyInput(TerminalKey.enter);
          return;
        }
        G.maybeCtrlJ = false;
        pty.write(const Utf8Encoder().convert(element));
      });
    };
    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };
  }

}

//default values
class D {

  static const String triliumPackage = "trilium.tar.xz";

  // Trilium 可选版本列表
  static const List<Map<String, String>> triliumVersions = [
    {
      'name': '0.63.7-cn (Built-in)',
      'url': '内置',
      'filename': 'assets/trilium.tar.xz',
    },
    {
      'name': '0.101.3 (Github)',
      'url': 'https://github.com/TriliumNext/Trilium/releases/download/v0.101.3/TriliumNotes-Server-v0.101.3-linux-arm64.tar.xz',
    },
    {
      'name': '0.101.3 (Gitee)',
      'url': 'https://gitee.com/nriver/pocket-trilium/releases/download/v1/TriliumNotes-Server-v0.101.3-linux-arm64.tar.xz',
    },
    {
      'name': '0.63.7 (Github)',
      'url': 'https://github.com/Nriver/pocket-trilium-resources/releases/download/v1/trilium-0.63.7.tar.xz',
    },
    {
      'name': '0.63.7 (Gitee)',
      'url': 'https://gitee.com/nriver/pocket-trilium/releases/download/v1/trilium-0.63.7.tar.xz',
    },

  ];

  static const String containerName = "Pocket Trilium by Nriver";

  // 启动前先杀掉旧的trilium进程, 防止快速多次关闭启动app时旧的进程没有退出导致的问题
  // 判断挂载到手机内部存储的默认数据路径如果无法写入，则写入到app内部目录
  static const String triliumStartCommand = r"""
#pkill -9 node 
 
cd /home/tiny/trilium
[ -w "/home/tiny/.local/share/trilium-data" ] && export TRILIUM_DATA_DIR="/home/tiny/.local/share/trilium-data" || export TRILIUM_DATA_DIR="/home/tiny/trilium-data" 

LOG=/tmp/trilium.log
for i in {1..10}; do
    : > "$LOG"
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
    {"name": "projectUrl", "value": "https://github.com/Nriver/pocket_trilium"},
    {"name": "issueUrl", "value": "https://github.com/Nriver/pocket_trilium/issues"},
    {"name": "discussionUrl", "value": "https://github.com/Nriver/pocket_trilium/discussions"},
  ];

  //默认快捷指令
  static const commands = [
    {"name":"清屏", "command":"clear"},
    {"name":"中断任务", "command":"\x03"},
  ];

  //默认快捷指令，英文版本
  static const commands4En = [
    {"name":"Clear Console", "command":"clear"},
    {"name":"Interrupt", "command":"\x03"},
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

  static const String boot = "\$DATA_DIR/bin/proot -H --change-id=1000:1000 --pwd=/home/tiny --rootfs=\$CONTAINER_DIR --mount=/system --mount=/apex --mount=/sys --mount=/data --kill-on-exit --mount=/storage --sysvipc -L --link2symlink --mount=/proc --mount=/dev --mount=\$CONTAINER_DIR/tmp:/dev/shm --mount=/dev/urandom:/dev/random --mount=/proc/self/fd:/dev/fd --mount=/proc/self/fd/0:/dev/stdin --mount=/proc/self/fd/1:/dev/stdout --mount=/proc/self/fd/2:/dev/stderr --mount=/dev/null:/dev/tty0 --mount=/dev/null:/proc/sys/kernel/cap_last_cap --mount=/storage/self/primary:/media/sd --mount=/storage/self/primary/trilium-data:/home/tiny/.local/share/trilium-data --mount=\$DATA_DIR/tiny:/home/tiny/.local/share/tiny --mount=\$DATA_DIR/trilium:/home/tiny/trilium \$EXTRA_MOUNT /usr/bin/env -i HOSTNAME=TINY HOME=/home/tiny USER=tiny TERM=xterm-256color SDL_IM_MODULE=fcitx XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx GTK_IM_MODULE=fcitx TMOE_CHROOT=false TMOE_PROOT=true TMPDIR=/tmp MOZ_FAKE_NO_SANDBOX=1 QTWEBENGINE_DISABLE_SANDBOX=1 DISPLAY=:4 PULSE_SERVER=tcp:127.0.0.1:4718 LANG=zh_CN.UTF-8 SHELL=/bin/bash PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games \$EXTRA_OPT /bin/bash -l";

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

// Global variables
class G {
  static late final String dataPath;
  static Pty? audioPty;
  static InAppWebViewController? controller;
  static late BuildContext homePageStateContext;
  static late int currentContainer; //目前运行第几个容器
  static late Map<int, TermPty> termPtys; //为容器<int>存放TermPty数据
  static late VirtualKeyboard keyboard; //存储ctrl, shift, alt状态
  static bool maybeCtrlJ = false; //为了区分按下的ctrl+J和enter而准备的变量
  static ValueNotifier<double> termFontScale = ValueNotifier(1); //终端字体大小，存储为G.prefs的termFontScale
  static bool isStreamServerStarted = false;
  static bool isStreaming = false;
  //static int? streamingPid;
  static String streamingOutput = "";
  static late Pty streamServerPty;
  static ValueNotifier<int> pageIndex = ValueNotifier(0); //主界面索引
  static ValueNotifier<bool> terminalPageChange = ValueNotifier(true); //更改值，用于刷新小键盘
  static ValueNotifier<bool> bootTextChange = ValueNotifier(true); //更改值，用于刷新启动命令
  static ValueNotifier<String> updateText = ValueNotifier("随身Trilium"); //加载界面的说明文字
  static String postCommand = ""; //第一次进入容器时额外运行的命令

  static late SharedPreferences prefs;
}

class Workflow {

  static Future<void> grantPermissions() async {
    Permission.storage.request();
    //Permission.manageExternalStorage.request();
  }

  static Future<void> setupBootstrap() async {
    //用来共享数据文件的文件夹
    Util.createDirFromString("${G.dataPath}/share");
    //用来存放可执行文件的文件夹
    Util.createDirFromString("${G.dataPath}/bin");
    //用来存放库的文件夹
    Util.createDirFromString("${G.dataPath}/lib");
    //挂载到/dev/shm的文件夹
    Util.createDirFromString("${G.dataPath}/tmp");
    //给proot的tmp文件夹，虽然我不知道为什么proot要这个
    Util.createDirFromString("${G.dataPath}/proot_tmp");
    //给pulseaudio的tmp文件夹
    Util.createDirFromString("${G.dataPath}/pulseaudio_tmp");
    //解压后得到bin文件夹和libexec文件夹
    //bin存放了proot, pulseaudio, tar等
    //libexec存放了proot loader
    await Util.copyAsset(
    "assets/assets.zip",
    "${G.dataPath}/assets.zip",
    );
    await Util.execute(
"""
export DATA_DIR=${G.dataPath}
export LD_LIBRARY_PATH=\$DATA_DIR/lib
cd \$DATA_DIR
ln -sf ../applib/libexec_busybox.so \$DATA_DIR/bin/busybox
ln -sf ../applib/libexec_busybox.so \$DATA_DIR/bin/sh
ln -sf ../applib/libexec_busybox.so \$DATA_DIR/bin/cat
ln -sf ../applib/libexec_busybox.so \$DATA_DIR/bin/xz
ln -sf ../applib/libexec_busybox.so \$DATA_DIR/bin/gzip
ln -sf ../applib/libexec_proot.so \$DATA_DIR/bin/proot
ln -sf ../applib/libexec_tar.so \$DATA_DIR/bin/tar
ln -sf ../applib/libexec_pulseaudio.so \$DATA_DIR/bin/pulseaudio
ln -sf ../applib/libbusybox.so \$DATA_DIR/lib/libbusybox.so.1.37.0
ln -sf ../applib/libtalloc.so \$DATA_DIR/lib/libtalloc.so.2
ln -sf ../applib/libepoxy.so \$DATA_DIR/lib/libepoxy.so
ln -sf ../applib/libproot-loader32.so \$DATA_DIR/lib/loader32
ln -sf ../applib/libproot-loader.so \$DATA_DIR/lib/loader

\$DATA_DIR/bin/busybox unzip -o assets.zip
chmod -R +x bin/*
chmod -R +x libexec/proot/*
chmod 1777 tmp
\$DATA_DIR/bin/busybox tar -xJf ${D.triliumPackage}
\$DATA_DIR/bin/busybox rm -rf assets.zip ${D.triliumPackage}
""");
  }

  //初次启动要做的事情
  static Future<void> initForFirstTime() async {
    // 提前保存 context，避免跨 async 使用失效的 context
    final BuildContext? ctx = G.homePageStateContext;
    if (ctx == null || !ctx.mounted) {
      debugPrint("警告：初始化时 context 不可用，将使用内置版本继续");
      await _copyBuiltInTrilium();
      await setupBootstrap();
      await _finishContainerSetup();
      return;
    }

    // ──────────────────────────────
    //      显示版本选择对话框
    // ──────────────────────────────
    String? selectedUrl;

    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("选择 Trilium 版本"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: D.triliumVersions.map((ver) {
              final isBuiltIn = ver['url'] == '内置';
              return ListTile(
                title: Text(ver['name']!),
                subtitle: isBuiltIn
                    ? const Text("内置版本", style: TextStyle(fontSize: 12))
                    : Text("在线下载", style: TextStyle(fontSize: 12, color: Colors.blue)),
                onTap: () {
                  selectedUrl = ver['url'];
                  Navigator.of(dialogContext).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );

    // 如果用户关闭对话框没有选择，默认使用内置版本
    selectedUrl ??= '内置';

    // ──────────────────────────────
    //      处理 trilium.tar.xz 文件
    // ──────────────────────────────
    final targetPath = "${G.dataPath}/${D.triliumPackage}";

    if (selectedUrl == '内置') {
      G.updateText.value = "正在使用内置版本 ${D.triliumVersions[0]['name']}...";
      await _copyBuiltInTrilium(targetPath);
    } else {
      G.updateText.value = "正在下载 Trilium ${D.triliumVersions.firstWhere((v) => v['url'] == selectedUrl)['name']}...";
      try {
        final response = await http.get(Uri.parse(selectedUrl!));
        if (response.statusCode == 200) {
          await File(targetPath).writeAsBytes(response.bodyBytes);
          G.updateText.value = "下载完成，正在准备环境...";
        } else {
          throw Exception("HTTP ${response.statusCode}");
        }
      } catch (e, stack) {
        debugPrint("下载失败: $e\n$stack");

        // 尽量在 context 还可用时提示用户
        if (ctx.mounted) {
          await showDialog(
            context: ctx,
            barrierDismissible: false, // 建议不让点外面关闭
            builder: (alertCtx) => AlertDialog(
              title: const Text("下载失败"),
              content: const Text("无法下载所选版本，应用无法正常运行。\n\n将退出程序。"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(alertCtx);
                    // 然后退出
                    // SystemNavigator.pop();
                    exit(0);
                  },
                  child: const Text("退出应用", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        }

        // 回退使用内置版本
        await _copyBuiltInTrilium(targetPath);
      }
    }

    // ──────────────────────────────
    //      继续原有的初始化流程
    // ──────────────────────────────
    G.updateText.value = AppLocalizations.of(ctx)!.installingBootPackage;
    await setupBootstrap();

    G.updateText.value = AppLocalizations.of(ctx)!.copyingContainerSystem;

    await _finishContainerSetup();

    G.updateText.value = AppLocalizations.of(ctx)!.installationComplete;
  }

  // 辅助方法：复制内置版本
  static Future<void> _copyBuiltInTrilium([String? customPath]) async {
    final target = customPath ?? "${G.dataPath}/${D.triliumPackage}";

    final builtIn = D.triliumVersions.firstWhere((v) => v['url'] == '内置');
    final assetPath = builtIn['filename']!;

    await Util.copyAsset(assetPath, target);
  }

  // 辅助方法：完成容器系统安装（原有的后半部分）
  static Future<void> _finishContainerSetup() async {
    //存放容器的文件夹0和存放硬链接的文件夹.l2s
    Util.createDirFromString("${G.dataPath}/containers/0/.l2s");
    //这个是容器rootfs，被split命令分成了xa*，放在assets里
    //首次启动，就用这个，别让用户另选了
    // AssetManifest.json 已经移除 https://docs.flutter.dev/release/breaking-changes/asset-manifest-dot-json
    // 新方式：官方推荐，使用 AssetManifest API 获取 assets/xa* 文件列表
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> xaFiles = manifest
        .listAssets()
        .where((String key) => key.startsWith('assets/xa'))
        .map((String key) => key.split('/').last)
        .toList();

    for (String name in xaFiles) {
      await Util.copyAsset("assets/$name", "${G.dataPath}/$name");
    }

    await Util.execute("""
export DATA_DIR=${G.dataPath}
export PATH=\$DATA_DIR/bin:\$PATH
export LD_LIBRARY_PATH=\$DATA_DIR/lib
export CONTAINER_DIR=\$DATA_DIR/containers/0
export EXTRA_OPT=""
cd \$DATA_DIR
export PATH=\$DATA_DIR/bin:\$PATH
export PROOT_TMP_DIR=\$DATA_DIR/proot_tmp
export PROOT_LOADER=\$DATA_DIR/applib/libproot-loader.so
export PROOT_LOADER_32=\$DATA_DIR/applib/libproot-loader32.so
#export PROOT_L2S_DIR=\$CONTAINER_DIR/.l2s
\$DATA_DIR/bin/proot --link2symlink sh -c "cat xa* | \$DATA_DIR/bin/tar x -J --delay-directory-restore --preserve-permissions -v -C containers/0"
#Script from proot-distro
chmod u+rw "\$CONTAINER_DIR/etc/passwd" "\$CONTAINER_DIR/etc/shadow" "\$CONTAINER_DIR/etc/group" "\$CONTAINER_DIR/etc/gshadow"
echo "aid_\$(id -un):x:\$(id -u):\$(id -g):Termux:/:/sbin/nologin" >> "\$CONTAINER_DIR/etc/passwd"
echo "aid_\$(id -un):*:18446:0:99999:7:::" >> "\$CONTAINER_DIR/etc/shadow"
id -Gn | tr ' ' '\\n' > tmp1
id -G | tr ' ' '\\n' > tmp2
\$DATA_DIR/bin/busybox paste tmp1 tmp2 > tmp3
local group_name group_id
cat tmp3 | while read -r group_name group_id; do
	echo "aid_\${group_name}:x:\${group_id}:root,aid_\$(id -un)" >> "\$CONTAINER_DIR/etc/group"
	if [ -f "\$CONTAINER_DIR/etc/gshadow" ]; then
		echo "aid_\${group_name}:*::root,aid_\$(id -un)" >> "\$CONTAINER_DIR/etc/gshadow"
	fi
done
\$DATA_DIR/bin/busybox rm -rf xa* tmp1 tmp2 tmp3
${Localizations.localeOf(G.homePageStateContext).languageCode == 'zh' ? "" : "echo 'LANG=en_US.UTF-8' > \$CONTAINER_DIR/usr/local/etc/tmoe-linux/locale.txt"}
""");
    // 一些数据初始化
    // $DATA_DIR 是数据文件夹, $CONTAINER_DIR 是容器根目录
    await G.prefs.setStringList("containersInfo", [
      jsonEncode({
        "name": D.containerName,
        "boot": D.boot,
        "appStartCommand": D.triliumStartCommand,
        "webUrl": D.webUrl,
        "commands": Localizations.localeOf(G.homePageStateContext).languageCode == 'zh'
            ? D.commands
            : D.commands4En,
      })
    ]);
  }

  static Future<void> initData() async {

    G.dataPath = (await getApplicationSupportDirectory()).path;

    G.termPtys = {};

    G.keyboard = VirtualKeyboard(defaultInputHandler);
    
    G.prefs = await SharedPreferences.getInstance();

    await Util.execute("ln -sf ${await D.androidChannel.invokeMethod("getNativeLibraryPath", {})} ${G.dataPath}/applib");

    //如果没有这个key，说明是初次启动
    if (!G.prefs.containsKey("defaultContainer")) {
      await initForFirstTime();
      if (Localizations.localeOf(G.homePageStateContext).languageCode != 'zh') {
        G.postCommand += "\nlocaledef -c -i en_US -f UTF-8 en_US.UTF-8";
        // For English users, assume they need to enable terminal write
        await G.prefs.setBool("isTerminalWriteEnabled", true);
        await G.prefs.setBool("isTerminalCommandsEnabled", true);
        await G.prefs.setBool("isStickyKey", false);
        await G.prefs.setBool("wakelock", true);
      }
    }
    G.currentContainer = Util.getGlobal("defaultContainer") as int;

    //是否需要重新安装引导包?
    if (Util.getGlobal("reinstallBootstrap")) {
      G.updateText.value = AppLocalizations.of(G.homePageStateContext)!.reinstallingBootPackage;
      await setupBootstrap();
      G.prefs.setBool("reinstallBootstrap", false);
    }

    G.termFontScale.value = Util.getGlobal("termFontScale") as double;

    G.controller = null;

    //设置屏幕常亮
    WakelockPlus.toggle(enable: Util.getGlobal("wakelock"));
  }

  static Future<void> initTerminalForCurrent() async {
    if (!G.termPtys.containsKey(G.currentContainer)) {
      G.termPtys[G.currentContainer] = TermPty();
    }
  }

  static Future<void> setupAudio() async {
    G.audioPty?.kill();
    G.audioPty = Pty.start(
      "/system/bin/sh"
    );
    G.audioPty!.write(const Utf8Encoder().convert("""
export DATA_DIR=${G.dataPath}
export PATH=\$DATA_DIR/bin:\$PATH
export LD_LIBRARY_PATH=\$DATA_DIR/lib
\$DATA_DIR/bin/busybox sed "s/4713/${Util.getGlobal("defaultAudioPort") as int}/g" \$DATA_DIR/bin/pulseaudio.conf > \$DATA_DIR/bin/pulseaudio.conf.tmp
rm -rf \$DATA_DIR/pulseaudio_tmp/*
TMPDIR=\$DATA_DIR/pulseaudio_tmp HOME=\$DATA_DIR/pulseaudio_tmp XDG_CONFIG_HOME=\$DATA_DIR/pulseaudio_tmp LD_LIBRARY_PATH=\$DATA_DIR/bin:\$LD_LIBRARY_PATH \$DATA_DIR/bin/pulseaudio -F \$DATA_DIR/bin/pulseaudio.conf.tmp
exit
"""));
  await G.audioPty?.exitCode;
  }

  static Future<void> launchCurrentContainer() async {
    String extraMount = ""; //mount options and other proot options
    String extraOpt = "";
    if (Util.getGlobal("isHidpiEnabled")) {
      extraOpt += "${Util.getGlobal("defaultHidpiOpt")} ";
    }
    Util.termWrite(
"""
export DATA_DIR=${G.dataPath}
export PATH=\$DATA_DIR/bin:\$PATH
export LD_LIBRARY_PATH=\$DATA_DIR/lib
export CONTAINER_DIR=\$DATA_DIR/containers/${G.currentContainer}
export EXTRA_MOUNT="$extraMount"
export EXTRA_OPT="$extraOpt"
#export PROOT_L2S_DIR=\$DATA_DIR/containers/0/.l2s
cd \$DATA_DIR
export PROOT_TMP_DIR=\$DATA_DIR/proot_tmp
export PROOT_LOADER=\$DATA_DIR/applib/libproot-loader.so
export PROOT_LOADER_32=\$DATA_DIR/applib/libproot-loader32.so
${Util.getCurrentProp("boot")}
${G.postCommand}
clear""");
  }

  static Future<void> launchGUIBackend() async {
    Util.termWrite((Util.getGlobal("autoLaunchVnc") as bool)?((Util.getGlobal("useX11") as bool)?"""mkdir -p "\$HOME/.vnc" && bash /etc/X11/xinit/Xsession &> "\$HOME/.vnc/x.log" &""":Util.getCurrentProp("appStartCommand")):"");
    Util.termWrite("clear");
  }

  static Future<void> waitForConnection() async {
    await retry(
      // Make a GET request
      () => http.get(Uri.parse(Util.getCurrentProp("webUrl"))).timeout(const Duration(milliseconds: 250)),
      // Retry on SocketException or TimeoutException
      retryIf: (e) => e is SocketException || e is TimeoutException,
    );
  }

  static Future<void> launchBrowser() async {
    final String webUrl = Util.getCurrentProp("webUrl") as String;

    Navigator.push(
      G.homePageStateContext,
      MaterialPageRoute(
        builder: (context) => InAppWebViewFullScreenPage(url: webUrl),
      ),
    );
  }

  static Future<void> launchAvnc() async {
    await AvncFlutter.launchUsingUri(Util.getCurrentProp("vncUri") as String, resizeRemoteDesktop: Util.getGlobal("avncResizeDesktop") as bool, resizeRemoteDesktopScaleFactor: pow(4, Util.getGlobal("avncScaleFactor") as double).toDouble());
  }

  static Future<void> launchXServer() async {
    await X11Flutter.launchXServer("${G.dataPath}/containers/${G.currentContainer}/tmp", "${G.dataPath}/containers/${G.currentContainer}/usr/share/X11/xkb", [":4"]);
  }

  static Future<void> launchX11() async {
    await X11Flutter.launchX11Page();
  }

  static Future<void> workflow() async {
    grantPermissions();
    await initData();
    await initTerminalForCurrent();
    setupAudio();
    launchCurrentContainer();
    if (Util.getGlobal("autoLaunchVnc") as bool) {
      launchGUIBackend();
      waitForConnection().then((value) => launchBrowser());
    }
  }
}


