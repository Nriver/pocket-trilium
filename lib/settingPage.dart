import 'package:flutter/material.dart';
import 'package:clipboard/clipboard.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'constants/defaults.dart';
import 'l10n/app_localizations.dart';
import 'workflow.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, l10n.privacySettings, Icons.security),
        _buildPrivacySettings(context, l10n),
        const Divider(),
        _buildSectionHeader(context, l10n.terminal, Icons.terminal),
        _buildTerminalSettings(context, l10n),
        const Divider(),
        _buildSectionHeader(context, l10n.advancedSettings, Icons.settings_applications),
        _buildAdvancedSettings(context, l10n),
        const Divider(),
        _buildSectionHeader(context, l10n.globalSettings, Icons.settings),
        _buildGlobalSettings(context, l10n),
        const Divider(),
        _buildSectionHeader(context, l10n.reinstallUpgradeGroup, Icons.system_update_alt),
        _buildDangerSettings(context, l10n),
        const Divider(),
        _buildSectionHeader(context, l10n.maintenanceToolsGroup, Icons.build),
        _buildMaintenanceTools(context, l10n),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.blur_on),
          title: Text(l10n.privacyBlur),
          subtitle: Text(l10n.privacyBlurSubtitle),
          value: Util.getGlobal("isPrivacyBlurEnabled") as bool,
          onChanged: (value) {
            G.prefs.setBool("isPrivacyBlurEnabled", value);
            setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: Text(l10n.biometricUnlock),
          subtitle: Text(l10n.biometricUnlockSubtitle),
          value: Util.getGlobal("isBiometricUnlockEnabled") as bool,
          onChanged: (value) async {
            if (value) {
              bool authenticated = await Util.authenticate();
              if (authenticated) {
                G.prefs.setBool("isBiometricUnlockEnabled", true);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.biometricUnlockFailed))
                  );
                }
              }
            } else {
              G.prefs.setBool("isBiometricUnlockEnabled", false);
            }
            setState(() {});
          },
        ),
        if (Util.getGlobal("isBiometricUnlockEnabled") as bool)
          SwitchListTile(
            secondary: const Icon(Icons.timer_outlined),
            title: Text(l10n.biometricOnlyOnStart),
            subtitle: Text(l10n.biometricOnlyOnStartSubtitle),
            value: Util.getGlobal("isBiometricOnlyOnStart") as bool,
            onChanged: (value) {
              G.prefs.setBool("isBiometricOnlyOnStart", value);
              setState(() {});
            },
          ),
      ],
    );
  }

  Widget _buildTerminalSettings(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            initialValue: (Util.getGlobal("termMaxLines") as int).toString(),
            decoration: InputDecoration(
              icon: const Icon(Icons.format_list_numbered),
              border: const OutlineInputBorder(),
              labelText: l10n.terminalMaxLines,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              return Util.validateBetween(value, 1024, 2147483647, () async {
                await G.prefs.setInt("termMaxLines", int.parse(value!));
              });
            },
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.edit_note),
          title: Text(l10n.enableTerminal),
          value: Util.getGlobal("isTerminalWriteEnabled") as bool,
          onChanged: (value) {
            G.prefs.setBool("isTerminalWriteEnabled", value);
            setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.keyboard_alt_outlined),
          title: Text(l10n.enableTerminalKeypad),
          value: Util.getGlobal("isTerminalCommandsEnabled") as bool,
          onChanged: (value) {
            G.prefs.setBool("isTerminalCommandsEnabled", value);
            setState(() {
              G.terminalPageChange.value = !G.terminalPageChange.value;
            });
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.ads_click),
          title: Text(l10n.terminalStickyKeys),
          value: Util.getGlobal("isStickyKey") as bool,
          onChanged: (value) {
            G.prefs.setBool("isStickyKey", value);
            setState(() {});
          },
        ),
      ],
    );
  }

  Future<void> _editAppStartCommand(BuildContext context, AppLocalizations l10n) async {
    final String? command = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _AppStartCommandDialog(l10n: l10n),
    );
    if (command != null) {
      await Util.setCurrentProp("appStartCommand", command);
    }
  }

  Widget _buildAdvancedSettings(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.restartAfterChange, style: Theme.of(context).textTheme.bodySmall),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.terminal),
            title: Text(l10n.triliumStartupCommand),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editAppStartCommand(context, l10n),
          ),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              label: Text(l10n.resetToDefault),
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(this.context);
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: Text(l10n.resetToDefault),
                    content: Text(l10n.confirmResetToDefaultTriliumStartCommand),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        child: Text(l10n.confirm),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Util.setCurrentProp("appStartCommand", D.triliumStartCommand);
                  if (mounted) {
                    messenger.showSnackBar(
                        SnackBar(content: Text(l10n.resetSuccessful))
                    );
                  }
                }
              },
            ),
          ),
          const Divider(height: 32),
          Text(l10n.shareUsageHint),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: Text(l10n.copyShareLink),
              onPressed: () async {
                final String? ip = await NetworkInfo().getWifiIP();
                if (!context.mounted) return;
                if (ip == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.cannotGetIpAddress))
                  );
                  return;
                }
                FlutterClipboard.copy(
                  (Util.getCurrentProp("webUrl") as String)
                      .replaceAll(RegExp.escape("localhost"), ip),
                ).then((value) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.shareLinkCopied))
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            maxLines: null,
            initialValue: Util.getCurrentProp("webUrl"),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n.webRedirectUrl,
            ),
            onChanged: (value) async {
              await Util.setCurrentProp("webUrl", value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalSettings(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.language),
          trailing: DropdownButton<String?>(
            value: Util.getGlobal("locale"),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.systemDefault)),
              const DropdownMenuItem(value: "zh", child: Text("中文")),
              const DropdownMenuItem(value: "en", child: Text("English")),
            ],
            onChanged: (value) {
              if (value == null) {
                G.prefs.remove("locale");
                G.locale.value = null;
              } else {
                G.prefs.setString("locale", value);
                G.locale.value = Locale(value);
              }
              setState(() {});
            },
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: Text(l10n.keepScreenOn),
          value: Util.getGlobal("wakelock") as bool,
          onChanged: (value) {
            G.prefs.setBool("wakelock", value);
            WakelockPlus.toggle(enable: value);
            setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.rocket_launch_outlined),
          title: Text(l10n.startWithGUI),
          value: Util.getGlobal("autoLaunchGUI") as bool,
          onChanged: (value) {
            G.prefs.setBool("autoLaunchGUI", value);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildDangerSettings(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.restartRequiredHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          _buildDangerZone(l10n),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTools(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildActionButton(context, l10n.ignoreBatteryOptimization, Icons.battery_saver_outlined, () {
              Permission.ignoreBatteryOptimizations.request();
            }),
            const SizedBox(width: 8),
            _buildActionButton(context, l10n.clearAppCache, Icons.cleaning_services_outlined, () async {
              await Util.clearAppCache();
            }),
            const SizedBox(width: 8),
            _buildActionButton(context, l10n.signal9ErrorPage, Icons.bug_report_outlined, () async {
              await D.androidChannel.invokeMethod("launchSignal9Page", {});
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: colorScheme.primary),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.2, color: colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDangerZone(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(l10n.reinstallTrilium, style: const TextStyle(color: Colors.red)),
            value: Util.getGlobal("reinstallTrilium") as bool,
            activeColor: Colors.red,
            onChanged: (value) {
              G.prefs.setBool("reinstallTrilium", value);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(l10n.reinstallBootPackage, style: const TextStyle(color: Colors.red)),
            value: Util.getGlobal("reinstallBootstrap") as bool,
            activeColor: Colors.red,
            onChanged: (value) {
              G.prefs.setBool("reinstallBootstrap", value);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(l10n.reinstallRootfs, style: const TextStyle(color: Colors.red)),
            value: G.prefs.getBool("reinstallRootfs") ?? false,
            activeColor: Colors.red,
            onChanged: (value) {
              G.prefs.setBool("reinstallRootfs", value);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class _AppStartCommandDialog extends StatefulWidget {
  final AppLocalizations l10n;

  const _AppStartCommandDialog({required this.l10n});

  @override
  State<_AppStartCommandDialog> createState() => _AppStartCommandDialogState();
}

class _AppStartCommandDialogState extends State<_AppStartCommandDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: Util.getCurrentProp("appStartCommand"));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.triliumStartupCommand,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                expands: true,
                minLines: null,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l10n.triliumStartupCommand,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_controller.text),
                  child: Text(l10n.confirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}