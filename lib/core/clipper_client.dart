import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../workflow.dart';

class ClipperException implements Exception {
  final String message;
  final int? statusCode;

  const ClipperException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ClippingImage {
  final String path;
  final String? mime;

  const ClippingImage({required this.path, this.mime});
}

class ClippingFile {
  final String path;
  final String? mime;
  final String name;
  final bool isImage;

  const ClippingFile({
    required this.path,
    this.mime,
    required this.name,
    this.isImage = false,
  });
}

/// Minimal client for Trilium's built-in web clipper API.
///
/// Pocket Trilium runs a local Trilium server, so we can talk to it directly
/// through 127.0.0.1. The clipper API accepts the same ETAPI token configured
/// in Trilium's Options -> ETAPI page.
class TriliumClipperClient {
  static const Duration _timeout = Duration(seconds: 20);

  static String get token =>
      (Util.getCurrentProp("etapiToken") as String? ?? "").trim();

  static bool get hasToken => token.isNotEmpty;

  static String get baseUrl => Workflow.resolveLocalApiUrl();

  static Uri _uri(String path) => Uri.parse(baseUrl).resolve(path);

  static Map<String, String> _headers(String authToken, {bool json = false}) {
    return {
      'Authorization': authToken,
      'trilium-local-now-datetime': _localNowDateTime(),
      if (json) 'Content-Type': 'application/json',
    };
  }

  /// Verifies the token and that the local server is reachable.
  static Future<void> testConnection({String? authToken}) async {
    final String value = (authToken ?? token).trim();
    if (value.isEmpty) {
      throw const ClipperException("ETAPI token is empty");
    }

    late http.Response response;
    try {
      response = await http
          .get(_uri('/api/clipper/handshake'), headers: _headers(value))
          .timeout(_timeout);
    } catch (e) {
      throw ClipperException("Cannot reach Trilium: $e");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ClipperException("Invalid ETAPI token", statusCode: 401);
    }
    if (response.statusCode != 200) {
      throw ClipperException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const ClipperException("Invalid response from Trilium");
    }
    if (data is! Map || data['appName'] != 'trilium') {
      throw const ClipperException("The target is not a Trilium server");
    }
  }

