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
          const Expanded(
            child: Stack(
              children: [
                _CanvasArea(),
                Positioned(top: 12, right: 12, child: _ControlsPanel()),
                Positioned(bottom: 12, left: 12, child: _StampSizePanel()),
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

    final isEraser = appState.selectedTool == ToolType.eraser;

    return Stack(
      children: [
        // 方眼表示（IgnorePointer で入力は Draw へ透過）
        if (appState.showGrid)
          Positioned.fill(
            child: IgnorePointer(
              child: GridPaper(
                color: const Color(0x28888888),
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
                width: 20.0,
                data: {'tool': 'eraser'},
              );
            }
            // 図形スタンプツール
            if (_isShapeTool(tool)) {
              return newStroke.copyWith(
                color: appState.selectedColor,
                width: 2.5,
                data: {
                  'tool': 'shape',
                  'shapeType': tool.name,
                  'layer': appState.activeLayer,
                },
              );
            }
            return null;
          },
          onStrokeUpdated: (stroke) {
            final tool = stroke.data?['tool'] as String?;
            if (tool == 'lineSolid' || tool == 'lineDashed') {
              if (stroke.points.length < 2) return stroke;
              return stroke.copyWith(
                points: [stroke.points.first, stroke.points.last],
              );
            }
            return stroke;
          },
          onStrokeDrawn: (stroke) {
            if (stroke.data?['tool'] == 'eraser') return;

            // 図形スタンプ: タップ位置を中心に輪郭 StrokePoint を生成して Stroke として追加
            if (stroke.data?['tool'] == 'shape') {
              final center = stroke.points.isNotEmpty
                  ? stroke.points.first.position
                  : const Offset(200, 200);
              final stampSize = appState.stampSize;
              final shapeTypeStr =
                  stroke.data?['shapeType'] as String? ?? 'shapeSquare';
              final shapePoints =
                  _generateShapePoints(shapeTypeStr, center, stampSize);
              AppStateWidget.of(context)
                  .onStrokeDrawn(stroke.copyWith(points: shapePoints));
              return;
            }

            AppStateWidget.of(context).onStrokeDrawn(stroke);
          },
        ),
      ],
    );
  }
}

/// 右上コントロール領域: 方眼トグル・Undo/Redo・クリアをまとめたパネル
class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel();

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final actions = AppStateWidget.of(context);

    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(
            icon: Icons.grid_on,
            tooltip: '方眼',
            isHighlighted: state.showGrid,
            onTap: actions.toggleGrid,
          ),
          const _ControlDivider(),
          _ControlButton(
            icon: Icons.undo,
            tooltip: 'Undo',
            isEnabled: state.canUndo,
            onTap: state.canUndo ? actions.undo : null,
          ),
          _ControlButton(
            icon: Icons.redo,
            tooltip: 'Redo',
            isEnabled: state.canRedo,
            onTap: state.canRedo ? actions.redo : null,
          ),
          const _ControlDivider(),
          _ControlButton(
            icon: Icons.delete_sweep,
            tooltip: 'クリア',
            onTap: actions.clearCanvas,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isHighlighted;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    this.isHighlighted = false,
    this.isEnabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    if (isHighlighted) {
      iconColor = const Color(0xFF0A84FF);
    } else if (!isEnabled || onTap == null) {
      iconColor = const Color(0xFF48484A);
    } else {
      iconColor = const Color(0xFFAEAEB2);
    }

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _ControlDivider extends StatelessWidget {
  const _ControlDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Divider(color: Color(0xFF48484A), height: 1, thickness: 1),
    );
  }
}

// ─── ToolType ヘルパー ────────────────────────────────────────────────────────

bool _isShapeTool(ToolType tool) {
  return tool == ToolType.shapeSquare ||
      tool == ToolType.shapeCircle ||
      tool == ToolType.shapeTriangle ||
      tool == ToolType.shapeDiamond ||
      tool == ToolType.shapeStar;
}

// ─── 図形スタンプの StrokePoint 生成 ─────────────────────────────────────────

/// 図形の輪郭を構成する StrokePoint リストを生成する。
/// 生成した点は消しゴムの交差判定（segmentDistance）にも使われる。
List<StrokePoint> _generateShapePoints(
  String shapeType,
  Offset center,
  double size,
) {
  switch (shapeType) {
    case 'shapeSquare':
      return _squarePoints(center, size);
    case 'shapeCircle':
      return _circlePoints(center, size / 2);
    case 'shapeTriangle':
      return _trianglePoints(center, size);
    case 'shapeDiamond':
      return _diamondPoints(center, size);
    case 'shapeStar':
      return _starPoints(center, size);
    default:
      return _squarePoints(center, size);
  }
}

/// 合成した StrokePoint を生成する（センサ値はデフォルト値）
StrokePoint _pt(Offset position) => StrokePoint(
      position: position,
      pressure: 0.5,
      pressureMin: 0.0,
      pressureMax: 1.0,
      tilt: 0.0,
      orientation: 0.0,
    );

