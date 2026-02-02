import 'dart:async';
import 'dart:math';

import 'package:clipboard/clipboard.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/gestures.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/xterm.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'constants/licenses.dart';
import 'l10n/app_localizations.dart';
import 'workflow.dart';



void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return MaterialApp(
            // 测试 强制显示英文界面
            // locale: const Locale('en'),

            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('zh'),
            ],
            theme: ThemeData(
              colorScheme: lightDynamic,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: darkDynamic,
              useMaterial3: true,
            ),
            home: MyHomePage(title: "Pocket Trilium by Nriver"),
          );
        }
    );
  }
}


//限制最大宽高比1:1
class AspectRatioMax1To1 extends StatelessWidget {
  final Widget child;
  //final double aspectRatio;

  const AspectRatioMax1To1({super.key, required this.child/*, required this.aspectRatio*/});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = MediaQuery.of(context).size;
        //double size = (s.width < s.height * aspectRatio) ? s.width : (s.height * aspectRatio);
        double size = s.width < s.height ? constraints.maxWidth : s.height;

        return Center(
          child: SizedBox(
            width: size,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}


class FakeLoadingStatus extends StatefulWidget {
  const FakeLoadingStatus({super.key});

  @override
  State<FakeLoadingStatus> createState() => _FakeLoadingStatusState();
}

class _FakeLoadingStatusState extends State<FakeLoadingStatus> {

  double _progressT = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progressT += 0.1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: 1 - pow(10, _progressT / -300).toDouble());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {

  final List<bool> _expandState = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: const EdgeInsets.all(0),
      expansionCallback: (panelIndex, isExpanded) {
      setState(() {
        _expandState[panelIndex] = isExpanded;
      });
    },children: [
      ExpansionPanel(
        isExpanded: _expandState[0],
        headerBuilder: ((context, isExpanded) {
          return ListTile(title: Text(AppLocalizations.of(context)!.advancedSettings), subtitle: Text(AppLocalizations.of(context)!.restartAfterChange));
        }), body: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          const SizedBox.square(dimension: 8),
          TextFormField(maxLines: null, initialValue: Util.getCurrentProp("appStartCommand"), decoration: InputDecoration(border: OutlineInputBorder(), labelText: AppLocalizations.of(context)!.triliumStartupCommand), onChanged: (value) async {
            await Util.setCurrentProp("appStartCommand", value);
          }),
          const SizedBox.square(dimension: 8),
          const Divider(height: 2, indent: 8, endIndent: 8),
          const SizedBox.square(dimension: 16),
          Text(AppLocalizations.of(context)!.shareUsageHint),
          const SizedBox.square(dimension: 16),
          Wrap(alignment: WrapAlignment.center, spacing: 4.0, runSpacing: 4.0, children: [
            OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.copyShareLink), onPressed: () async {
              final String? ip = await NetworkInfo().getWifiIP();
              if (!context.mounted) return;
              if (ip == null) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.cannotGetIpAddress))
                );
                return;
              }
              FlutterClipboard.copy((Util.getCurrentProp("webUrl") as String).replaceAll(RegExp.escape("localhost"), ip)).then((value) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.shareLinkCopied))
                );
              });
            }),
          ]),
          const SizedBox.square(dimension: 16),
          TextFormField(maxLines: null, initialValue: Util.getCurrentProp("webUrl"), decoration: InputDecoration(border: OutlineInputBorder(), labelText: AppLocalizations.of(context)!.webRedirectUrl), onChanged: (value) async {
            await Util.setCurrentProp("webUrl", value);
          }),
          const SizedBox.square(dimension: 8),
        ],))),
      ExpansionPanel(
        isExpanded: _expandState[1],
        headerBuilder: ((context, isExpanded) {
          return ListTile(title: Text(AppLocalizations.of(context)!.globalSettings), subtitle: Text(AppLocalizations.of(context)!.enableTerminalEditing));
        }), body: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          TextFormField(autovalidateMode: AutovalidateMode.onUserInteraction, initialValue: (Util.getGlobal("termMaxLines") as int).toString(), decoration: InputDecoration(border: OutlineInputBorder(), labelText: AppLocalizations.of(context)!.terminalMaxLines),
            keyboardType: TextInputType.number,
            validator: (value) {
              return Util.validateBetween(value, 1024, 2147483647, () async {
                await G.prefs.setInt("termMaxLines", int.parse(value!));
              });
            },),
          const SizedBox.square(dimension: 16),
          SwitchListTile(title: Text(AppLocalizations.of(context)!.enableTerminal), value: Util.getGlobal("isTerminalWriteEnabled") as bool, onChanged:(value) {
            G.prefs.setBool("isTerminalWriteEnabled", value);
            setState(() {});
          },),
          const SizedBox.square(dimension: 8),
          SwitchListTile(title: Text(AppLocalizations.of(context)!.enableTerminalKeypad), value: Util.getGlobal("isTerminalCommandsEnabled") as bool, onChanged:(value) {
            G.prefs.setBool("isTerminalCommandsEnabled", value);
            setState(() {
              G.terminalPageChange.value = !G.terminalPageChange.value;
            });
          },),
          const SizedBox.square(dimension: 8),
          SwitchListTile(title: Text(AppLocalizations.of(context)!.terminalStickyKeys), value: Util.getGlobal("isStickyKey") as bool, onChanged:(value) {
            G.prefs.setBool("isStickyKey", value);
            setState(() {});
          },),
          const SizedBox.square(dimension: 8),
          SwitchListTile(title: Text(AppLocalizations.of(context)!.keepScreenOn), value: Util.getGlobal("wakelock") as bool, onChanged:(value) {
            G.prefs.setBool("wakelock", value);
            WakelockPlus.toggle(enable: value);
            setState(() {});
          },),
          const SizedBox.square(dimension: 8),
          const Divider(height: 2, indent: 8, endIndent: 8),
          const SizedBox.square(dimension: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 4.0, runSpacing: 4.0, children: [
            OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.ignoreBatteryOptimization), onPressed: () {
              Permission.ignoreBatteryOptimizations.request();
            }),
          ]),
          const SizedBox.square(dimension: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 4.0, runSpacing: 4.0, children: [
            OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.signal9ErrorPage), onPressed: () async {
              await D.androidChannel.invokeMethod("launchSignal9Page", {});
            }),
          ]),
          const SizedBox.square(dimension: 8),
          const Divider(height: 2, indent: 8, endIndent: 8),
          const SizedBox.square(dimension: 16),
          Text(AppLocalizations.of(context)!.restartRequiredHint),
          const SizedBox.square(dimension: 8),
          SwitchListTile(title: Text(AppLocalizations.of(context)!.startWithGUI), value: Util.getGlobal("autoLaunchGUI") as bool, onChanged:(value) {
            G.prefs.setBool("autoLaunchGUI", value);
            setState(() {});
          },),
          const SizedBox.square(dimension: 8),
          SwitchListTile(title: Text(AppLocalizations.of(context)!.reinstallBootPackage), value: Util.getGlobal("reinstallBootstrap") as bool, onChanged:(value) {
            G.prefs.setBool("reinstallBootstrap", value);
            setState(() {});
          },),
          const SizedBox.square(dimension: 8),
          SwitchListTile(title: Text(AppLocalizations.of(context)!.reinstallTrilium), value: Util.getGlobal("reinstallTrilium") as bool, onChanged:(value) {
            G.prefs.setBool("reinstallTrilium", value);
            setState(() {});
          },),
        ],))),
    ],);
  }
}

