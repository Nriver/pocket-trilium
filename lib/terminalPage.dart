import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'constants/defaults.dart';
import 'workflow.dart';

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
class TerminalPage extends StatelessWidget {
  const TerminalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 终端主区域 + 手势缩放
        Expanded(
          child: Container(
            color: D.terminalTheme.background,
            child: forceScaleGestureDetector(
              onScaleUpdate: (details) {
                G.termFontScale.value = (details.scale *
                        (Util.getGlobal("termFontScale") as double))
                    .clamp(0.2, 5.0);
              },
              onScaleEnd: (details) async {
                await G.prefs.setDouble("termFontScale", G.termFontScale.value);
              },
              child: ValueListenableBuilder<double>(
                valueListenable: G.termFontScale,
                builder: (context, value, child) {
                  return TerminalView(
                    G.termPtys[G.currentContainer]!.terminal,
                    theme: D.terminalTheme,
                    textScaler: TextScaler.linear(value),
                    keyboardType: TextInputType.multiline,
                    autofocus: true,
                  );
                },
              ),
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
