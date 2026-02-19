import 'dart:math' as math;

import 'package:draw_your_image/draw_your_image.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_state.dart';
import '../canvas/selection_handler.dart';
import '../models/snapshot.dart';
import '../ui/snapshot_panel.dart';
import '../ui/toolbar.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  Future<void> _saveSnapshot() async {
    final ro = _repaintKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return;

    // pixelRatio を下げてサムネイル化（0.3 ≒ 30%）
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final image = await ro.toImage(pixelRatio: devicePixelRatio * 0.3);

    if (!mounted) return;
    final state = AppState.of(context).canvasState;
    AppStateWidget.of(context).addSnapshot(
      Snapshot(state: state, thumbnail: image, createdAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // 左サイドツールバー
          const Toolbar(),
          // キャンバス領域
          Expanded(
            child: Stack(
              children: [
                RepaintBoundary(key: _repaintKey, child: const _CanvasArea()),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _ControlsPanel(onSaveSnapshot: _saveSnapshot),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: const _StampSizePanel(),
                ),
                // スナップショット一覧パネル（上部中央）
                const Positioned(
                  top: 12,
                  left: 12,
                  right: 68,
                  child: Center(child: SnapshotPanel()),
                ),
                // 選択オブジェクトのプロパティパネル（右下）
                const Positioned(
                  bottom: 12,
                  right: 12,
                  child: _SelectionPropertyPanel(),
                ),
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

    final layerAStrokes = appState.canvasState.strokes
        .where((s) => (s.data?['layer'] as int? ?? 0) == 0)
        .toList();
    final layerBStrokes = appState.canvasState.strokes
        .where((s) => (s.data?['layer'] as int? ?? 0) == 1)
        .toList();

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

        // Layer A（下層）
        _buildLayerDraw(
          context: context,
          appState: appState,
          layerIndex: 0,
          layerStrokes: layerAStrokes,
          opacity: appState.layerAOpacity,
        ),

        // Layer B（上層）
        _buildLayerDraw(
          context: context,
          appState: appState,
          layerIndex: 1,
          layerStrokes: layerBStrokes,
          opacity: appState.layerBOpacity,
        ),

        // 選択オーバーレイ（選択ツール時のみ）
        if (appState.selectedTool == ToolType.select)
          Positioned.fill(child: _SelectionOverlay(appState: appState)),
      ],
    );
  }

  /// 指定レイヤー用の Draw ウィジェットを生成する。
  /// アクティブレイヤーのみ入力を受け付け、非アクティブは IgnorePointer で遮断する。
  Widget _buildLayerDraw({
    required BuildContext context,
    required AppState appState,
    required int layerIndex,
    required List<Stroke> layerStrokes,
    required double opacity,
  }) {
    final isEraser = appState.selectedTool == ToolType.eraser;
    final isActive = appState.activeLayer == layerIndex;
    // 選択ツール時は _SelectionOverlay がイベントを担当するため Draw は無効化する。
    final isSelectTool = appState.selectedTool == ToolType.select;

    // 非アクティブレイヤーは IgnorePointer でポインタイベントを完全遮断するため、
    // コールバックに isActive 判定は不要。
    return IgnorePointer(
      ignoring: !isActive || isSelectTool,
      child: Opacity(
        opacity: opacity,
        child: Draw(
          strokes: layerStrokes,
          backgroundColor: Colors.transparent,
          pathBuilder: _buildStrokePath,
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
                data: {'tool': 'freehand', 'layer': layerIndex},
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
                  'layer': layerIndex,
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
            if (_isShapeTool(tool)) {
              return newStroke.copyWith(
                color: appState.selectedColor,
                width: 2.5,
                data: {
                  'tool': 'shape',
                  'shapeType': tool.name,
                  'layer': layerIndex,
                },
              );
            }
            if (tool == ToolType.freeRect || tool == ToolType.freeOval) {
              return newStroke.copyWith(
                color: appState.selectedColor,
                width: 3.0,
                data: {
                  'tool': tool == ToolType.freeRect ? 'freeRect' : 'freeOval',
                  'layer': layerIndex,
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
            if (tool == 'freeRect') {
              if (stroke.points.length < 2) return stroke;
              final start = stroke.points.first.position;
              final end = stroke.points.last.position;
              return stroke.copyWith(
                points: [
                  start,
                  Offset(end.dx, start.dy),
                  end,
                  Offset(start.dx, end.dy),
                  start, // 閉じる
                ].map(_pt).toList(),
              );
            }
            if (tool == 'freeOval') {
              if (stroke.points.length < 2) return stroke;
              // points には生のポインタ入力を保持し続ける。
              // first = ドラッグ開始点（中心）、last = 現在位置（半径の基準）
              // pathBuilder が data の cx/cy/radius を使って addOval で描画する。
              final center = stroke.points.first.position;
              final radius =
                  (stroke.points.last.position - center).distance;
              final data = Map<String, dynamic>.from(stroke.data ?? {});
              data['cx'] = center.dx;
              data['cy'] = center.dy;
              data['radius'] = radius;
              return stroke.copyWith(data: data);
            }
            return stroke;
          },
          onStrokeDrawn: (stroke) {
            if (stroke.data?['tool'] == 'eraser') return;

            if (stroke.data?['tool'] == 'shape') {
              final center = stroke.points.isNotEmpty
                  ? stroke.points.first.position
                  : const Offset(200, 200);
              final stampSize = appState.stampSize;
              final shapeTypeStr =
                  stroke.data?['shapeType'] as String? ?? 'shapeSquare';
              final shapePoints = _generateShapePoints(
                shapeTypeStr,
                center,
                stampSize,
              );
              // サイズを data に保存して、選択後のリサイズに使用できるようにする
              final newData = Map<String, dynamic>.from(stroke.data!);
              newData['size'] = stampSize;
              AppStateWidget.of(context).onStrokeDrawn(
                stroke.copyWith(points: shapePoints, data: newData),
              );
              return;
            }

            if (stroke.data?['tool'] == 'freeOval') {
              // 消しゴムの交差判定（segmentDistance）のために
              // points を円の輪郭点列に差し替えて保存する。
              // pathBuilder は引き続き data の cx/cy/radius で addOval を描画する。
              final cx = stroke.data?['cx'] as double?;
              final cy = stroke.data?['cy'] as double?;
              final radius = stroke.data?['radius'] as double?;
              if (cx != null && cy != null && radius != null && radius > 0) {
                final circlePoints = _circlePoints(Offset(cx, cy), radius);
                AppStateWidget.of(context)
                    .onStrokeDrawn(stroke.copyWith(points: circlePoints));
              }
              return;
            }

            AppStateWidget.of(context).onStrokeDrawn(stroke);
          },
        ),
      ),
    );
  }
}

/// 右上コントロール領域: 方眼トグル・Undo/Redo・スナップショット保存・クリア・レイヤー切り替えをまとめたパネル
class _ControlsPanel extends StatelessWidget {
  final VoidCallback? onSaveSnapshot;
  const _ControlsPanel({this.onSaveSnapshot});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final actions = AppStateWidget.of(context);

    return Container(
      width: 88,
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
            icon: Icons.camera_alt,
            tooltip: 'スナップショット保存',
            onTap: onSaveSnapshot,
          ),
          const _ControlDivider(),
          _ControlButton(
            icon: Icons.delete_sweep,
            tooltip: 'クリア',
            onTap: actions.clearCanvas,
          ),
          const _ControlDivider(),
          _LayerPanelSection(state: state, actions: actions),
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

// ─── レイヤーパネル ───────────────────────────────────────────────────────────

/// _ControlsPanel 内のレイヤー切り替え + 不透明度セクション
class _LayerPanelSection extends StatelessWidget {
  final AppState state;
  final AppStateWidgetState actions;

  const _LayerPanelSection({required this.state, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LayerRow(
            label: 'A',
            isActive: state.activeLayer == 0,
            opacity: state.layerAOpacity,
            onTap: () => actions.setLayer(0),
            onOpacityChanged: (v) => actions.setLayerOpacity(0, v),
          ),
          const SizedBox(height: 6),
          _LayerRow(
            label: 'B',
            isActive: state.activeLayer == 1,
            opacity: state.layerBOpacity,
            onTap: () => actions.setLayer(1),
            onOpacityChanged: (v) => actions.setLayerOpacity(1, v),
          ),
        ],
      ),
    );
  }
}

/// レイヤー名バッジ・不透明度表示・スライダーをまとめた1行分のウィジェット
class _LayerRow extends StatelessWidget {
  final String label;
  final bool isActive;
  final double opacity;
  final VoidCallback onTap;
  final ValueChanged<double> onOpacityChanged;

  const _LayerRow({
    required this.label,
    required this.isActive,
    required this.opacity,
    required this.onTap,
    required this.onOpacityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF0A84FF)
                      : const Color(0xFF3A3A3C),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFFAEAEB2),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(opacity * 100).round()}%',
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 9),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF0A84FF),
            inactiveTrackColor: const Color(0xFF48484A),
            thumbColor: const Color(0xFF0A84FF),
            overlayColor: const Color(0x290A84FF),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: SizedBox(
            height: 24,
            child: Slider(
              value: opacity,
              min: 0.0,
              max: 1.0,
              onChanged: onOpacityChanged,
            ),
          ),
        ),
      ],
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
    return _pt(
      Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      ),
    );
  });
}

