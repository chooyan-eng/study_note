import 'dart:math' as math;

import 'package:draw_your_image/draw_your_image.dart';
import 'package:flutter/material.dart';

import 'history/canvas_history.dart';
import 'models/canvas_state.dart';
import 'models/draw_object.dart';

/// 描画ツールの種類
enum ToolType {
  freehand, // フリーハンド
  lineSolid, // 直線（実線）
  lineDashed, // 直線（破線）
  eraser, // 消しゴム
  select, // 選択
  shapeSquare, // 正方形スタンプ (T09)
  shapeCircle, // 円形スタンプ (T09)
  shapeTriangle, // 三角形スタンプ (T09)
  shapeDiamond, // 菱形スタンプ (T09)
  shapeStar, // 星形スタンプ (T09)
  freeRect, // 任意サイズ四角形 (T10)
  freeOval, // 任意サイズ楕円 (T10)
}

/// 固定6色パレット
const List<Color> kPaletteColors = [
  Colors.black,
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
];

/// アプリ全体の状態を保持する StatefulWidget
class AppStateWidget extends StatefulWidget {
  final Widget child;
  const AppStateWidget({super.key, required this.child});

  /// findAncestorStateOfType で AppStateWidgetState に直接アクセスする（ミューテーション用）
  static AppStateWidgetState of(BuildContext context) {
    return context.findAncestorStateOfType<AppStateWidgetState>()!;
  }

  @override
  State<AppStateWidget> createState() => AppStateWidgetState();
}

class AppStateWidgetState extends State<AppStateWidget> {
  // ── キャンバス状態 ──────────────────────────────────────────────────────────
  CanvasState _canvasState = const CanvasState();
  final _history = CanvasHistory();

  // ── UI 状態 ────────────────────────────────────────────────────────────────
  ToolType _selectedTool = ToolType.freehand;
  Color _selectedColor = Colors.black;
  int _activeLayer = 0; // 0 = Layer A, 1 = Layer B
  bool _showGrid = false;

  // ── 消しゴム状態 ────────────────────────────────────────────────────────────
  /// 1回の消しゴムストローク中に history を push したかどうか
  bool _eraserHistoryPushed = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  CanvasState get canvasState => _canvasState;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  ToolType get selectedTool => _selectedTool;
  Color get selectedColor => _selectedColor;
  int get activeLayer => _activeLayer;
  bool get showGrid => _showGrid;

  // ── キャンバス操作 ──────────────────────────────────────────────────────────

  void onStrokeDrawn(Stroke stroke) {
    if (stroke.points.isEmpty) return;
    setState(() {
      _history.push(_canvasState);
      _canvasState = _canvasState.copyWith(
        strokes: [..._canvasState.strokes, stroke],
      );
    });
  }

  void addObject(DrawObject object) {
    setState(() {
      _history.push(_canvasState);
      _canvasState = _canvasState.copyWith(
        objects: [..._canvasState.objects, object],
      );
    });
  }

  /// 消しゴムの1点分のヒットテストを実行し、当たったストロークをアクティブレイヤーから削除する。
  /// [isFirstPoint] が true のときは新しい消しゴムストロークの開始点なので、
  /// 最初の削除が発生したタイミングで history に push する（1ストローク = 1 Undo 単位）。
  void eraseAtPoint(
    Offset point, {
    required bool isFirstPoint,
    double eraserRadius = 20.0,
  }) {
    if (isFirstPoint) _eraserHistoryPushed = false;

    final toRemove = _canvasState.strokes.where((stroke) {
      final strokeLayer = stroke.data?['layer'] as int? ?? 0;
      if (strokeLayer != _activeLayer) return false;
      return _strokeHitTest(stroke, point, eraserRadius);
    }).toList();

    if (toRemove.isEmpty) return;

    setState(() {
      if (!_eraserHistoryPushed) {
        _history.push(_canvasState);
        _eraserHistoryPushed = true;
      }
      final removeSet = toRemove.toSet();
      _canvasState = _canvasState.copyWith(
        strokes:
            _canvasState.strokes.where((s) => !removeSet.contains(s)).toList(),
      );
    });
  }

  void undo() {
    final prev = _history.undo(_canvasState);
    if (prev != null) setState(() => _canvasState = prev);
  }

  void redo() {
    final next = _history.redo(_canvasState);
    if (next != null) setState(() => _canvasState = next);
  }

  // ── UI 操作 ────────────────────────────────────────────────────────────────

  void setTool(ToolType tool) => setState(() => _selectedTool = tool);
  void setColor(Color color) => setState(() => _selectedColor = color);
  void setLayer(int layer) => setState(() => _activeLayer = layer);
  void toggleGrid() => setState(() => _showGrid = !_showGrid);

  @override
  Widget build(BuildContext context) {
    return AppState(
      canvasState: _canvasState,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
      selectedTool: _selectedTool,
      selectedColor: _selectedColor,
      activeLayer: _activeLayer,
      showGrid: _showGrid,
      child: widget.child,
    );
  }
}

/// InheritedWidget: 状態の読み取りとリビルド登録に使用
/// ミューテーションは AppStateWidget.of(context) 経由で行う
class AppState extends InheritedWidget {
  final CanvasState canvasState;
  final bool canUndo;
  final bool canRedo;
  final ToolType selectedTool;
  final Color selectedColor;
  final int activeLayer;
  final bool showGrid;

  const AppState({
    super.key,
    required this.canvasState,
    required this.canUndo,
    required this.canRedo,
    required this.selectedTool,
    required this.selectedColor,
    required this.activeLayer,
    required this.showGrid,
    required super.child,
  });

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppState>()!;
  }

  @override
  bool updateShouldNotify(AppState oldWidget) =>
      canvasState != oldWidget.canvasState ||
      canUndo != oldWidget.canUndo ||
      canRedo != oldWidget.canRedo ||
      selectedTool != oldWidget.selectedTool ||
      selectedColor != oldWidget.selectedColor ||
      activeLayer != oldWidget.activeLayer ||
      showGrid != oldWidget.showGrid;
}

// ── 消しゴム ヒットテスト ─────────────────────────────────────────────────────

/// ストローク [stroke] が消しゴム点 [point]（半径 [radius]）に当たるかを判定する。
bool _strokeHitTest(Stroke stroke, Offset point, double radius) {
  final tool = stroke.data?['tool'] as String?;
  if (tool == 'freehand') {
    return stroke.points.any((p) => (p.position - point).distance <= radius);
  } else if (tool == 'lineSolid' || tool == 'lineDashed') {
    if (stroke.points.length < 2) return false;
    final start = stroke.points.first.position;
    final end = stroke.points.last.position;
    return _distanceToSegment(point, start, end) <= radius;
  }
  return false;
}

/// 点 [p] から線分 [a]→[b] への最短距離を返す。
double _distanceToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lengthSq = dx * dx + dy * dy;
  if (lengthSq == 0) return (p - a).distance;
  final t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSq;
  final tClamped = math.max(0.0, math.min(1.0, t));
  final nearest = Offset(a.dx + tClamped * dx, a.dy + tClamped * dy);
  return (p - nearest).distance;
}
