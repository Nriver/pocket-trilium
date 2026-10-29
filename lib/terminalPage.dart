import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'constants/defaults.dart';
import 'l10n/app_localizations.dart';
import 'workflow.dart';

enum _TerminalLogAction { copySelection, selectAll, copyAll }

// 强制接受缩放手势的识别器（解决某些设备上缩放被拒绝的问题）
class ForceScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    super.acceptGesture(pointer);
  }
}

// 支持强制缩放的手势探测器
RawGestureDetector forceScaleGestureDetector({
  GestureScaleUpdateCallback? onScaleUpdate,
  GestureScaleEndCallback? onScaleEnd,
  Widget? child,
}) {
  return RawGestureDetector(
    gestures: {
      ForceScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<ForceScaleGestureRecognizer>(
        () => ForceScaleGestureRecognizer(),
        (detector) {
          detector.onUpdate = onScaleUpdate;
          detector.onEnd = onScaleEnd;
        },
      )
    },
    child: child,
  );
}

// 终端页面
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  late final TerminalController _terminalController;

  Terminal get _terminal => G.termPtys[G.currentContainer]!.terminal;

  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController();
  }

  @override
  void dispose() {
    _terminalController.clearSelection();
    _terminalController.dispose();
    super.dispose();
  }

  Future<void> _copySelection() async {
    final selection = _terminalController.selection;
    if (selection == null) return;

    final text = _terminal.buffer.getText(selection);
    await _copyText(text);
  }

  Future<void> _copyAll() async {
    await _copyText(_terminal.buffer.getText());
  }

  Future<void> _copyText(String text) async {
    final l10n = AppLocalizations.of(context)!;
    if (text.isEmpty) {
      _showMessage(l10n.terminalNoOutput);
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showMessage(l10n.copiedToClipboard);
  }

  void _selectAll() {
    final buffer = _terminal.buffer;
    if (buffer.height <= 0) return;

    _terminalController.setSelection(
      buffer.createAnchor(0, 0),
      buffer.createAnchor(_terminal.viewWidth, buffer.height - 1),
      mode: SelectionMode.line,
    );
  }

  void _clearSelection() {
    _terminalController.clearSelection();
  }

  void _handleLogAction(_TerminalLogAction action) {
    switch (action) {
      case _TerminalLogAction.copySelection:
        _copySelection();
        break;
      case _TerminalLogAction.selectAll:
        _selectAll();
        break;
      case _TerminalLogAction.copyAll:
        _copyAll();
        break;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Widget _buildLogActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<_TerminalLogAction>(
        tooltip: l10n.more,
        icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 20),
        onSelected: _handleLogAction,
        itemBuilder: (context) {
          final hasSelection = _terminalController.selection != null;
          return [
            if (hasSelection)
              PopupMenuItem(
                value: _TerminalLogAction.copySelection,
                child: Text(l10n.copy),
              ),
            PopupMenuItem(
              value: _TerminalLogAction.selectAll,
              child: Text(l10n.selectAll),
            ),
            PopupMenuItem(
              value: _TerminalLogAction.copyAll,
              child: Text(l10n.copyAllLogs),
            ),
          ];
        },
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: const Color(0xFFF2F2F2),
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1F1F1F),
              ),
              onPressed: _copySelection,
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.copy),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF424242),
              ),
              onPressed: _selectAll,
              child: Text(l10n.selectAll),
            ),
            IconButton(
              tooltip: l10n.cancel,
              icon: const Icon(
                Icons.close,
                color: Color(0xFF424242),
                size: 18,
              ),
              onPressed: _clearSelection,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 终端主区域 + 手势缩放
        Expanded(
          child: Container(
            color: D.terminalTheme.background,
            child: Stack(
              children: [
                Positioned.fill(
                  child: forceScaleGestureDetector(
                    onScaleUpdate: (details) {
                      G.termFontScale.value = (details.scale *
                              (Util.getGlobal("termFontScale") as double))
                          .clamp(0.2, 5.0);
                    },
                    onScaleEnd: (details) async {
                      await G.prefs
                          .setDouble("termFontScale", G.termFontScale.value);
                    },
                    child: ValueListenableBuilder<double>(
                      valueListenable: G.termFontScale,
                      builder: (context, value, child) {
                        return TerminalView(
                          _terminal,
                          controller: _terminalController,
                          theme: D.terminalTheme,
                          textScaler: TextScaler.linear(value),
                          keyboardType: TextInputType.multiline,
                          autofocus: true,
                        );
                      },
                    ),
                  ),
                ),

                // 右上角日志操作菜单
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildLogActions(context),
                ),

                // 长按选中文本后显示的选择操作栏
                ListenableBuilder(
                  listenable: _terminalController,
                  builder: (context, child) {
                    return Positioned(
                      top: 8,
                      left: 8,
                      right: 64,
                      child: _terminalController.selection == null
                          ? const SizedBox.shrink()
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: _buildSelectionBar(context),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // 底部控制栏（Ctrl/Alt/Shift + 快捷命令）
        ValueListenableBuilder(
          valueListenable: G.terminalPageChange,
          builder: (context, value, child) {
            final bool showCommands =
                Util.getGlobal("isTerminalCommandsEnabled") as bool;

            if (!showCommands) return const SizedBox.shrink();

            return Container(
              color: D.terminalTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Ctrl Alt Shift 开关
                    AnimatedBuilder(
                      animation: G.keyboard,
                      builder: (context, child) {
                        return Row(
                          children: [
                            _buildControlButton(
                              'Ctrl',
                              G.keyboard.ctrl,
                              () => G.keyboard.ctrl = !G.keyboard.ctrl,
                            ),
                            const SizedBox(width: 4),
                            _buildControlButton(
                              'Alt',
                              G.keyboard.alt,
                              () => G.keyboard.alt = !G.keyboard.alt,
                            ),
                            const SizedBox(width: 4),
                            _buildControlButton(
                              'Shift',
                              G.keyboard.shift,
                              () => G.keyboard.shift = !G.keyboard.shift,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // 快捷命令按钮
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            return OutlinedButton(
                              style: D.controlButtonStyle,
                              onPressed: () {
                                G.termPtys[G.currentContainer]!.terminal
                                    .keyInput(
                                  D.termCommands[index]["key"]! as TerminalKey,
                                );
                              },
                              child: Text(
                                D.termCommands[index]["name"]! as String,
                              ),
                            );
                          },
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 4),
                          itemCount: D.termCommands.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildControlButton(String label, bool isActive, VoidCallback onTap) {
    return OutlinedButton(
      style: isActive ? D.activeControlButtonStyle : D.controlButtonStyle,
      onPressed: onTap,
      child: Text(label),
    );
  }
}
