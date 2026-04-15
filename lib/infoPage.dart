import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants/defaults.dart';
import 'constants/licenses.dart';
import 'l10n/app_localizations.dart';
import 'workflow.dart';

class InfoPage extends StatefulWidget {
  final bool openFirstInfo;

  const InfoPage({super.key, this.openFirstInfo = false});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final List<bool> _expandState = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    _expandState[0] = widget.openFirstInfo;
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: const EdgeInsets.all(0),
      expansionCallback: (panelIndex, isExpanded) {
        _expandState[panelIndex] = isExpanded;
        WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
      },
      children: [
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(
                title: Text(AppLocalizations.of(context)!.userManual));
          },
          body: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(AppLocalizations.of(context)!.firstLoadInstructions),
                  const SizedBox.square(dimension: 16),
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: [
                        OutlinedButton(
                            style: D.commandButtonStyle,
                            child: Text(AppLocalizations.of(context)!
                                .ignoreBatteryOptimization),
                            onPressed: () {
                              Permission.ignoreBatteryOptimizations.request();
                            }),
                      ]),
                  const SizedBox.square(dimension: 16),
                  Text(AppLocalizations.of(context)!.updateRequest),
                  const SizedBox.square(dimension: 16),
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: D.links.asMap().entries.map<Widget>((e) {
                        return OutlinedButton(
                            style: D.commandButtonStyle,
                            child: Text(
                                Util.getl10nText(e.value["name"]!, context)),
                            onPressed: () {
                              launchUrl(Uri.parse(e.value["value"]!),
                                  mode: LaunchMode.externalApplication);
                            });
                      }).toList()),
                ],
              )),
          isExpanded: _expandState[0],
        ),
        ExpansionPanel(
            isExpanded: _expandState[1],
            headerBuilder: ((context, isExpanded) {
              return ListTile(
                  title:
                      Text(AppLocalizations.of(context)!.openSourceLicenses));
            }),
            body: const Padding(
                padding: EdgeInsets.all(8), child: Text(openSourceLicenses))),
        ExpansionPanel(
            isExpanded: _expandState[2],
            headerBuilder: ((context, isExpanded) {
              return ListTile(
                  title: Text(AppLocalizations.of(context)!.permissionUsage));
            }),
            body: Padding(
                padding: EdgeInsets.all(8),
                child: Text(AppLocalizations.of(context)!.privacyStatement))),
        ExpansionPanel(
            isExpanded: _expandState[3],
            headerBuilder: ((context, isExpanded) {
              return ListTile(
                  title: Text(AppLocalizations.of(context)!.supportAuthor));
            }),
            body: Column(children: [
              Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                      AppLocalizations.of(context)!.supportAuthorDescription)),
              ElevatedButton(
                onPressed: () {
                  launchUrl(
                      Uri.parse("https://github.com/Nriver/pocket-trilium"),
                      mode: LaunchMode.externalApplication);
                },
                child: Text(AppLocalizations.of(context)!.projectUrl),
              ),
            ])),
      ],
    );
  }
}
