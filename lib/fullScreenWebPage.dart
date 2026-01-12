// lib/pages/in_app_webview_fullscreen_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../workflow.dart'; // 引入 workflow.dart 以使用 G.controller（如果需要）

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

class _InAppWebViewFullScreenPageState
    extends State<InAppWebViewFullScreenPage> {
  InAppWebViewController? webViewController;

  @override
  void initState() {
    super.initState();
    // 进入页面时隐藏状态栏和导航栏，实现真·全屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // 退出页面时恢复系统 UI 模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 让 Flutter 响应键盘高度变化
      resizeToAvoidBottomInset: true,

      // 去掉标题栏
      appBar: null,

      // body 占满屏幕
      body: SafeArea(
        top: false,
        bottom: false,
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
        ),
      ),
    );
  }
}