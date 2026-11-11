import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/defaults.dart';
import '../fullScreenWebPage.dart';
import '../l10n/app_localizations.dart';
import '../workflow.dart';
import 'clipper_client.dart';
import 'etapi_token_dialog.dart';
import 'page_clipper.dart';

class SharedImage {
  final String path;
  final String? mime;
  final String? name;

  const SharedImage({required this.path, this.mime, this.name});

  static SharedImage? tryFromMap(dynamic value) {
    if (value is! Map) return null;
    final String? path = SharePayload._clean(value['path']);
    if (path == null) return null;
    return SharedImage(
      path: path,
      mime: SharePayload._clean(value['mime']),
      name: SharePayload._clean(value['name']),
    );
  }
}

class SharePayload {
  final String? text;
  final String? subject;
  final String? url;
  final String? sourceApp;
  final List<SharedImage> images;

  const SharePayload({
    this.text,
    this.subject,
    this.url,
    this.sourceApp,
    this.images = const [],
  });

  static final RegExp _urlPattern =
      RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false);

  static String? _clean(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _trimUrl(String? value) {
    if (value == null) return null;
    return value.trim().replaceFirst(
          RegExp(r'''[.,;:!)\]}"'，。！？）】》]+$'''),
          '',
        );
  }

  factory SharePayload.fromMap(dynamic value) {
    if (value is! Map) {
      return const SharePayload();
    }
    final String? text = _clean(value['text']);
    final String? subject = _clean(value['subject']);
    final String? sourceApp = _clean(value['sourceApp']);
    String? url = _clean(value['url']);
    if (url == null && text != null) {
      url = _urlPattern.firstMatch(text)?.group(0);
    }

    final List<SharedImage> images = <SharedImage>[];
    final dynamic rawImages = value['images'];
    if (rawImages is List) {
      for (final dynamic item in rawImages) {
        final SharedImage? image = SharedImage.tryFromMap(item);
        if (image != null) {
          images.add(image);
        }
      }
    }

    return SharePayload(
      text: text,
      subject: subject,
      url: _trimUrl(url),
      sourceApp: sourceApp,
      images: images,
    );
  }

  bool get isEmpty =>
      (text == null || text!.isEmpty) &&
      (url == null || url!.isEmpty) &&
      images.isEmpty;
}

class ShareHandler {
  static bool _initialized = false;
  static bool _uiReady = false;
  static bool _processing = false;
  static final List<SharePayload> _queue = <SharePayload>[];

