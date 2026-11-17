import 'package:flutter/material.dart';

import '../constants/defaults.dart';
import '../l10n/app_localizations.dart';
import '../workflow.dart';
import 'deep_link_parser.dart';

class DeepLinkHandler {
  static bool _initialized = false;
  static bool _uiReady = false;
  static bool _processing = false;
  static final List<DeepLinkTarget> _queue = <DeepLinkTarget>[];
  static final Set<dynamic> _seenIds = <dynamic>{};

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _pullPending();
  }

  static Future<void> _pullPending() async {
    try {
      final dynamic pending =
          await D.androidChannel.invokeMethod('getPendingDeepLink');
      _enqueueRaw(pending);
    } catch (_) {}
  }

  static bool get hasPending => _queue.isNotEmpty;

  static void onNativeDeepLink(dynamic value) {
    _enqueueRaw(value);
  }

  static void markUiReady(BuildContext context) {
    _uiReady = true;
    processPending(context);
    _pullPending();
  }

  static void _enqueueRaw(dynamic value) {
    final String? raw =
        value is Map ? value['url']?.toString() : value?.toString();
    if (raw == null || raw.isEmpty) return;

    final dynamic id = value is Map ? value['id'] : null;
    if (id != null && !_seenIds.add(id)) return;

    final DeepLinkTarget? target = DeepLinkParser.parse(raw);
    if (target == null) {
      debugPrint('忽略无法识别的深链: $raw');
      return;
    }

    _queue.add(target);
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
        final DeepLinkTarget target = _queue.removeAt(0);
        try {
          await D.androidChannel.invokeMethod('consumePendingDeepLink');
        } catch (_) {}
        if (!context.mounted) break;
        await _handle(context, target);
      }
    } finally {
      _processing = false;
    }
  }

  static Future<void> _handle(
    BuildContext context,
    DeepLinkTarget target,
  ) async {
    final bool ready = await _waitForServer(context);
    if (!ready || !context.mounted) return;

    await Workflow.waitForAutoOpen();
    if (!context.mounted) return;

    await Workflow.openNoteFragment(target.fragment);
  }

  static Future<bool> _waitForServer(BuildContext context) async {
    if (G.isTriliumReady.value) return true;

    final l10n = AppLocalizations.of(context)!;

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
