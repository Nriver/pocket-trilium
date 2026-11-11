import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../workflow.dart';
import 'clipper_client.dart';

/// Shows the ETAPI token editor. Returns true when the token was saved.
Future<bool> showEtapiTokenDialog(BuildContext context) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (_) => const _EtapiTokenDialog(),
  );
  return result == true;
}

class _EtapiTokenDialog extends StatefulWidget {
  const _EtapiTokenDialog();

  @override
  State<_EtapiTokenDialog> createState() => _EtapiTokenDialogState();
}

class _EtapiTokenDialogState extends State<_EtapiTokenDialog> {
  late final TextEditingController _controller;
  bool _testing = false;
  bool _saving = false;
  String? _message;
  bool? _messageOk;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (Util.getCurrentProp("etapiToken") as String? ?? "").trim(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test(AppLocalizations l10n) async {
    setState(() {
      _testing = true;
      _message = null;
      _messageOk = null;
    });
    try {
      await TriliumClipperClient.testConnection(
        authToken: _controller.text,
      );
      if (!mounted) return;
      setState(() {
        _testing = false;
        _message = l10n.etapiTokenValid;
        _messageOk = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _message = l10n.etapiTokenInvalid(e.toString());
        _messageOk = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Util.addCurrentProp("etapiToken", _controller.text.trim());
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.etapiToken),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.etapiTokenHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.etapiToken,
                hintText: l10n.etapiTokenHint,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _messageOk == true
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: (_testing || _saving) ? null : () => _test(l10n),
          child: Text(_testing ? l10n.etapiTokenTesting : l10n.etapiTokenTest),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.shareSave),
        ),
      ],
    );
  }
}
