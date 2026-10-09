import 'dart:async';
import 'dart:math';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pocket_trilium/settingPage.dart';
import 'package:pocket_trilium/terminalPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/defaults.dart';
import 'infoPage.dart';
import 'l10n/app_localizations.dart';
import 'workflow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  G.prefs = await SharedPreferences.getInstance();
  String? localeCode = Util.getGlobal("locale");
  if (localeCode != null) {
    G.locale.value = Locale(localeCode);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return ValueListenableBuilder(
        valueListenable: G.locale,
        builder: (context, Locale? locale, child) {
          return MaterialApp(
            builder: (context, child) => AppLifecycleOverlay(child: child!),
            locale: locale,
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
        },
      );
    });
  }
}

//限制最大宽高比1:1
class AspectRatioMax1To1 extends StatelessWidget {
  final Widget child;

  //final double aspectRatio;

  const AspectRatioMax1To1(
      {super.key, required this.child /*, required this.aspectRatio*/
      });

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
    return LinearProgressIndicator(
        value: 1 - pow(10, _progressT / -300).toDouble());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(8),
        child: AspectRatioMax1To1(
            child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: FractionallySizedBox(
                widthFactor: 0.4,
                child: Image(image: AssetImage("images/icon.png"))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: ValueListenableBuilder(
                valueListenable: G.updateText,
                builder: (context, value, child) {
                  return Text(value, textScaler: const TextScaler.linear(2));
                }),
          ),
          const FakeLoadingStatus(),
          const Expanded(
              child: Padding(
            padding: EdgeInsets.all(8),
            child: Card(
                child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Scrollbar(
                        child: SingleChildScrollView(child: InfoPage())))),
          ))
        ])));
  }
}

//终端未显示时覆盖在上面的启动遮罩，给不熟悉终端的用户一个友好的界面
class TriliumStartingOverlay extends StatelessWidget {
  const TriliumStartingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FractionallySizedBox(
                widthFactor: 0.3,
                child: Image(image: AssetImage("images/icon.png")),
              ),
              const SizedBox(height: 24),
              ValueListenableBuilder<bool>(
                valueListenable: G.isTriliumReady,
                builder: (context, ready, child) {
                  return Text(
                    ready ? l10n.triliumStartedTitle : l10n.triliumStartingTitle,
                    textScaler: const TextScaler.linear(1.6),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: G.isTriliumReady,
                builder: (context, ready, child) {
                  return SizedBox(
                    width: 200,
                    child: ready
                        ? const LinearProgressIndicator(value: 1)
                        : const FakeLoadingStatus(),
                  );
                },
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: G.isTriliumReady,
                builder: (context, ready, child) {
                  return Text(
                    ready
                        ? l10n.triliumStartedSubtitle
                        : l10n.triliumStartingSubtitle,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Workflow.launchBrowser();
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.enterGUI),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.triliumStartingHint,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
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
    Future.delayed(Duration.zero, () {
      _initializeWorkflow();
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);
  }

  @override
  void dispose() {
    super.dispose();
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
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([G.pageIndex, G.isTerminalVisible]),
            builder: (context, child) {
              final l10n = AppLocalizations.of(context)!;
              final bool terminalVisible = G.isTerminalVisible.value;
              final bool onTerminalTab = G.pageIndex.value == 0;
              return Visibility(
                visible: isLoadingComplete && onTerminalTab,
                child: IconButton(
                  tooltip:
                      terminalVisible ? l10n.hideTerminal : l10n.showTerminal,
                  icon: Icon(terminalVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () {
                    G.isTerminalVisible.value = !terminalVisible;
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: isLoadingComplete
          ? ValueListenableBuilder(
              valueListenable: G.pageIndex,
              builder: (context, value, child) {
                return IndexedStack(
                  index: G.pageIndex.value,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: G.isTerminalVisible,
                      builder: (context, visible, child) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeIn,
                          switchOutCurve: Curves.easeOut,
                          child: visible
                              ? const TerminalPage()
                              : const TriliumStartingOverlay(),
                        );
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: AspectRatioMax1To1(
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            restorationId: "control-scroll",
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: const FractionallySizedBox(
                                    widthFactor: 0.4,
                                    child: Image(
                                        image: AssetImage("images/icon.png")),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        children: [
                                          const SettingPage(),
                                          const SizedBox.square(dimension: 16),
                                          const InfoPage(),
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
                NavigationDestination(
                    icon: const Icon(Icons.monitor),
                    label: AppLocalizations.of(context)!.terminal),
                NavigationDestination(
                    icon: const Icon(Icons.video_settings),
                    label: AppLocalizations.of(context)!.control),
              ],
              onDestinationSelected: (index) {
                G.pageIndex.value = index;
              },
            ),
          );
        },
      ),
      floatingActionButton: ListenableBuilder(
        listenable: Listenable.merge([G.pageIndex, G.isTerminalVisible]),
        builder: (context, child) {
          final bool showCommands =
              Util.getGlobal("isTerminalCommandsEnabled") as bool;
          final bool onTerminalTab = G.pageIndex.value == 0;
          return Visibility(
            visible:
                isLoadingComplete && onTerminalTab && G.isTerminalVisible.value,
            child: Padding(
              padding: EdgeInsets.only(bottom: showCommands ? 40.0 : 0.0),
              child: FloatingActionButton(
                tooltip: AppLocalizations.of(context)!.enterGUI,
                onPressed: () {
                  Workflow.launchBrowser();
                },
                child: const Icon(Icons.play_arrow),
              ),
            ),
          );
        },
      ),
    );
  }
}
