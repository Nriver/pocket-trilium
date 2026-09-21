import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants/defaults.dart';
import 'constants/licenses.dart';
import 'l10n/app_localizations.dart';
import 'workflow.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        _buildSection(
          context,
          title: l10n.userManual,
          icon: Icons.help_outline,
          child: _buildUserManualContent(context),
        ),
        _buildSection(
          context,
          title: l10n.openSourceLicenses,
          icon: Icons.description_outlined,
          child: const Text(openSourceLicenses, style: TextStyle(fontSize: 12)),
        ),
        _buildSection(
          context,
          title: l10n.permissionUsage,
          icon: Icons.privacy_tip_outlined,
          child: Text(l10n.privacyStatement),
        ),
        _buildSection(
          context,
          title: l10n.supportAuthor,
          icon: Icons.favorite_border,
          child: Column(
            children: [
              Text(l10n.supportAuthorDescription),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => launchUrl(
                    Uri.parse("https://github.com/Nriver/pocket-trilium"),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.code),
                label: Text(l10n.projectUrl),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserManualContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.firstLoadInstructions),
        const SizedBox(height: 16),
        Center(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => Permission.ignoreBatteryOptimizations.request(),
                icon: const Icon(Icons.battery_saver),
                label: Text(l10n.ignoreBatteryOptimization),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.updateRequest),
        const SizedBox(height: 16),
        Center(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: D.links.map<Widget>((link) {
              return OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(link["value"]!),
                    mode: LaunchMode.externalApplication),
                icon: _getLinkIcon(link["name"]!),
                label: Text(Util.getl10nText(link["name"]!, context)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _showInfoSheet(
          context,
          title: title,
          icon: icon,
          child: child,
        ),
      ),
    );
  }

  Future<void> _showInfoSheet(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Icon _getLinkIcon(String name) {
    switch (name) {
      case 'projectUrl':
        return const Icon(Icons.home_outlined, size: 18);
      case 'issueUrl':
        return const Icon(Icons.bug_report_outlined, size: 18);
      case 'discussionUrl':
        return const Icon(Icons.forum_outlined, size: 18);
      default:
        return const Icon(Icons.link, size: 18);
    }
  }
}