import 'package:draw_your_image/draw_your_image.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ui/toolbar.dart';

class CanvasScreen extends StatelessWidget {
  const CanvasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Row(
        children: [
          // 左サイドツールバー
          const Toolbar(),
          // キャンバス領域
          const Expanded(child: _CanvasArea()),
        ],
      ),
    );
  }
}

class _CanvasArea extends StatelessWidget {
  const _CanvasArea();

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);

    // すべての描画物（画像を除く）は Stroke に落とし込んで Draw で描画する
    return Draw(
      strokes: appState.canvasState.strokes,
      backgroundColor: Colors.white,
      onStrokeStarted: (newStroke, currentStroke) {
        // 描画中のストロークがあればそちらを継続する
        if (currentStroke != null) return currentStroke;
        // フリーハンドモードかつスタイラス/マウスのみ描画を許可
        if (appState.selectedTool != ToolType.freehand) return null;
        final kind = newStroke.deviceKind;
        if (kind == PointerDeviceKind.stylus ||
            kind == PointerDeviceKind.mouse) {
          return newStroke.copyWith(
            color: appState.selectedColor,
            width: 4.0,
          );
        }
        return null;
      },
      onStrokeDrawn: (stroke) {
        AppStateWidget.of(context).onStrokeDrawn(stroke);
      },
    );
  }
}
