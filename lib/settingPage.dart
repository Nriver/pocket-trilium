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
  final List<bool> _expandState = [false, false, false];

  Key _appStartCommandKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: const EdgeInsets.all(0),
      expansionCallback: (panelIndex, isExpanded) {
        setState(() {
          _expandState[panelIndex] = isExpanded;
        });
      },
      children: [
        ExpansionPanel(
          isExpanded: _expandState[0],
          headerBuilder: ((context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.advancedSettings),
              subtitle: Text(AppLocalizations.of(context)!.restartAfterChange),
            );
          }),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox.square(dimension: 8),

                TextFormField(
                  key: _appStartCommandKey,
                  maxLines: null,
                  initialValue: Util.getCurrentProp("appStartCommand"),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.triliumStartupCommand,
                  ),
                  onChanged: (value) async {
                    await Util.setCurrentProp("appStartCommand", value);
                  },
                ),

                const SizedBox.square(dimension: 8),

                Center(
                  child: OutlinedButton(
                    style: D.commandButtonStyle,
                    child: Text(AppLocalizations.of(context)!.resetToDefault),
                    onPressed: () async {
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(AppLocalizations.of(context)!.resetToDefault),
                          content: Text(
                            AppLocalizations.of(context)!.confirmResetToDefaultTriliumStartCommand,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(AppLocalizations.of(context)!.confirm),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await Util.setCurrentProp("appStartCommand", D.triliumStartCommand);

                        if (mounted) {
                          setState(() {
                            _appStartCommandKey = UniqueKey();
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.resetSuccessful),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),

                const SizedBox.square(dimension: 16),
                const Divider(height: 2, indent: 8, endIndent: 8),
                const SizedBox.square(dimension: 16),

                Text(AppLocalizations.of(context)!.shareUsageHint),
                const SizedBox.square(dimension: 16),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    OutlinedButton(
                      style: D.commandButtonStyle,
                      child: Text(AppLocalizations.of(context)!.copyShareLink),
                      onPressed: () async {
                        final String? ip = await NetworkInfo().getWifiIP();
                        if (!context.mounted) return;
                        if (ip == null) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.cannotGetIpAddress)),
                          );
                          return;
                        }
                        FlutterClipboard.copy(
                          (Util.getCurrentProp("webUrl") as String)
                              .replaceAll(RegExp.escape("localhost"), ip),
                        ).then((value) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.shareLinkCopied)),
                          );
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox.square(dimension: 16),

                TextFormField(
                  maxLines: null,
                  initialValue: Util.getCurrentProp("webUrl"),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.webRedirectUrl,
                  ),
                  onChanged: (value) async {
                    await Util.setCurrentProp("webUrl", value);
                  },
                ),
                const SizedBox.square(dimension: 8),
              ],
            ),
          ),
        ),

        ExpansionPanel(
          isExpanded: _expandState[1],
          headerBuilder: ((context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.globalSettings),
              subtitle: Text(AppLocalizations.of(context)!.enableTerminalEditing),
            );
          }),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  initialValue: (Util.getGlobal("termMaxLines") as int).toString(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.terminalMaxLines,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    return Util.validateBetween(value, 1024, 2147483647, () async {
                      await G.prefs.setInt("termMaxLines", int.parse(value!));
                    });
                  },
                ),
                const SizedBox.square(dimension: 16),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.enableTerminal),
                  value: Util.getGlobal("isTerminalWriteEnabled") as bool,
                  onChanged: (value) {
                    G.prefs.setBool("isTerminalWriteEnabled", value);
                    setState(() {});
                  },
                ),
                const SizedBox.square(dimension: 8),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.enableTerminalKeypad),
                  value: Util.getGlobal("isTerminalCommandsEnabled") as bool,
                  onChanged: (value) {
                    G.prefs.setBool("isTerminalCommandsEnabled", value);
                    setState(() {
                      G.terminalPageChange.value = !G.terminalPageChange.value;
                    });
                  },
                ),
                const SizedBox.square(dimension: 8),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.terminalStickyKeys),
                  value: Util.getGlobal("isStickyKey") as bool,
                  onChanged: (value) {
                    G.prefs.setBool("isStickyKey", value);
                    setState(() {});
                  },
                ),
                const SizedBox.square(dimension: 8),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.keepScreenOn),
                  value: Util.getGlobal("wakelock") as bool,
                  onChanged: (value) {
                    G.prefs.setBool("wakelock", value);
                    WakelockPlus.toggle(enable: value);
                    setState(() {});
                  },
                ),
                const SizedBox.square(dimension: 8),
                const Divider(height: 2, indent: 8, endIndent: 8),
                const SizedBox.square(dimension: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    OutlinedButton(
                      style: D.commandButtonStyle,
                      child: Text(AppLocalizations.of(context)!.ignoreBatteryOptimization),
                      onPressed: () {
                        Permission.ignoreBatteryOptimizations.request();
                      },
                    ),
                  ],
                ),
                const SizedBox.square(dimension: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    OutlinedButton(
                      style: D.commandButtonStyle,
                      child: Text(AppLocalizations.of(context)!.clearAppCache),
                      onPressed: () async {
                        await Util.clearAppCache();
                      },
                    ),
                  ],
                ),
                const SizedBox.square(dimension: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    OutlinedButton(
                      style: D.commandButtonStyle,
                      child: Text(AppLocalizations.of(context)!.signal9ErrorPage),
                      onPressed: () async {
                        await D.androidChannel.invokeMethod("launchSignal9Page", {});
                      },
                    ),
                  ],
                ),
                const SizedBox.square(dimension: 8),
                const Divider(height: 2, indent: 8, endIndent: 8),
                const SizedBox.square(dimension: 16),
                Text(AppLocalizations.of(context)!.restartRequiredHint),
                const SizedBox.square(dimension: 8),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.startWithGUI),
                  value: Util.getGlobal("autoLaunchGUI") as bool,
                  onChanged: (value) {
                    G.prefs.setBool("autoLaunchGUI", value);
                    setState(() {});
                  },
                ),
                const SizedBox.square(dimension: 8),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.reinstallBootPackage),
                  value: Util.getGlobal("reinstallBootstrap") as bool,
                  onChanged: (value) {
                    G.prefs.setBool("reinstallBootstrap", value);
                    setState(() {});
                  },
                ),
                const SizedBox.square(dimension: 8),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.reinstallTrilium),
                  value: Util.getGlobal("reinstallTrilium") as bool,
                  onChanged: (value) {
                    G.prefs.setBool("reinstallTrilium", value);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}