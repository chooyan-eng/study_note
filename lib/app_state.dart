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

  // ── Getters ────────────────────────────────────────────────────────────────
  CanvasState get canvasState => _canvasState;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  ToolType get selectedTool => _selectedTool;
  Color get selectedColor => _selectedColor;
  int get activeLayer => _activeLayer;

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

  @override
  Widget build(BuildContext context) {
    return AppState(
      canvasState: _canvasState,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
      selectedTool: _selectedTool,
      selectedColor: _selectedColor,
      activeLayer: _activeLayer,
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

  const AppState({
    super.key,
    required this.canvasState,
    required this.canUndo,
    required this.canRedo,
    required this.selectedTool,
    required this.selectedColor,
    required this.activeLayer,
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
      activeLayer != oldWidget.activeLayer;
}
