import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
              clearCache: false,

              useHybridComposition: true,
              allowContentAccess: true,
              builtInZoomControls: true,
              supportMultipleWindows: true,
              cacheMode: CacheMode.LOAD_DEFAULT,

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

            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.ALLOW;
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