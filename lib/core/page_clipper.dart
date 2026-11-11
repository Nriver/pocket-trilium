import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import 'article_extractor.dart';
import 'clipper_client.dart';

class PageClipResult {
  final String noteId;
  final String title;

  const PageClipResult({required this.noteId, required this.title});
}

/// Extracts an article and saves it to Trilium as a full-page clipping,
/// including images when possible.
class PageClipper {
  static const int _maxImages = 30;
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _concurrency = 4;
  static const Duration _imageTimeout = Duration(seconds: 15);

  static final Map<String, Future<String>> _cookieCache =
      <String, Future<String>>{};

  static Future<PageClipResult> clip({
    required String url,
    required String remarkHtml,
    required String currentTitle,
    required bool preferArticleTitle,
  }) async {
    _cookieCache.clear();

    final ArticleExtractionResult article = await ArticleExtractor.extract(url);

    final String title = (preferArticleTitle && article.title.isNotEmpty)
        ? article.title
        : (currentTitle.trim().isEmpty ? article.title : currentTitle.trim());

    final _PreparedImages prepared = await _prepareImages(
      html: article.contentHtml,
      images: article.images,
      pageUrl: article.pageUrl.isNotEmpty ? article.pageUrl : url,
      userAgent: article.userAgent,
    );

    final Map<String, String> labels = <String, String>{};
    if (article.publishedDate != null) {
      labels['publishedDate'] = article.publishedDate!;
    }
    if (article.modifiedDate != null) {
      labels['modifiedDate'] = article.modifiedDate!;
    }

    final String noteId = await TriliumClipperClient.createPageClipping(
      title: title.isEmpty ? article.pageUrl : title,
      content: prepared.html + remarkHtml,
      pageUrl: article.pageUrl.isNotEmpty ? article.pageUrl : url,
      images: prepared.payloads,
      labels: labels,
    );

    return PageClipResult(noteId: noteId, title: title);
  }

  static Future<_PreparedImages> _prepareImages({
    required String html,
    required List<ExtractedImage> images,
    required String pageUrl,
    required String userAgent,
  }) async {
    if (images.isEmpty) {
      return _PreparedImages(html: html, payloads: const []);
    }

    final List<ExtractedImage> toFetch = images.take(_maxImages).toList();
    final List<ExtractedImage> skipped = images.skip(_maxImages).toList();

    final List<_PreparedImageResult> results = await _fetchAll(
      toFetch,
      pageUrl,
      userAgent,
    );

    String resultHtml = html;
    final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[];

    for (final _PreparedImageResult result in results) {
      if (result.payload != null) {
        payloads.add(result.payload!);
      } else {
        resultHtml = resultHtml.replaceAll(
          result.imageId,
          _escapeAttribute(result.fallbackUrl ?? ''),
        );
      }
    }

    for (final ExtractedImage image in skipped) {
      resultHtml = resultHtml.replaceAll(
        image.imageId,
        _escapeAttribute(image.src),
      );
    }

    return _PreparedImages(html: resultHtml, payloads: payloads);
  }

  static Future<List<_PreparedImageResult>> _fetchAll(
    List<ExtractedImage> images,
    String pageUrl,
    String userAgent,
  ) async {
    final List<_PreparedImageResult?> results =
        List<_PreparedImageResult?>.filled(images.length, null);

    int next = 0;
    Future<void> worker() async {
      while (true) {
        final int index = next++;
        if (index >= images.length) return;
        results[index] = await _fetchOne(
          images[index],
          index,
          pageUrl,
          userAgent,
        );
      }
    }

    final int workers =
        images.length < _concurrency ? images.length : _concurrency;
    await Future.wait(List<Future<void>>.generate(workers, (_) => worker()));

    return results.whereType<_PreparedImageResult>().toList();
  }

