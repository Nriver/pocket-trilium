import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'clipper_client.dart';
import 'webview_scripts.dart';

class ExtractedImage {
  final String imageId;
  final String src;

  const ExtractedImage({required this.imageId, required this.src});
}

class ArticleExtractionResult {
  final String title;
  final String contentHtml;
  final String pageUrl;
  final String userAgent;
  final String? publishedDate;
  final String? modifiedDate;
  final List<ExtractedImage> images;

  const ArticleExtractionResult({
    required this.title,
    required this.contentHtml,
    required this.pageUrl,
    required this.userAgent,
    required this.images,
    this.publishedDate,
    this.modifiedDate,
  });
}

/// Loads a page in a headless WebView and extracts its readable content with
/// Readability.js, mirroring the desktop Trilium web clipper.
class ArticleExtractor {
  static const Duration _loadTimeout = Duration(seconds: 30);
  static const Duration _renderDelay = Duration(milliseconds: 800);
  static const int _maxContentLength = 5 * 1024 * 1024;

  static Future<ArticleExtractionResult> extract(String url) async {
    final String readabilitySource = WebViewScripts.get('Readability.js');
    if (readabilitySource.isEmpty) {
      throw const ClipperException("Readability.js is not available");
    }

    final Completer<void> loaded = Completer<void>();
    bool mainFrameFailed = false;
    String? loadError;

    HeadlessInAppWebView? webView;
    webView = HeadlessInAppWebView(
      initialSize: const Size(1080, 1920),
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        disableContextMenu: true,
        mediaPlaybackRequiresUserGesture: true,
      ),
      onLoadStop: (controller, loadedUrl) {
        if (!loaded.isCompleted) {
          loaded.complete();
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          mainFrameFailed = true;
          loadError = error.description;
          if (!loaded.isCompleted) {
            loaded.complete();
          }
        }
      },
      onReceivedHttpError: (controller, request, response) {
        if (request.isForMainFrame == true &&
            (response.statusCode ?? 0) >= 400) {
          mainFrameFailed = true;
          loadError = "HTTP ${response.statusCode}";
          if (!loaded.isCompleted) {
            loaded.complete();
          }
        }
      },
    );

