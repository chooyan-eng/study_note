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
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // 左サイドツールバー
          const Toolbar(),
          // キャンバス領域（方眼トグルボタンを右上に重ねる）
          Expanded(
            child: Stack(
              children: const [
                _CanvasArea(),
                Positioned(top: 12, right: 12, child: _GridToggleButton()),
              ],
            ),
          ),
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
    final isEraser = appState.selectedTool == ToolType.eraser;

    // 方眼表示: Draw の上に GridPaper を重ねる（IgnorePointer で入力は Draw へ透過）
    return Stack(
      children: [
        if (appState.showGrid)
          Positioned.fill(
            child: IgnorePointer(
              child: GridPaper(
                color: const Color(0x28888888), // 約16%の薄い灰色
                interval: 10,
                divisions: 1,
                subdivisions: 1,
              ),
            ),
          ),

        Draw(
          strokes: appState.canvasState.strokes,
          backgroundColor: Colors.transparent,
          pathBuilder: _buildStrokePath,
          // 消しゴムモード時のみ標準の交差判定を有効にする
          intersectionDetector: isEraser
              ? IntersectionMode.segmentDistance.detector
              : null,
          onStrokesSelected: isEraser
              ? (strokes) => AppStateWidget.of(context).eraseStrokes(strokes)
              : null,
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
                data: {'tool': 'freehand', 'layer': appState.activeLayer},
              );
            }
            if (tool == ToolType.lineSolid || tool == ToolType.lineDashed) {
              return newStroke.copyWith(
                color: appState.selectedColor,
                width: 3.0,
                data: {
                  'tool': tool == ToolType.lineSolid
                      ? 'lineSolid'
                      : 'lineDashed',
                  'layer': appState.activeLayer,
                },
              );
            }
            if (tool == ToolType.eraser) {
              AppStateWidget.of(context).resetEraserHistory();
              return newStroke.copyWith(
                color: Colors.transparent,
                width: 20.0, // 交差判定の閾値として使われる幅
                data: {'tool': 'eraser'},
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
            // 消しゴムストロークはキャンバスに追加しない
            if (stroke.data?['tool'] == 'eraser') return;
            AppStateWidget.of(context).onStrokeDrawn(stroke);
          },
        ),
      ],
    );
  }
}

/// 右上に表示する方眼ON/OFFトグルボタン
class _GridToggleButton extends StatelessWidget {
  const _GridToggleButton();

  @override
  Widget build(BuildContext context) {
    final showGrid = AppState.of(context).showGrid;
    return GestureDetector(
      onTap: () => AppStateWidget.of(context).toggleGrid(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: showGrid ? const Color(0xFF0A84FF) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.grid_on, color: Colors.white, size: 22),
      ),
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
  if (tool == 'eraser') {
    // 消しゴムストロークは描画しない（ヒットテストのみ使用）
    return Path();
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