class InfoPage extends StatefulWidget {
  final bool openFirstInfo;

  const InfoPage({super.key, this.openFirstInfo=false});

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
          return ListTile(title: Text(AppLocalizations.of(context)!.userManual));
        },
        body: Padding(padding: const EdgeInsets.all(8), child: Column(
          children: [
            Text(AppLocalizations.of(context)!.firstLoadInstructions),
            const SizedBox.square(dimension: 16),
            Wrap(alignment: WrapAlignment.center, spacing: 4.0, runSpacing: 4.0, children: [
              OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.ignoreBatteryOptimization), onPressed: () {
                Permission.ignoreBatteryOptimizations.request();
              }),
            ]),
            const SizedBox.square(dimension: 16),
            Text(AppLocalizations.of(context)!.updateRequest),
            const SizedBox.square(dimension: 16),
            Wrap(alignment: WrapAlignment.center, spacing: 4.0, runSpacing: 4.0, children: D.links
            .asMap().entries.map<Widget>((e) {
              return OutlinedButton(style: D.commandButtonStyle, child: Text(Util.getl10nText(e.value["name"]!, context)), onPressed: () {
                launchUrl(Uri.parse(e.value["value"]!), mode: LaunchMode.externalApplication);
              });
            }).toList()),
          ],
        )),
        isExpanded: _expandState[0],
      ),
      ExpansionPanel(
        isExpanded: _expandState[1],
        headerBuilder: ((context, isExpanded) {
          return ListTile(title: Text(AppLocalizations.of(context)!.openSourceLicenses));
        }), body: const Padding(padding: EdgeInsets.all(8), child: Text(openSourceLicenses))),
      ExpansionPanel(
        isExpanded: _expandState[2],
        headerBuilder: ((context, isExpanded) {
          return ListTile(title: Text(AppLocalizations.of(context)!.permissionUsage));
        }), body: Padding(padding: EdgeInsets.all(8), child: Text(AppLocalizations.of(context)!.privacyStatement))),
      ExpansionPanel(
        isExpanded: _expandState[3],
        headerBuilder: ((context, isExpanded) {
          return ListTile(title: Text(AppLocalizations.of(context)!.supportAuthor));
        }), body: Column(
        children: [
          Padding(padding: EdgeInsets.all(8), child: Text(AppLocalizations.of(context)!.supportAuthorDescription)),
          ElevatedButton(
            onPressed: () {
              launchUrl(Uri.parse("https://github.com/Nriver/pocket-trilium"), mode: LaunchMode.externalApplication);
            },
            child: Text(AppLocalizations.of(context)!.projectUrl),
          ),
        ]
      )),
    ],
  );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: AspectRatioMax1To1(child:
        Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: FractionallySizedBox(
                widthFactor: 0.4,
                child: Image(
                  image: AssetImage("images/icon.png")
                )
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: ValueListenableBuilder(valueListenable: G.updateText, builder:(context, value, child) {
                return Text(value, textScaler: const TextScaler.linear(2));
              }),
            ),
            const FakeLoadingStatus(),
            const Expanded(child: Padding(padding: EdgeInsets.all(8), child: Card(child: Padding(padding: EdgeInsets.all(8), child: 
              Scrollbar(child:
                SingleChildScrollView(
                  child: InfoPage(openFirstInfo: true)
                )
              )
            ))
            ,))
          ]
        )
      )
    );
  }
}

class ForceScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    super.acceptGesture(pointer);
  }
}

RawGestureDetector forceScaleGestureDetector({
  GestureScaleUpdateCallback? onScaleUpdate,
  GestureScaleEndCallback? onScaleEnd,
  Widget? child,
}) {
  return RawGestureDetector(
    gestures: {
      ForceScaleGestureRecognizer:GestureRecognizerFactoryWithHandlers<ForceScaleGestureRecognizer>(() {
        return ForceScaleGestureRecognizer();
      }, (detector) {
        detector.onUpdate = onScaleUpdate;
        detector.onEnd = onScaleEnd;
      })
    },
    child: child,
  );
}

class TerminalPage extends StatelessWidget {
  const TerminalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [Expanded(child: forceScaleGestureDetector(onScaleUpdate: (details) {
        G.termFontScale.value = (details.scale * (Util.getGlobal("termFontScale") as double)).clamp(0.2, 5);
      }, onScaleEnd: (details) async {
        await G.prefs.setDouble("termFontScale", G.termFontScale.value);
      }, child: ValueListenableBuilder(valueListenable: G.termFontScale, builder:(context, value, child) {
        return TerminalView(G.termPtys[G.currentContainer]!.terminal, textScaler: TextScaler.linear(G.termFontScale.value), keyboardType: TextInputType.multiline);
      },) )), 
      ValueListenableBuilder(valueListenable: G.terminalPageChange, builder:(context, value, child) {
      return (Util.getGlobal("isTerminalCommandsEnabled") as bool)?Padding(padding: const EdgeInsets.all(8), child: Row(children: [AnimatedBuilder(
          animation: G.keyboard,
          builder: (context, child) => ToggleButtons(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            isSelected: [G.keyboard.ctrl, G.keyboard.alt, G.keyboard.shift],
            onPressed: (index) {
              switch (index) {
                case 0:
                  G.keyboard.ctrl = !G.keyboard.ctrl;
                  break;
                case 1:
                  G.keyboard.alt = !G.keyboard.alt;
                  break;
                case 2:
                  G.keyboard.shift = !G.keyboard.shift;
                  break;
              }
            },
            children: const [Text('Ctrl'), Text('Alt'), Text('Shift')],
          ),
        ),
        const SizedBox.square(dimension: 8), 
        Expanded(child: SizedBox(height: 24, child: ListView.separated(scrollDirection: Axis.horizontal, itemBuilder:(context, index) {
          return OutlinedButton(style: D.controlButtonStyle, onPressed: () {
            G.termPtys[G.currentContainer]!.terminal.keyInput(D.termCommands[index]["key"]! as TerminalKey);
          }, child: Text(D.termCommands[index]["name"]! as String));
        }, separatorBuilder:(context, index) {
          return const SizedBox.square(dimension: 4);
        }, itemCount: D.termCommands.length))), SizedBox.fromSize(size: const Size(72, 0))])):const SizedBox.square(dimension: 0);
      })
    ]);
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool bannerAdsFailedToLoad = false;
  bool isLoadingComplete = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero,() {
      _initializeWorkflow();
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);
  }

  Future<void> _initializeWorkflow() async {
    await Workflow.workflow();
    if (mounted) {
      setState(() {
        isLoadingComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    G.homePageStateContext = context;

    return Scaffold(
      appBar: AppBar(
        title: Text(D.containerName),
      ),
      body: isLoadingComplete
          ? ValueListenableBuilder(
              valueListenable: G.pageIndex,
              builder: (context, value, child) {
                return IndexedStack(
                  index: G.pageIndex.value,
                  children: const [
                    TerminalPage(),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: AspectRatioMax1To1(
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            restorationId: "control-scroll",
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: FractionallySizedBox(
                                    widthFactor: 0.4,
                                    child: Image(image: AssetImage("images/icon.png")),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        children: [
                                          SettingPage(),
                                          SizedBox.square(dimension: 8),
                                          InfoPage(openFirstInfo: false),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          : const LoadingPage(),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: G.pageIndex,
        builder: (context, value, child) {
          return Visibility(
            visible: isLoadingComplete,
            child: NavigationBar(
              selectedIndex: G.pageIndex.value,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.monitor), label: AppLocalizations.of(context)!.terminal),
                NavigationDestination(icon: const Icon(Icons.video_settings), label: AppLocalizations.of(context)!.control),
              ],
              onDestinationSelected: (index) {
                G.pageIndex.value = index;
              },
            ),
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder(
        valueListenable: G.pageIndex,
        builder: (context, value, child) {
          return Visibility(
            visible: isLoadingComplete && (value == 0),
            child: FloatingActionButton(
              tooltip: AppLocalizations.of(context)!.enterGUI,
              onPressed: () {
                Workflow.launchBrowser();
              },
              child: const Icon(Icons.play_arrow),
            ),
          );
        },
      ),
    );
  }
}