  static Future<_PreparedImageResult> _fetchOne(
    ExtractedImage image,
    int index,
    String pageUrl,
    String userAgent,
  ) async {
    final String src = image.src;

    if (src.startsWith('data:image/')) {
      return _PreparedImageResult.success(
        imageId: image.imageId,
        payload: <String, dynamic>{
          'imageId': image.imageId,
          'src': 'inline.${_extensionFromDataUrl(src)}',
          'dataUrl': src,
        },
      );
    }

    final Uri? uri = Uri.tryParse(src);
    if (uri == null) {
      return _PreparedImageResult.failure(image.imageId, src);
    }

    try {
      final Map<String, String> headers = <String, String>{
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        if (userAgent.isNotEmpty) 'User-Agent': userAgent,
        if (pageUrl.isNotEmpty) 'Referer': pageUrl,
      };

      final String cookieHeader = await _cookieHeader(uri);
      if (cookieHeader.isNotEmpty) {
        headers['Cookie'] = cookieHeader;
      }

      final http.Response response =
          await http.get(uri, headers: headers).timeout(_imageTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _PreparedImageResult.failure(image.imageId, src);
      }

      final List<int> bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > _maxImageBytes) {
        return _PreparedImageResult.failure(image.imageId, src);
      }

      String mime =
          response.headers['content-type']?.split(';').first.trim() ?? '';
      if (!mime.startsWith('image/')) {
        mime = _guessMime(uri.path);
      }

      final String extension = _extensionForMime(mime);
      final String fileName = _fileName(uri, index, extension);

      return _PreparedImageResult.success(
        imageId: image.imageId,
        payload: <String, dynamic>{
          'imageId': image.imageId,
          'src': fileName,
          'dataUrl': 'data:$mime;base64,${base64Encode(bytes)}',
        },
      );
    } catch (_) {
      return _PreparedImageResult.failure(image.imageId, src);
    }
  }

  static Future<String> _cookieHeader(Uri uri) {
    final String key = uri.origin;
    return _cookieCache.putIfAbsent(key, () async {
      try {
        final List<Cookie> cookies = await CookieManager.instance().getCookies(
          url: WebUri(uri.toString()),
        );
        return cookies
            .map((Cookie cookie) => '${cookie.name}=${cookie.value}')
            .join('; ');
      } catch (_) {
        return '';
      }
    });
  }

  static String _fileName(Uri uri, int index, String extension) {
    String name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (name.isEmpty) {
      name = 'image_$index';
    }
    if (!name.contains('.')) {
      name = '$name.$extension';
    }
    if (name.length > 80) {
      name = 'image_$index.$extension';
    }
    return name;
  }

  static String _extensionForMime(String mime) {
    switch (mime.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/bmp':
        return 'bmp';
      case 'image/svg+xml':
        return 'svg';
      case 'image/avif':
        return 'avif';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      default:
        return 'jpg';
    }
  }

  static String _guessMime(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.avif')) return 'image/avif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  static String _extensionFromDataUrl(String dataUrl) {
    final Match? match =
        RegExp(r'^data:image/([a-zA-Z0-9.+-]+);').firstMatch(dataUrl);
    final String subtype = match?.group(1)?.toLowerCase() ?? 'png';
    if (subtype == 'jpeg') return 'jpg';
    if (subtype == 'svg+xml') return 'svg';
    return subtype;
  }

  static String _escapeAttribute(String value) {
    return const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
  }
}

class _PreparedImages {
  final String html;
  final List<Map<String, dynamic>> payloads;

  const _PreparedImages({required this.html, required this.payloads});
}

class _PreparedImageResult {
  final String imageId;
  final Map<String, dynamic>? payload;
  final String? fallbackUrl;

  const _PreparedImageResult({
    required this.imageId,
    this.payload,
    this.fallbackUrl,
  });

  factory _PreparedImageResult.success({
    required String imageId,
    required Map<String, dynamic> payload,
  }) {
    return _PreparedImageResult(imageId: imageId, payload: payload);
  }

  factory _PreparedImageResult.failure(String imageId, String fallbackUrl) {
    return _PreparedImageResult(
      imageId: imageId,
      fallbackUrl: fallbackUrl,
    );
  }
}
