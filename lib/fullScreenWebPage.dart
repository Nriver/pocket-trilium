import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

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
          ),
        ),
      ),
    );
  }
}