  /// Registers the native callback and pulls any share that launched the app.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    D.androidChannel.setMethodCallHandler((call) async {
      if (call.method == 'onShareReceived') {
        _enqueue(SharePayload.fromMap(call.arguments));
      }
    });

    try {
      final dynamic pending =
          await D.androidChannel.invokeMethod('getPendingShare');
      _enqueue(SharePayload.fromMap(pending));
    } catch (_) {
      // Native side is not available (e.g. tests); ignore.
    }
  }

  /// Called by the home page once the workflow and UI are ready.
  static void markUiReady(BuildContext context) {
    _uiReady = true;
    processPending(context);
  }

  static void _enqueue(SharePayload payload) {
    if (payload.isEmpty) return;
    _queue.add(payload);

    if (!_uiReady || _processing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_uiReady || _processing) return;
      processPending(G.homePageStateContext);
    });
  }

  static Future<void> processPending(BuildContext context) async {
    if (!_uiReady || _processing || _queue.isEmpty) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        final SharePayload payload = _queue.removeAt(0);
        try {
          await D.androidChannel.invokeMethod('consumePendingShare');
        } catch (_) {
          // Ignore; the payload is already in memory.
        }
        if (!context.mounted) break;
        await _handle(context, payload);
      }
    } finally {
      _processing = false;
    }
  }

  static Future<void> _handle(
    BuildContext context,
    SharePayload payload,
  ) async {
    if (payload.isEmpty || !context.mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (!TriliumClipperClient.hasToken) {
      final bool saved = await showEtapiTokenDialog(context);
      if (!saved || !context.mounted) return;
    }

    final bool ready = await _waitForServer(context);
    if (!ready || !context.mounted) return;

    // 等待后台自动打开图形界面, 保证分享弹窗显示在网页之上
    await Workflow.waitForAutoOpen();
    if (!context.mounted) return;
    // 给网页的原生视图留出挂载时间, 避免它盖住随后弹出的分享弹窗
    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;

    final String? noteId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ShareCaptureSheet(payload: payload),
    );
    if (noteId == null || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.shareSaveSuccess),
        action: SnackBarAction(
          label: l10n.shareOpenNote,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    InAppWebViewFullScreenPage(url: Workflow.noteUrl(noteId)),
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<bool> _waitForServer(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // 先快速探测一次, 服务已就绪时不显示等待遮罩
    bool ready =
        await Workflow.waitForConnection(maxWait: const Duration(seconds: 2));

    OverlayEntry? waitingEntry;
    if (!ready && context.mounted) {
      final OverlayState overlay = Overlay.of(context, rootOverlay: true);
      waitingEntry = OverlayEntry(
        builder: (_) => AbsorbPointer(
          child: ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 16),
                      Flexible(child: Text(l10n.shareWaitingTrilium)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(waitingEntry);

      if (!(Util.getGlobal("autoLaunchGUI") as bool)) {
        Workflow.launchGUIBackend();
      }

      ready = await Workflow.waitForConnection(
        maxWait: const Duration(seconds: 60),
      );
    }

    if (ready) {
      G.isTriliumReady.value = true;
    }

    waitingEntry?.remove();
    waitingEntry = null;

    if (!ready && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.shareToTrilium),
          content: Text(l10n.shareStartTimeout),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    }

    return ready;
  }
}

class _ShareCaptureSheet extends StatefulWidget {
  final SharePayload payload;

  const _ShareCaptureSheet({required this.payload});

  @override
  State<_ShareCaptureSheet> createState() => _ShareCaptureSheetState();
}

enum _ClipMode { link, fullPage }

class _ShareCaptureSheetState extends State<_ShareCaptureSheet> {
  bool _initialized = false;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _includeLink = false;
  bool _saving = false;
  bool _authError = false;
  String? _error;
  _ClipMode _clipMode = _ClipMode.link;
  String _initialTitle = '';

  bool get _hasUrl =>
      widget.payload.url != null && widget.payload.url!.isNotEmpty;

  bool get _canClipFullPage => _hasUrl && widget.payload.images.isEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final l10n = AppLocalizations.of(context)!;
    final SharePayload payload = widget.payload;
    final String? url = payload.url;

    String content = payload.text ?? '';
    if (url != null && url.isNotEmpty && content.isNotEmpty) {
      content = content.replaceAll(url, '').trim();
    }

    String title;
    final String? subject = payload.subject;
    if (payload.images.isNotEmpty) {
      title = _imageShareTitle(l10n, payload);
    } else if (subject != null && subject.isNotEmpty && !_looksLikeUrl(subject)) {
      title = subject;
    } else if (content.isNotEmpty) {
      title = _firstLine(content, 80);
    } else if (url != null && url.isNotEmpty) {
      final String? host = Uri.tryParse(url)?.host;
      title = (host != null && host.isNotEmpty)
          ? host
          : l10n.shareLinkTitleFallback;
    } else {
      title = l10n.shareTextTitleFallback;
    }

    _titleController = TextEditingController(text: title);
    _contentController = TextEditingController(text: content);
    _includeLink = url != null && url.isNotEmpty;
    _initialTitle = title;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  static bool _looksLikeUrl(String value) {
    final String trimmed = value.trim();
    final Match? match = SharePayload._urlPattern.firstMatch(trimmed);
    return match != null && match.group(0) == trimmed;
  }

  static String _firstLine(String text, int maxLength) {
    final String line = text.split('\n').first.trim();
    if (line.length <= maxLength) return line;
    return '${line.substring(0, maxLength)}…';
  }

  static String _imageShareTitle(
    AppLocalizations l10n,
    SharePayload payload,
  ) {
    final int count = payload.images.length;
    final String fallback = count > 1
        ? l10n.shareImagesTitleFromGallery(count)
        : l10n.shareImageTitleFromGallery;

    final String? app = payload.sourceApp;
    if (app != null && app.isNotEmpty) {
      final String title = count > 1
          ? l10n.shareImagesTitleFromApp(app, count)
          : l10n.shareImageTitleFromApp(app);
      if (title.trim().isNotEmpty) {
        return title;
      }
    }

    return fallback.trim().isNotEmpty
        ? fallback
        : l10n.shareTextTitleFallback;
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _escapeAttribute(String value) {
    return _escapeHtml(value).replaceAll("'", '&#39;');
  }

  String _buildContent(AppLocalizations l10n) {
    final String? url = widget.payload.url;
    final String text = _contentController.text.trim();
    final List<String> parts = <String>[];

    if (_includeLink && url != null && url.isNotEmpty) {
      parts.add(
        '<p><a href="${_escapeAttribute(url)}">${_escapeHtml(url)}</a></p>',
      );
    }

    if (text.isNotEmpty) {
      final blocks = text.split(RegExp(r'\n\s*\n'));
      for (final block in blocks) {
        final String trimmed = block.trim();
        if (trimmed.isEmpty) continue;
        parts.add(
          '<p>${_escapeHtml(trimmed).replaceAll('\n', '<br>')}</p>',
        );
      }
    }

    return parts.join();
  }

  Future<void> _save(AppLocalizations l10n) async {
    final String content = _buildContent(l10n);
    final bool hasImages = widget.payload.images.isNotEmpty;
    final bool fullPage = _canClipFullPage && _clipMode == _ClipMode.fullPage;
    if (content.isEmpty && !hasImages && !fullPage) {
      setState(() => _error = l10n.shareEmpty);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _authError = false;
    });

    try {
      final String? url = widget.payload.url;
      final String typedTitle = _titleController.text.trim();
      final String title = typedTitle.isEmpty
          ? (hasImages
              ? _imageShareTitle(l10n, widget.payload)
              : ((url != null && url.isNotEmpty)
                  ? l10n.shareLinkTitleFallback
                  : l10n.shareTextTitleFallback))
          : typedTitle;

      final String noteId;
      if (hasImages) {
        noteId = await TriliumClipperClient.createImageClipping(
          title: title,
          remarkHtml: content,
          images: [
            for (final SharedImage image in widget.payload.images)
              ClippingImage(path: image.path, mime: image.mime),
          ],
          pageUrl: url,
        );
        for (final SharedImage image in widget.payload.images) {
          try {
            final File file = File(image.path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {
            // Ignore cleanup failures.
          }
        }
      } else if (fullPage && url != null && url.isNotEmpty) {
        final PageClipResult result = await PageClipper.clip(
          url: url,
          remarkHtml: content,
          currentTitle: title,
          preferArticleTitle: typedTitle.isEmpty || typedTitle == _initialTitle,
        );
        noteId = result.noteId;
      } else if (url == null || url.isEmpty) {
        final String inboxId = await TriliumClipperClient.getInboxNoteId();
        noteId = await TriliumClipperClient.createEtapiNote(
          parentNoteId: inboxId,
          title: title,
          content: content,
        );
      } else {
        noteId = await TriliumClipperClient.createNote(
          title: title,
          content: content,
          pageUrl: url,
          clipType: 'note',
        );
      }
      if (mounted) {
        Navigator.of(context).pop(noteId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            fullPage ? l10n.shareFullPageFailed(e.toString()) : e.toString();
        _authError = e is ClipperException && e.statusCode == 401;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final bool fullPage = _canClipFullPage && _clipMode == _ClipMode.fullPage;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.share_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.shareToTrilium,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.shareTitle,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.payload.url != null &&
                widget.payload.url!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.link,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        widget.payload.url!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_canClipFullPage) ...[
              SegmentedButton<_ClipMode>(
                segments: <ButtonSegment<_ClipMode>>[
                  ButtonSegment<_ClipMode>(
                    value: _ClipMode.link,
                    label: Text(l10n.shareClipModeLink),
                    icon: const Icon(Icons.link),
                  ),
                  ButtonSegment<_ClipMode>(
                    value: _ClipMode.fullPage,
                    label: Text(l10n.shareClipModeFullPage),
                    icon: const Icon(Icons.article_outlined),
                  ),
                ],
                selected: <_ClipMode>{_clipMode},
                onSelectionChanged: _saving
                    ? null
                    : (Set<_ClipMode> selection) {
                        setState(() => _clipMode = selection.first);
                      },
              ),
              if (fullPage)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.shareFullPageHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (widget.payload.images.isNotEmpty) ...[
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.payload.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final SharedImage image = widget.payload.images[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(image.path),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 96,
                          height: 96,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _contentController,
              minLines: 3,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: l10n.shareRemark,
                hintText: l10n.shareRemarkHint,
                alignLabelWithHint: true,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.payload.url != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.shareIncludeLink),
                value: _includeLink,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _includeLink = value ?? false),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              if (_authError)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final bool saved = await showEtapiTokenDialog(context);
                      if (saved && mounted) {
                        setState(() {
                          _error = null;
                          _authError = false;
                        });
                      }
                    },
                    child: Text(l10n.etapiTokenUpdate),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(l10n),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? (fullPage ? l10n.shareClippingPage : l10n.shareSaving)
                        : l10n.shareSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
