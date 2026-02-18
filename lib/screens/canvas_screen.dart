import 'dart:math' as math;

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
      pathBuilder: _buildStrokePath,
      onStrokeStarted: (newStroke, currentStroke) {
        // 描画中のストロークがあればそちらを継続する
        if (currentStroke != null) return currentStroke;
        final kind = newStroke.deviceKind;
        if (kind != PointerDeviceKind.stylus &&
            kind != PointerDeviceKind.mouse) {
          return null;
        }

        final tool = appState.selectedTool;
        if (tool == ToolType.freehand) {
          return newStroke.copyWith(
            color: appState.selectedColor,
            width: 4.0,
            data: {'tool': 'freehand'},
          );
        }
        if (tool == ToolType.lineSolid || tool == ToolType.lineDashed) {
          return newStroke.copyWith(
            color: appState.selectedColor,
            width: 3.0,
            data: {
              'tool': tool == ToolType.lineSolid ? 'lineSolid' : 'lineDashed',
            },
          );
        }
        return null;
      },
      onStrokeUpdated: (stroke) {
        final tool = stroke.data?['tool'] as String?;
        if (tool == 'lineSolid' || tool == 'lineDashed') {
          // 直線: 始点と現在位置の2点のみに制約してプレビュー表示
          if (stroke.points.length < 2) return stroke;
          return stroke.copyWith(
            points: [stroke.points.first, stroke.points.last],
          );
        }
        return stroke;
      },
      onStrokeDrawn: (stroke) {
        // ツール種別によらず、ストロークとして strokes に追加
        // (始点と終点が同じタップのみの場合も含めすべて記録)
        AppStateWidget.of(context).onStrokeDrawn(stroke);
      },
    );
  }
}

/// Stroke の種別に応じて Path を生成する
///
/// - lineDashed: 破線パスを生成
/// - それ以外（freehand / lineSolid）: デフォルトの Catmull-Rom スプライン
///   ※ 2点の実線ストロークは catmullRom で直線として描画される
Path _buildStrokePath(Stroke stroke) {
  final tool = stroke.data?['tool'] as String?;
  if (tool == 'lineDashed') {
    return _buildDashedLinePath(stroke);
  }
  return generateCatmullRomPath(stroke);
}

/// 破線の Path を生成する（TECH_NOTES §1 参照）
Path _buildDashedLinePath(
  Stroke stroke, {
  double dashLength = 10,
  double gapLength = 6,
}) {
  if (stroke.points.length < 2) return Path();
  final a = stroke.points.first.position;
  final b = stroke.points.last.position;

  final path = Path();
  final delta = b - a;
  final length = delta.distance;
  if (length == 0) return path;

  final direction = delta / length;
  double distance = 0.0;

  while (distance < length) {
    final start = a + direction * distance;
    final endDistance = math.min(distance + dashLength, length);
    final end = a + direction * endDistance;
    path.moveTo(start.dx, start.dy);
    path.lineTo(end.dx, end.dy);
    distance = endDistance + gapLength;
  }
  return path;
}
