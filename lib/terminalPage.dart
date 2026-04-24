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
          child: forceScaleGestureDetector(
            onScaleUpdate: (details) {
              G.termFontScale.value =
                  (details.scale * (Util.getGlobal("termFontScale") as double))
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
                  textScaler: TextScaler.linear(value),
                  keyboardType: TextInputType.multiline,
                );
              },
            ),
          ),
        ),

        // 底部控制栏（Ctrl/Alt/Shift + 快捷命令）
        ValueListenableBuilder(
          valueListenable: G.terminalPageChange,
          builder: (context, value, child) {
            final bool showCommands =
                Util.getGlobal("isTerminalCommandsEnabled") as bool;

            return showCommands
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        // Ctrl Alt Shift 开关
                        AnimatedBuilder(
                          animation: G.keyboard,
                          builder: (context, child) => ToggleButtons(
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                            isSelected: [
                              G.keyboard.ctrl,
                              G.keyboard.alt,
                              G.keyboard.shift
                            ],
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
                            children: const [
                              Text('Ctrl'),
                              Text('Alt'),
                              Text('Shift')
                            ],
                          ),
                        ),
                        const SizedBox.square(dimension: 8),

                        // 快捷命令按钮
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                return OutlinedButton(
                                  style: D.controlButtonStyle,
                                  onPressed: () {
                                    G.termPtys[G.currentContainer]!.terminal
                                        .keyInput(
                                      D.termCommands[index]["key"]!
                                          as TerminalKey,
                                    );
                                  },
                                  child: Text(
                                    D.termCommands[index]["name"]! as String,
                                  ),
                                );
                              },
                              separatorBuilder: (context, index) =>
                                  const SizedBox.square(dimension: 4),
                              itemCount: D.termCommands.length,
                            ),
                          ),
                        ),

                        const SizedBox(width: 72), // 占位，保持布局平衡
                      ],
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