List<StrokePoint> _squarePoints(Offset center, double size) {
  final h = size / 2;
  return [
    Offset(center.dx - h, center.dy - h), // topLeft
    Offset(center.dx + h, center.dy - h), // topRight
    Offset(center.dx + h, center.dy + h), // bottomRight
    Offset(center.dx - h, center.dy + h), // bottomLeft
    Offset(center.dx - h, center.dy - h), // 閉じる
  ].map(_pt).toList();
}

List<StrokePoint> _circlePoints(Offset center, double radius) {
  const segments = 36;
  return List.generate(segments + 1, (i) {
    final angle = 2 * math.pi * i / segments - math.pi / 2;
    return _pt(Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    ));
  });
}

List<StrokePoint> _trianglePoints(Offset center, double size) {
  final h = size / 2;
  return [
    Offset(center.dx, center.dy - h),        // top
    Offset(center.dx + h, center.dy + h),     // bottomRight
    Offset(center.dx - h, center.dy + h),     // bottomLeft
    Offset(center.dx, center.dy - h),         // 閉じる
  ].map(_pt).toList();
}

List<StrokePoint> _diamondPoints(Offset center, double size) {
  final h = size / 2;
  return [
    Offset(center.dx, center.dy - h),         // top
    Offset(center.dx + h, center.dy),         // right
    Offset(center.dx, center.dy + h),         // bottom
    Offset(center.dx - h, center.dy),         // left
    Offset(center.dx, center.dy - h),         // 閉じる
  ].map(_pt).toList();
}

List<StrokePoint> _starPoints(Offset center, double size) {
  const numPoints = 5;
  final outerRadius = size / 2;
  final innerRadius = outerRadius * 0.55;

  final offsets = List.generate(numPoints * 2 + 1, (i) {
    final index = i % (numPoints * 2);
    final angle = (math.pi * index / numPoints) - math.pi / 2;
    final r = index.isEven ? outerRadius : innerRadius;
    return Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
  });
  return offsets.map(_pt).toList();
}

// ─── Path ビルダー ────────────────────────────────────────────────────────────

/// Stroke の種別に応じて Path を生成する
///
/// - lineDashed: 破線パスを生成
/// - shape: 輪郭点を直線で結ぶポリゴンパスを生成（消しゴムの交差判定と一致させる）
/// - eraser: 空パス（描画しない）
/// - それ以外（freehand / lineSolid）: デフォルトの Catmull-Rom スプライン
Path _buildStrokePath(Stroke stroke) {
  final tool = stroke.data?['tool'] as String?;
  if (tool == 'lineDashed') {
    return _buildDashedLinePath(stroke);
  }
  if (tool == 'shape') {
    return _buildShapeOutlinePath(stroke);
  }
  if (tool == 'eraser') {
    return Path();
  }
  return generateCatmullRomPath(stroke);
}

/// 図形スタンプの輪郭パス（points を直線で結ぶ）
Path _buildShapeOutlinePath(Stroke stroke) {
  if (stroke.points.isEmpty) return Path();
  final path = Path();
  final first = stroke.points.first.position;
  path.moveTo(first.dx, first.dy);
  for (final point in stroke.points.skip(1)) {
    path.lineTo(point.position.dx, point.position.dy);
  }
  return path;
}

// ─── スタンプサイズ調整パネル ─────────────────────────────────────────────────

/// 図形スタンプツール選択時にキャンバス左下に表示するサイズ調整パネル。
/// スライダーと実物大プレビューを含む。
class _StampSizePanel extends StatelessWidget {
  const _StampSizePanel();

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    if (!_isShapeTool(appState.selectedTool)) return const SizedBox.shrink();

    final shapeType = appState.selectedTool.name;
    final stampSize = appState.stampSize;
    const previewBoxSize = 160.0;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xF02C2C2E),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 実物大プレビュー ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: previewBoxSize,
              height: previewBoxSize,
              child: ColoredBox(
                color: Colors.white,
                child: CustomPaint(
                  painter: _ShapePreviewPainter(
                    shapeType: shapeType,
                    size: stampSize,
                    color: appState.selectedColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // ── サイズ表示 ──
          Text(
            '${stampSize.round()} px',
            style: const TextStyle(
              color: Color(0xFFAEAEB2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          // ── スライダー ──
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0A84FF),
              inactiveTrackColor: const Color(0xFF48484A),
              thumbColor: const Color(0xFF0A84FF),
              overlayColor: const Color(0x290A84FF),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: stampSize,
              min: 30,
              max: 200,
              onChanged: (v) => AppStateWidget.of(context).setStampSize(v),
            ),
          ),
        ],
      ),
    );
  }
}

/// 図形の実物大プレビューを描画する CustomPainter。
/// _generateShapePoints を再利用して StrokePoint → Path を構築する。
class _ShapePreviewPainter extends CustomPainter {
  final String shapeType;
  final double size;
  final Color color;

  const _ShapePreviewPainter({
    required this.shapeType,
    required this.size,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final points = _generateShapePoints(shapeType, center, size);
    if (points.isEmpty) return;

    final path = Path();
    path.moveTo(points.first.position.dx, points.first.position.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.position.dx, p.position.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ShapePreviewPainter old) =>
      shapeType != old.shapeType || size != old.size || color != old.color;
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
