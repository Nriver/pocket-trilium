import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'workflow.dart';
import 'l10n/app_localizations.dart';

class InAppWebViewFullScreenPage extends StatefulWidget {
  final String url;
  const InAppWebViewFullScreenPage({
    super.key,
    required this.url,
  });
  @override
  State<InAppWebViewFullScreenPage> createState() =>
      _InAppWebViewFullScreenPageState();
}

class _InAppWebViewFullScreenPageState extends State<InAppWebViewFullScreenPage> {
  InAppWebViewController? webViewController;

  // 用于实现「网页能后退就后退，不能后退再按一次才退出」
  bool _isAtRoot = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (webViewController == null) return true;
    bool canGoBack = await webViewController!.canGoBack();
    if (canGoBack) {
      await webViewController!.goBack();
      setState(() => _isAtRoot = false);
      return false;
    } else {
      if (_isAtRoot) {
        return true;
      } else {
        setState(() => _isAtRoot = true);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pressAgainToExitBrowser),
            duration: const Duration(seconds: 2),
          ),
        );
        return false;
      }
    }
  }

  Future<String> _getUniqueFilename(String baseName, Directory dir) async {
    String name = baseName;
    String ext = '';
    int dotIndex = baseName.lastIndexOf('.');
    if (dotIndex != -1) {
      name = baseName.substring(0, dotIndex);
      ext = baseName.substring(dotIndex);
    }

    String candidate = baseName;
    int i = 1;
    while (await File('${dir.path}/$candidate').exists()) {
      candidate = '$name ($i)$ext';
      i++;
    }
    return candidate;
  }

  Future<String?> _showEditFilenameDialog(BuildContext context, String initialName) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downloadFile),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.fileName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Future<bool> _showOverwriteDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.fileExists),
        content: Text(l10n.overwriteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // 让 Flutter 响应键盘高度变化
        resizeToAvoidBottomInset: true,
        // 去掉标题栏
        appBar: null,
        // body 占满屏幕，edge-to-edge模式下使用 SafeArea 保护状态栏和导航栏区域
        body: SafeArea(
          top: true,
          bottom: true,
          // Focus 组件 处理键盘方向键事件
          child: Focus(
            onKeyEvent: (FocusNode node, KeyEvent event) {
              // 检查是否为物理键盘按下事件
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                final logicalKey = event.logicalKey;

                // 匹配四个方向键
                if (logicalKey == LogicalKeyboardKey.arrowUp ||
                    logicalKey == LogicalKeyboardKey.arrowDown ||
                    logicalKey == LogicalKeyboardKey.arrowLeft ||
                    logicalKey == LogicalKeyboardKey.arrowRight) {

                  // 返回 skipRemainingHandlers 告诉 Flutter：
                  // 不要在这里处理焦点切换，把事件传给 Native (WebView)
                  return KeyEventResult.skipRemainingHandlers;
                }
              }
              return KeyEventResult.ignored;
            },
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                supportZoom: true,
                clearCache: true,  // Clear existing cache on initialization
                cacheEnabled: false,  // Disable caching entirely
                cacheMode: CacheMode.LOAD_NO_CACHE,  // Force loads from network, ignoring cache
                useHybridComposition: true,
                allowContentAccess: true,
                builtInZoomControls: true,
                supportMultipleWindows: true,
                allowsInlineMediaPlayback: true,
                allowsBackForwardNavigationGestures: true,
                iframeAllowFullscreen: true,
                isInspectable: kDebugMode,
                disableDefaultErrorPage: true,
                useOnDownloadStart: true, // 启用下载事件处理
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
                G.controller = controller; // 保持全局引用（如果 workflow.dart 还在用）
              },
              onProgressChanged: (controller, progress) {
                // 可选：这里可以加进度条逻辑
              },
              onLoadStop: (controller, url) async {
                print("页面加载完成: $url");
                // 解决某些情况下 Webview 焦点丢失
                await controller.evaluateJavascript(source: """
                  document.addEventListener('keydown', function(e) {
                    if(['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) {
                      // 检测按键事件触发
                      console.log('Key pressed: ' + e.code);
                    }
                  }, true);
                """);
                final can = await controller.canGoBack();
                if (mounted) {
                  setState(() => _isAtRoot = !can);
                }
              },
              // 拦截普通链接导航（非 target="_blank"）
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null) return NavigationActionPolicy.ALLOW;
                // 额外保险，如果 URL 完全相同，也可以在这里强制 reload
                // 在需要刷新页面的场景下有用，比如手动刷新页面的按钮，切换移动模式和桌面模式等
                final current = await controller.getUrl();
                if (uri.toString() == current?.toString()) {
                  await controller.reload();
                  return NavigationActionPolicy.CANCEL;
                }
                // 默认允许在 WebView 内加载
                return NavigationActionPolicy.ALLOW;
              },
              // 处理 target="_blank" 或 window.open()，用系统浏览器打开
              onCreateWindow: (controller, createWindowAction) async {
                final url = createWindowAction.request.url;
                if (url != null && await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,  // 用系统默认浏览器
                  );
                  return true;  // 已处理，不要创建新 WebView 窗口
                }
                // 不处理就返回 false
                return false;
              },
              onReceivedError: (controller, request, error) {
                print("加载错误: ${error.description} (code: ${error.type})");
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                print("HTTP 错误: ${errorResponse.statusCode}");
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) async {
                final can = await controller.canGoBack();
                if (mounted) {
                  setState(() => _isAtRoot = !can);
                }
              },
              // 处理文件下载事件
              onDownloadStartRequest: (controller, downloadStartRequest) async {
                final url = downloadStartRequest.url;
                if (url == null) return;

                // 获取建议文件名
                String filename = downloadStartRequest.suggestedFilename ??
                    url.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'download');

                // 使用指定的下载目录（公共目录，无需额外权限）
                final downloadDir = Directory('/storage/emulated/0/Download');
                if (!await downloadDir.exists()) {
                  await downloadDir.create(recursive: true);
                }

                // 计算唯一文件名（如果存在则添加后缀）
                final uniqueFilename = await _getUniqueFilename(filename, downloadDir);

                // 显示弹窗让用户修改文件名
                final chosenFilename = await _showEditFilenameDialog(context, uniqueFilename);
                if (chosenFilename == null || chosenFilename.isEmpty) return;

                final filePath = '${downloadDir.path}/$chosenFilename';

                // 检查是否已存在，如果存在，要求二次确认
                if (await File(filePath).exists()) {
                  final overwrite = await _showOverwriteDialog(context);
                  if (!overwrite) return;
                }

                // 准备请求头以处理登录认证
                Map<String, String> headers = {};

                // 添加 Cookie
                final cookieManager = CookieManager.instance();
                final cookies = await cookieManager.getCookies(url: url);
                if (cookies.isNotEmpty) {
                  headers['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
                }

                final l10n = AppLocalizations.of(context)!;
                try {
                  final response = await http.get(url, headers: headers);

                  if (response.statusCode == 200) {
                    final file = File(filePath);
                    await file.writeAsBytes(response.bodyBytes);
                    // 显示下载成功提示
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${l10n.downloadSuccess}: $filePath')),
                      );
                    }
                  } else {
                    // 处理下载失败
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${l10n.downloadFailed}: ${response.statusCode}')),
                      );
                    }
                  }
                } catch (e) {
                  // 处理异常
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.downloadError}: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}