List<StrokePoint> _trianglePoints(Offset center, double size) {
  final h = size / 2;
  return [
    Offset(center.dx, center.dy - h), // top
    Offset(center.dx + h, center.dy + h), // bottomRight
    Offset(center.dx - h, center.dy + h), // bottomLeft
    Offset(center.dx, center.dy - h), // 閉じる
  ].map(_pt).toList();
}

List<StrokePoint> _diamondPoints(Offset center, double size) {
  final h = size / 2;
  return [
    Offset(center.dx, center.dy - h), // top
    Offset(center.dx + h, center.dy), // right
    Offset(center.dx, center.dy + h), // bottom
    Offset(center.dx - h, center.dy), // left
    Offset(center.dx, center.dy - h), // 閉じる
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
  if (tool == 'freeRect') {
    return _buildShapeOutlinePath(stroke);
  }
  if (tool == 'freeOval') {
    return _buildFreeOvalPath(stroke);
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

/// freeOval の円パス（data に保存した cx/cy/radius から addOval で滑らかな円を描く）
Path _buildFreeOvalPath(Stroke stroke) {
  final data = stroke.data;
  final cx = data?['cx'] as double?;
  final cy = data?['cy'] as double?;
  final radius = data?['radius'] as double?;
  if (cx == null || cy == null || radius == null || radius == 0) {
    return _buildShapeOutlinePath(stroke);
  }
  final path = Path();
  path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
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
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
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

// ─── 選択オーバーレイ (T11) ───────────────────────────────────────────────────

/// リサイズハンドルの半径（px）
const double _handleRadius = 8.0;

/// ハンドルへのヒット判定距離（px）
const double _handleHitRadius = 16.0;

/// 選択中ストロークの種別に応じたハンドル位置リストを返す。
/// 直線: [start, end], freeRect: [TL, TR, BR, BL], freeOval: [右端]
/// フリーハンド・スタンプ: [] （ハンドルなし）
List<Offset> _getSelectionHandles(Stroke stroke) {
  final tool = stroke.data?['tool'] as String?;
  switch (tool) {
    case 'lineSolid':
    case 'lineDashed':
      if (stroke.points.length >= 2) {
        return [
          stroke.points.first.position,
          stroke.points.last.position,
        ];
      }
      return [];
    case 'freeRect':
      if (stroke.points.length >= 4) {
        return [
          stroke.points[0].position, // TL
          stroke.points[1].position, // TR
          stroke.points[2].position, // BR
          stroke.points[3].position, // BL
        ];
      }
      return [];
    case 'freeOval':
      final cx = stroke.data?['cx'] as double? ?? 0;
      final cy = stroke.data?['cy'] as double? ?? 0;
      final r = stroke.data?['radius'] as double? ?? 0;
      return [Offset(cx + r, cy)]; // 右端に1ハンドル
    default:
      return []; // freehand / shape: ハンドルなし
  }
}

/// 選択ツール時のオーバーレイ: タップ選択・ドラッグ移動・ハンドルリサイズを処理する。
class _SelectionOverlay extends StatefulWidget {
  final AppState appState;
  const _SelectionOverlay({required this.appState});

  @override
  State<_SelectionOverlay> createState() => _SelectionOverlayState();
}

class _SelectionOverlayState extends State<_SelectionOverlay> {
  /// ドラッグ中のハンドルインデックス（-1=ハンドルなし, -2=ボディ移動）
  int _activeHandle = -1;
  Offset? _lastPan;
  bool _historyPushedForDrag = false;

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final selected = appState.selectedStroke;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final pos = details.localPosition;
        final found = SelectionHandler.findStrokeAt(
          pos,
          appState.canvasState.strokes,
          appState.activeLayer,
        );
        AppStateWidget.of(context).selectStroke(found);
      },
      onPanStart: (details) {
        final pos = details.localPosition;
        _lastPan = pos;
        _historyPushedForDrag = false;

        if (selected == null) {
          _activeHandle = -1;
          return;
        }

        // ハンドルに近いか確認
        final handles = _getSelectionHandles(selected);
        for (int i = 0; i < handles.length; i++) {
          if ((handles[i] - pos).distance <= _handleHitRadius) {
            _activeHandle = i;
            return;
          }
        }

        // ボディ上か確認
        if (SelectionHandler.hitTest(pos, selected)) {
          _activeHandle = -2; // ボディ移動
        } else {
          _activeHandle = -1;
        }
      },
      onPanUpdate: (details) {
        final selected = widget.appState.selectedStroke;
        if (selected == null || _lastPan == null) return;
        if (_activeHandle == -1) return;

        final pos = details.localPosition;
        final delta = pos - _lastPan!;
        _lastPan = pos;

        // 初回ドラッグ時に履歴を1度だけ積む
        if (!_historyPushedForDrag) {
          AppStateWidget.of(context).pushHistory();
          _historyPushedForDrag = true;
        }

        if (_activeHandle == -2) {
          _moveStroke(context, selected, delta);
        } else {
          _resizeByHandle(context, selected, _activeHandle, pos);
        }
      },
      onPanEnd: (_) {
        _activeHandle = -1;
        _lastPan = null;
        _historyPushedForDrag = false;
      },
      child: CustomPaint(
        painter: _SelectionPainter(selected: selected),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _moveStroke(BuildContext context, Stroke stroke, Offset delta) {
    final tool = stroke.data?['tool'] as String?;

    final newPoints =
        stroke.points.map((p) => _pt(p.position + delta)).toList();

    Map<String, dynamic>? newData;
    if (tool == 'freeOval') {
      final cx = (stroke.data?['cx'] as double? ?? 0) + delta.dx;
      final cy = (stroke.data?['cy'] as double? ?? 0) + delta.dy;
      newData = Map<String, dynamic>.from(stroke.data!);
      newData['cx'] = cx;
      newData['cy'] = cy;
    }

    final updated = newData != null
        ? stroke.copyWith(points: newPoints, data: newData)
        : stroke.copyWith(points: newPoints);

    AppStateWidget.of(context).updateSelectedStroke(updated, pushHistory: false);
  }

  void _resizeByHandle(
    BuildContext context,
    Stroke stroke,
    int handleIndex,
    Offset newPos,
  ) {
    final tool = stroke.data?['tool'] as String?;
    Stroke updated;

    if (tool == 'lineSolid' || tool == 'lineDashed') {
      final pts = stroke.points;
      if (pts.length < 2) return;
      if (handleIndex == 0) {
        updated = stroke.copyWith(points: [_pt(newPos), pts.last]);
      } else {
        updated = stroke.copyWith(points: [pts.first, _pt(newPos)]);
      }
    } else if (tool == 'freeRect') {
      final pts = stroke.points;
      if (pts.length < 4) return;
      Offset tl = pts[0].position;
      Offset tr = pts[1].position;
      Offset br = pts[2].position;
      Offset bl = pts[3].position;

      switch (handleIndex) {
        case 0: // TL
          tl = newPos;
          tr = Offset(tr.dx, newPos.dy);
          bl = Offset(newPos.dx, bl.dy);
        case 1: // TR
          tr = newPos;
          tl = Offset(tl.dx, newPos.dy);
          br = Offset(newPos.dx, br.dy);
        case 2: // BR
          br = newPos;
          tr = Offset(newPos.dx, tr.dy);
          bl = Offset(bl.dx, newPos.dy);
        case 3: // BL
          bl = newPos;
          tl = Offset(newPos.dx, tl.dy);
          br = Offset(br.dx, newPos.dy);
      }
      updated = stroke.copyWith(
        points: [tl, tr, br, bl, tl].map(_pt).toList(),
      );
    } else if (tool == 'freeOval') {
      final cx = stroke.data?['cx'] as double? ?? 0;
      final cy = stroke.data?['cy'] as double? ?? 0;
      final center = Offset(cx, cy);
      final newRadius = math.max(4.0, (newPos - center).distance);
      final circlePoints = _circlePoints(center, newRadius);
      final newData = Map<String, dynamic>.from(stroke.data!);
      newData['radius'] = newRadius;
      updated = stroke.copyWith(points: circlePoints, data: newData);
    } else {
      return;
    }

    AppStateWidget.of(context).updateSelectedStroke(updated, pushHistory: false);
  }
}

/// 選択中ストロークのバウンディングボックスとハンドルを描画する CustomPainter。
class _SelectionPainter extends CustomPainter {
  final Stroke? selected;

  const _SelectionPainter({required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    if (selected == null) return;

    final bounds = SelectionHandler.getBounds(selected!).inflate(8);

    // バウンディングボックス（青い枠線）
    final boxPaint = Paint()
      ..color = const Color(0xFF0A84FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds, boxPaint);

    // ハンドル
    final handles = _getSelectionHandles(selected!);
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF0A84FF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final h in handles) {
      canvas.drawCircle(h, _handleRadius, fillPaint);
      canvas.drawCircle(h, _handleRadius, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      !identical(selected, old.selected);
}

// ─── 選択プロパティパネル (T11) ───────────────────────────────────────────────

/// 選択中ストロークがある場合に右下に表示するプロパティ編集パネル。
/// 色変更・直線種別切替・スタンプサイズ調整・削除ボタンを含む。
class _SelectionPropertyPanel extends StatelessWidget {
  const _SelectionPropertyPanel();

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final selected = appState.selectedStroke;
    if (selected == null || appState.selectedTool != ToolType.select) {
      return const SizedBox.shrink();
    }

    final tool = selected.data?['tool'] as String?;
    final isLine = tool == 'lineSolid' || tool == 'lineDashed';
    final isStamp = tool == 'shape';

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xF02C2C2E),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 色パレット ──
          const Text(
            '色',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 10),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: kPaletteColors.map((color) {
              final isSelected = selected.color == color;
              return GestureDetector(
                onTap: () {
                  final updated = selected.copyWith(color: color);
                  AppStateWidget.of(context).updateSelectedStroke(updated);
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withAlpha(128),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),

          // ── 直線種別切替（直線ツールのみ）──
          if (isLine) ...[
            const SizedBox(height: 10),
            const Text(
              '線種',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 10),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _LineTypeButton(
                  label: '実線',
                  isSelected: tool == 'lineSolid',
                  onTap: () {
                    final newData =
                        Map<String, dynamic>.from(selected.data!);
                    newData['tool'] = 'lineSolid';
                    AppStateWidget.of(context).updateSelectedStroke(
                      selected.copyWith(data: newData),
                    );
                  },
                ),
                const SizedBox(width: 6),
                _LineTypeButton(
                  label: '破線',
                  isSelected: tool == 'lineDashed',
                  onTap: () {
                    final newData =
                        Map<String, dynamic>.from(selected.data!);
                    newData['tool'] = 'lineDashed';
                    AppStateWidget.of(context).updateSelectedStroke(
                      selected.copyWith(data: newData),
                    );
                  },
                ),
              ],
            ),
          ],

          // ── スタンプサイズスライダー（スタンプのみ）──
          if (isStamp) ...[
            const SizedBox(height: 10),
            const Text(
              'サイズ',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              '${_currentStampSize(selected).round()} px',
              style: const TextStyle(
                color: Color(0xFFAEAEB2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF0A84FF),
                inactiveTrackColor: const Color(0xFF48484A),
                thumbColor: const Color(0xFF0A84FF),
                overlayColor: const Color(0x290A84FF),
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: SizedBox(
                height: 28,
                child: Slider(
                  value: _currentStampSize(selected).clamp(30.0, 200.0),
                  min: 30,
                  max: 200,
                  onChanged: (newSize) {
                    _resizeStamp(context, selected, newSize);
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── 削除ボタン ──
          GestureDetector(
            onTap: () => AppStateWidget.of(context).deleteSelectedStroke(),
            child: Container(
              width: double.infinity,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF3B30),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Text(
                  '削除',
                  style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _currentStampSize(Stroke stroke) {
    final sizeInData = stroke.data?['size'] as double?;
    if (sizeInData != null) return sizeInData;
    // data に size がない場合はバウンディング幅から推算
    final bounds = SelectionHandler.getBounds(stroke);
    return math.max(bounds.width, bounds.height).clamp(30.0, 200.0);
  }

  void _resizeStamp(BuildContext context, Stroke stroke, double newSize) {
    final shapeType =
        stroke.data?['shapeType'] as String? ?? 'shapeSquare';
    final bounds = SelectionHandler.getBounds(stroke);
    final center = bounds.center;
    final newPoints = _generateShapePoints(shapeType, center, newSize);
    final newData = Map<String, dynamic>.from(stroke.data!);
    newData['size'] = newSize;
    AppStateWidget.of(context).updateSelectedStroke(
      stroke.copyWith(points: newPoints, data: newData),
      pushHistory: false,
    );
  }
}

/// 直線種別切替ボタン（実線 / 破線）
class _LineTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LineTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0A84FF)
              : const Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFAEAEB2),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