  /// Creates (or appends to) a note under Trilium's clipper inbox.
  ///
  /// The clipper inbox is the note labelled `#clipperInbox`, falling back to
  /// today's day note, which is the same behaviour as the desktop web clipper.
  static Future<String> createNote({
    required String title,
    required String content,
    String? pageUrl,
    String clipType = 'note',
  }) async {
    if (!hasToken) {
      throw const ClipperException("ETAPI token is not set");
    }

    final Map<String, dynamic> body = {
      'title': title,
      'content': content,
      'clipType': clipType,
      if (pageUrl != null && pageUrl.isNotEmpty) 'pageUrl': pageUrl,
    };

    late http.Response response;
    try {
      response = await http
          .post(
            _uri('/api/clipper/notes'),
            headers: _headers(token, json: true),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw ClipperException("Cannot reach Trilium: $e");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ClipperException("Invalid ETAPI token", statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClipperException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const ClipperException("Invalid response from Trilium");
    }

    final dynamic noteId = data is Map ? data['noteId'] : null;
    if (noteId is! String || noteId.isEmpty) {
      throw const ClipperException("Trilium did not return a noteId");
    }
    return noteId;
  }

  /// Returns the inbox note for [date], falling back to that day's day note.
  static Future<String> getInboxNoteId({DateTime? date}) async {
    if (!hasToken) {
      throw const ClipperException("ETAPI token is not set");
    }

    final DateTime value = date ?? DateTime.now();
    final String ymd = '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    late http.Response response;
    try {
      response = await http
          .get(_uri('/etapi/inbox/$ymd'), headers: _headers(token))
          .timeout(_timeout);
    } catch (e) {
      throw ClipperException("Cannot reach Trilium: $e");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ClipperException("Invalid ETAPI token", statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClipperException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    final dynamic noteId = data is Map ? data['noteId'] : null;
    if (noteId is! String || noteId.isEmpty) {
      throw const ClipperException("Trilium did not return an inbox noteId");
    }
    return noteId;
  }

  /// Creates a plain text note through ETAPI.
  ///
  /// Used for shares without a page URL so each share becomes its own note
  /// instead of being deduplicated by the clipper API's pageUrl label.
  static Future<String> createEtapiNote({
    required String parentNoteId,
    required String title,
    required String content,
    String type = 'text',
  }) async {
    if (!hasToken) {
      throw const ClipperException("ETAPI token is not set");
    }

    late http.Response response;
    try {
      response = await http
          .post(
            _uri('/etapi/create-note'),
            headers: _headers(token, json: true),
            body: jsonEncode({
              'parentNoteId': parentNoteId,
              'title': title,
              'type': type,
              'content': content,
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      throw ClipperException("Cannot reach Trilium: $e");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ClipperException("Invalid ETAPI token", statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClipperException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    final dynamic note = data is Map ? data['note'] : null;
    final dynamic noteId = note is Map ? note['noteId'] : null;
    if (noteId is! String || noteId.isEmpty) {
      throw const ClipperException("Trilium did not return a noteId");
    }
    return noteId;
  }

  /// Saves one or more shared images as a clipping note.
  static Future<String> createImageClipping({
    required String title,
    required String remarkHtml,
    required List<ClippingImage> images,
    String? pageUrl,
  }) async {
    if (!hasToken) {
      throw const ClipperException("ETAPI token is not set");
    }
    if (images.isEmpty) {
      throw const ClipperException("No image to save");
    }

    final List<Map<String, dynamic>> imagePayloads = <Map<String, dynamic>>[];
    final List<String> parts = <String>[];
    final int stamp = DateTime.now().microsecondsSinceEpoch;

    for (int i = 0; i < images.length; i++) {
      final File file = File(images[i].path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final String mime = images[i].mime ?? _guessImageMime(file.path);
      final String imageId = 'shared_image_${stamp}_$i';
      parts.add('<img src="$imageId">');
      imagePayloads.add({
        'imageId': imageId,
        'src': file.uri.pathSegments.last,
        'dataUrl': 'data:$mime;base64,${base64Encode(bytes)}',
      });
    }

    if (imagePayloads.isEmpty) {
      throw const ClipperException("No readable image to save");
    }
    if (remarkHtml.isNotEmpty) {
      parts.add(remarkHtml);
    }

    // The clipper API stores a pageUrl label. Use a unique synthetic URL for
    // image-only shares so separate shares don't get merged into one note.
    final String uniquePageUrl = (pageUrl != null && pageUrl.isNotEmpty)
        ? pageUrl
        : 'https://pocket-trilium.local/shared-image/$stamp';

    return _createClipping(
      title: title,
      content: parts.join(),
      pageUrl: uniquePageUrl,
      images: imagePayloads,
    );
  }

  /// Saves a full-page clipping through the web clipper API.
  static Future<String> createPageClipping({
    required String title,
    required String content,
    required String pageUrl,
    List<Map<String, dynamic>> images = const [],
    Map<String, String> labels = const {},
  }) async {
    if (!hasToken) {
      throw const ClipperException("ETAPI token is not set");
    }

    late http.Response response;
    try {
      response = await http
          .post(
            _uri('/api/clipper/notes'),
            headers: _headers(token, json: true),
            body: jsonEncode({
              'title': title,
              'content': content,
              'pageUrl': pageUrl,
              'clipType': 'page',
              if (images.isNotEmpty) 'images': images,
              if (labels.isNotEmpty) 'labels': labels,
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw ClipperException("Cannot reach Trilium: $e");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ClipperException("Invalid ETAPI token", statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClipperException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    final dynamic noteId = data is Map ? data['noteId'] : null;
    if (noteId is! String || noteId.isEmpty) {
      throw const ClipperException("Trilium did not return a noteId");
    }
    return noteId;
  }

  /// Saves arbitrary files as attachments on a new note in the inbox.
  static Future<String> createFileClipping({
    required String title,
    required String remarkHtml,
    required List<ClippingFile> files,
  }) async {
    if (!hasToken) {
      throw const ClipperException("ETAPI token is not set");
    }
    if (files.isEmpty) {
      throw const ClipperException("No file to save");
    }

    final String inboxId = await getInboxNoteId();
    final String noteId = await createEtapiNote(
      parentNoteId: inboxId,
      title: title,
      content: '',
    );

    final List<String> parts = <String>[];
    for (final ClippingFile file in files) {
      final String mime = file.mime ??
          _guessMimeFromName(file.name) ??
          'application/octet-stream';
      final String role = file.isImage ? 'image' : 'file';
      final String attachmentId = await _createAttachment(
        ownerId: noteId,
        role: role,
        mime: mime,
        title: file.name,
      );
      await _uploadAttachmentContent(
        attachmentId: attachmentId,
        path: file.path,
      );

      if (file.isImage) {
        parts.add(
          '<img src="api/attachments/$attachmentId/image/'
          '${Uri.encodeComponent(file.name)}">',
        );
      } else {
        parts.add(
          '<p><a class="reference-link" '
          'href="#root/$noteId?viewMode=attachments&attachmentId=$attachmentId">'
          '${_escapeHtml(file.name)}</a></p>',
        );
      }
    }

    if (remarkHtml.isNotEmpty) {
      parts.add(remarkHtml);
    }

    await _updateNoteContent(noteId: noteId, content: parts.join());
    return noteId;
  }

  static Future<String> _createAttachment({
    required String ownerId,
    required String role,
    required String mime,
    required String title,
  }) async {
    late http.Response response;
    try {
      response = await http
          .post(
            _uri('/etapi/attachments'),
            headers: _headers(token, json: true),
            body: jsonEncode({
              'ownerId': ownerId,
              'role': role,
              'mime': mime,
              'title': title,
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      throw ClipperException("Cannot reach Trilium: $e");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ClipperException("Invalid ETAPI token", statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClipperException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    final dynamic attachmentId = data is Map ? data['attachmentId'] : null;
    if (attachmentId is! String || attachmentId.isEmpty) {
      throw const ClipperException("Trilium did not return an attachmentId");
    }
    return attachmentId;
  }

  static Future<void> _uploadAttachmentContent({
    required String attachmentId,
    required String path,
  }) async {
    final File file = File(path);
    if (!await file.exists()) {
      throw const ClipperException("Shared file no longer exists");
    }

    final int length = await file.length();
    if (length > 100 * 1024 * 1024) {
      throw const ClipperException("File is larger than 100 MB");
    }

    final http.StreamedRequest request = http.StreamedRequest(
      'PUT',
      _uri('/etapi/attachments/$attachmentId/content'),
    );
    request.headers.addAll(_headers(token));
    request.headers['Content-Type'] = 'application/octet-stream';
    request.contentLength = length;

    final http.Client client = http.Client();
    try {
      final Future<http.StreamedResponse> responseFuture = client.send(request);
      await file.openRead().pipe(request.sink);
      final http.StreamedResponse streamedResponse = await responseFuture;
      final http.Response response =
          await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ClipperException("Invalid ETAPI token", statusCode: 401);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ClipperException(
          _errorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } finally {
      client.close();
    }
  }

  static Future<void> _updateNoteContent({
    required String noteId,
    required String content,
  }) async {
    late http.Response response;
    try {
      response = await http
          .put(
            _uri('/etapi/notes/$noteId/content'),
            headers: {
              ..._headers(token),
              'Content-Type': 'text/plain; charset=utf-8',
            },
            body: content,
          )
          .timeout(_timeout);
    } catch (e) {
      throw ClipperException("Cannot reach Trilium: $e");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ClipperException("Invalid ETAPI token", statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClipperException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  static String? _guessMimeFromName(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.webm')) return 'video/webm';
    return null;
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static Future<String> _createClipping({
    required String title,
    required String content,
    required String pageUrl,
    required List<Map<String, dynamic>> images,
  }) async {
    late http.Response response;
    try {
      response = await http
          .post(
            _uri('/api/clipper/clippings'),
            headers: _headers(token, json: true),
            body: jsonEncode({
              'title': title,
              'content': content,
              'pageUrl': pageUrl,
              'images': images,
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      throw ClipperException("Cannot reach Trilium: $e");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ClipperException("Invalid ETAPI token", statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClipperException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    final dynamic noteId = data is Map ? data['noteId'] : null;
    if (noteId is! String || noteId.isEmpty) {
      throw const ClipperException("Trilium did not return a noteId");
    }
    return noteId;
  }

  static String _guessImageMime(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  static String _errorMessage(http.Response response) {
    final String body = utf8.decode(response.bodyBytes).trim();
    if (body.isNotEmpty) {
      try {
        final dynamic data = jsonDecode(body);
        if (data is Map) {
          final dynamic message = data['message'] ?? data['error'];
          if (message is String && message.isNotEmpty) {
            return message;
          }
        }
      } catch (_) {
        // Fall through and show the raw body.
      }
      if (body.length > 300) {
        return body.substring(0, 300);
      }
      return body;
    }
    return "HTTP ${response.statusCode}";
  }

  static String _localNowDateTime() {
    final DateTime now = DateTime.now();
    final Duration offset = now.timeZoneOffset;
    final String sign = offset.isNegative ? '-' : '+';
    final String hours = offset.inHours.abs().toString().padLeft(2, '0');
    final String minutes =
        (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');

    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.'
        '${three(now.millisecond)}$sign$hours:$minutes';
  }
}
