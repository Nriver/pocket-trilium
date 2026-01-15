// This file is part of pocket-trilium.

// Copyright (C) 2026 Nriver

// Pocket Trilium is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or any later version.

// Pocket Trilium is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see http://www.gnu.org/licenses/agpl-3.0.html.

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

class _InAppWebViewFullScreenPageState extends State<InAppWebViewFullScreenPage> {
  InAppWebViewController? webViewController;

  // 用于实现「网页能后退就后退，不能后退再按一次才退出」
  bool _isAtRoot = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("再按一次退出浏览器"),
            duration: Duration(seconds: 2),
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