    try {
      await webView.run();

      try {
        await loaded.future.timeout(_loadTimeout);
      } on TimeoutException {
        throw const ClipperException("Timed out while loading the page");
      }

      if (mainFrameFailed) {
        throw ClipperException(
          loadError == null ? "Failed to load the page" : loadError!,
        );
      }

      // Give client-side rendering a moment to finish before extracting.
      await Future<void>.delayed(_renderDelay);

      final InAppWebViewController? controller = webView.webViewController;
      if (controller == null) {
        throw const ClipperException("Headless WebView is not ready");
      }

      final dynamic raw = await controller.evaluateJavascript(
        source: '$readabilitySource\n;$_extractScript',
      );

      dynamic value = raw;
      if (value is String) {
        try {
          value = jsonDecode(value);
        } catch (_) {
          throw const ClipperException("Invalid extraction result");
        }
      }
      if (value is! Map) {
        throw const ClipperException("Invalid extraction result");
      }

      if (value['ok'] != true) {
        final dynamic error = value['error'];
        throw ClipperException(
          error is String && error.isNotEmpty
              ? error
              : "Could not extract the page content",
        );
      }

      final String content = (value['content'] ?? '').toString();
      if (content.isEmpty) {
        throw const ClipperException("The extracted page content is empty");
      }
      if (content.length > _maxContentLength) {
        throw const ClipperException("The page content is too large");
      }

      final List<ExtractedImage> images = <ExtractedImage>[];
      final dynamic rawImages = value['images'];
      if (rawImages is List) {
        for (final dynamic item in rawImages) {
          if (item is! Map) continue;
          final String? imageId = _clean(item['imageId']);
          final String? src = _clean(item['src']);
          if (imageId != null && src != null) {
            images.add(ExtractedImage(imageId: imageId, src: src));
          }
        }
      }

      return ArticleExtractionResult(
        title: (value['title'] ?? '').toString().trim(),
        contentHtml: content,
        pageUrl: (value['pageUrl'] ?? url).toString(),
        userAgent: (value['userAgent'] ?? '').toString(),
        publishedDate: _dateOnly(value['publishedDate']),
        modifiedDate: _dateOnly(value['modifiedDate']),
        images: images,
      );
    } finally {
      try {
        await webView.dispose();
      } catch (_) {
        // The WebView may already be gone.
      }
    }
  }

  static String? _clean(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _dateOnly(dynamic value) {
    final String? raw = _clean(value);
    if (raw == null) return null;

    final Match? match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(raw);
    if (match != null) {
      return match.group(1);
    }

    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final DateTime local = parsed.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static const String _extractScript = r'''
(function () {
  try {
    var clone = document.cloneNode(true);
    var article = new Readability(clone).parse();
    if (!article || !article.content) {
      return JSON.stringify({ ok: false, error: 'Readability could not parse this page' });
    }

    var container = document.createElement('div');
    container.innerHTML = article.content;

    var base = document.baseURI || location.href;

    container.querySelectorAll('script,style,noscript,link,meta').forEach(function (el) {
      el.remove();
    });

    container.querySelectorAll('a[href]').forEach(function (a) {
      try { a.href = new URL(a.getAttribute('href'), base).href; } catch (e) {}
    });

    var images = [];
    var seen = {};
    container.querySelectorAll('img').forEach(function (img) {
      var candidate = img.currentSrc || img.getAttribute('src');
      if (!candidate) {
        candidate = img.getAttribute('data-src')
          || img.getAttribute('data-original')
          || img.getAttribute('data-lazy-src')
          || '';
      }
      if (!candidate) return;

      var absolute = candidate;
      if (!/^data:image\//i.test(absolute)) {
        try { absolute = new URL(absolute, base).href; } catch (e) {}
      }
      if (!absolute) return;

      if (seen[absolute]) {
        img.setAttribute('src', seen[absolute]);
        return;
      }

      var imageId = '__pocket_trilium_image_' + images.length + '__';
      seen[absolute] = imageId;
      images.push({ imageId: imageId, src: absolute });
      img.setAttribute('src', imageId);
      img.removeAttribute('srcset');
      img.removeAttribute('data-src');
      img.removeAttribute('data-original');
      img.removeAttribute('data-lazy-src');
    });

    // Drop bulky machine-readable attributes to keep the note compact and
    // reduce server-side sanitizing/parsing time.
    container.querySelectorAll('*').forEach(function (el) {
      Array.from(el.attributes).forEach(function (attr) {
        var name = attr.name.toLowerCase();
        if (name.indexOf('data-') === 0 ||
            name === 'typeof' ||
            name === 'about' ||
            name === 'role' ||
            name.indexOf('aria-') === 0) {
          el.removeAttribute(attr.name);
        }
      });
    });

    container.querySelectorAll('span').forEach(function (el) {
      if (el.attributes.length === 0 &&
          el.children.length === 0 &&
          !el.textContent.trim()) {
        el.remove();
      }
    });

    function meta(property) {
      var el = document.querySelector("meta[property='" + property + "']")
        || document.querySelector("meta[name='" + property + "']");
      return el && el.getAttribute('content') ? el.getAttribute('content') : null;
    }

    return JSON.stringify({
      ok: true,
      title: article.title || document.title || '',
      content: container.innerHTML,
      pageUrl: location.href.split('#')[0],
      userAgent: navigator.userAgent,
      publishedDate: meta('article:published_time'),
      modifiedDate: meta('article:modified_time'),
      images: images
    });
  } catch (e) {
    return JSON.stringify({ ok: false, error: String(e) });
  }
})();
''';
}
