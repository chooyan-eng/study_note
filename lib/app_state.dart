import 'dart:typed_data';

import 'package:draw_your_image/draw_your_image.dart';
import 'package:flutter/material.dart';

import 'history/canvas_history.dart';
import 'history/snapshot_manager.dart';
import 'models/canvas_state.dart';
import 'models/draw_object.dart';
import 'models/image_object.dart';
import 'models/snapshot.dart';

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

  // ── スナップショット状態 ────────────────────────────────────────────────────
  final _snapshotManager = SnapshotManager();
  List<Snapshot> _snapshots = const [];

  // ── UI 状態 ────────────────────────────────────────────────────────────────
  ToolType _selectedTool = ToolType.freehand;
  Color _selectedColor = Colors.black;
  int _activeLayer = 0; // 0 = Layer A, 1 = Layer B
  double _layerAOpacity = 1.0;
  double _layerBOpacity = 1.0;
  bool _showGrid = false;
  double _stampSize = 80.0; // 図形スタンプのサイズ（px）

  // ── 消しゴム状態 ────────────────────────────────────────────────────────────
  /// 1回の消しゴムストローク中に history を push したかどうか
  bool _eraserHistoryPushed = false;

  // ── 選択状態 (T11) ──────────────────────────────────────────────────────────
  Stroke? _selectedStroke;

  // ── Getters ────────────────────────────────────────────────────────────────
  CanvasState get canvasState => _canvasState;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  ToolType get selectedTool => _selectedTool;
  Color get selectedColor => _selectedColor;
  int get activeLayer => _activeLayer;
  double get layerAOpacity => _layerAOpacity;
  double get layerBOpacity => _layerBOpacity;
  bool get showGrid => _showGrid;
  double get stampSize => _stampSize;
  List<Snapshot> get snapshots => _snapshots;
  Stroke? get selectedStroke => _selectedStroke;

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

  /// 加工済み画像をアクティブレイヤーの ImageObject としてキャンバスに貼り付ける。
  void addImageObject(Uint8List bytes) {
    final obj = ImageObject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      color: Colors.transparent,
      strokeWidth: 0,
      layerIndex: _activeLayer,
      imageBytes: bytes,
    );
    setState(() {
      _history.push(_canvasState);
      _canvasState = _canvasState.copyWith(
        objects: [..._canvasState.objects, obj],
      );
    });
  }

  /// 新しい消しゴムストロークの開始時に呼び出す。
  /// history push フラグをリセットして、1ストローク = 1 Undo 単位とする。
  void resetEraserHistory() => _eraserHistoryPushed = false;

  /// Draw.onStrokesSelected から渡された交差ストロークをアクティブレイヤーから削除する。
  /// 最初の削除発生時に一度だけ history に push する（1ストローク = 1 Undo 単位）。
  void eraseStrokes(List<Stroke> strokes) {
    // すでに削除済みのストロークを除外（同一フレーム内の重複呼び出し対策）
    final toRemove =
        strokes
            .where(
              (s) =>
                  _canvasState.strokes.contains(s) &&
                  (s.data?['layer'] as int? ?? 0) == _activeLayer,
            )
            .toList();

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

  /// アクティブレイヤーの全ストローク・画像をクリアし、Undo/Redo スタックも破棄する。
  void clearCanvas() {
    setState(() {
      _history.clear();
      _selectedStroke = null;
      _canvasState = _canvasState.copyWith(
        strokes: _canvasState.strokes
            .where((s) => (s.data?['layer'] as int? ?? 0) != _activeLayer)
            .toList(),
        objects: _canvasState.objects
            .where((o) => o.layerIndex != _activeLayer)
            .toList(),
      );
    });
  }

  void undo() {
    final prev = _history.undo(_canvasState);
    if (prev != null) {
      setState(() {
        _canvasState = prev;
        _selectedStroke = null;
      });
    }
  }

  void redo() {
    final next = _history.redo(_canvasState);
    if (next != null) {
      setState(() {
        _canvasState = next;
        _selectedStroke = null;
      });
    }
  }

  // ── 選択操作 (T11) ──────────────────────────────────────────────────────────

  /// 選択中のストロークをセットする。null を渡すと選択解除。
  void selectStroke(Stroke? stroke) => setState(() => _selectedStroke = stroke);

  /// 現在の状態を Undo スタックに積む（ドラッグ開始時などに1度だけ呼ぶ）。
  void pushHistory() => _history.push(_canvasState);

  /// 選択中ストロークを [updated] で置き換える。
  /// [pushHistory] が true の場合は Undo スタックにも積む（プロパティ変更時）。
  void updateSelectedStroke(Stroke updated, {bool pushHistory = true}) {
    if (_selectedStroke == null) return;
    setState(() {
      if (pushHistory) _history.push(_canvasState);
      _canvasState = _canvasState.copyWith(
        strokes: _canvasState.strokes
            .map((s) => identical(s, _selectedStroke) ? updated : s)
            .toList(),
      );
      _selectedStroke = updated;
    });
  }

  /// 選択中ストロークを削除して選択解除する。Undo スタックに積む。
  void deleteSelectedStroke() {
    if (_selectedStroke == null) return;
    final target = _selectedStroke;
    setState(() {
      _history.push(_canvasState);
      _canvasState = _canvasState.copyWith(
        strokes:
            _canvasState.strokes.where((s) => !identical(s, target)).toList(),
      );
      _selectedStroke = null;
    });
  }

  // ── スナップショット操作 ────────────────────────────────────────────────────

  /// 現在のキャンバス状態をサムネイルとともにスナップショットとして保存する。
  void addSnapshot(Snapshot snapshot) {
    setState(() {
      _snapshotManager.add(snapshot);
      _snapshots = List.unmodifiable(_snapshotManager.snapshots);
    });
  }

  /// スナップショットを復元する（現在の状態を Undo スタックに積む）。
  void restoreSnapshot(Snapshot snapshot) {
    setState(() {
      _history.push(_canvasState);
      _canvasState = snapshot.state;
    });
  }

  // ── UI 操作 ────────────────────────────────────────────────────────────────

  void setTool(ToolType tool) => setState(() {
        _selectedTool = tool;
        if (tool != ToolType.select) _selectedStroke = null;
      });
  void setColor(Color color) => setState(() => _selectedColor = color);
  void setLayer(int layer) => setState(() => _activeLayer = layer);
  void setLayerOpacity(int layer, double opacity) => setState(() {
        if (layer == 0) _layerAOpacity = opacity;
        else _layerBOpacity = opacity;
      });
  void toggleGrid() => setState(() => _showGrid = !_showGrid);
  void setStampSize(double size) => setState(() => _stampSize = size);

  @override
  Widget build(BuildContext context) {
    return AppState(
      canvasState: _canvasState,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
      selectedTool: _selectedTool,
      selectedColor: _selectedColor,
      activeLayer: _activeLayer,
      layerAOpacity: _layerAOpacity,
      layerBOpacity: _layerBOpacity,
      showGrid: _showGrid,
      stampSize: _stampSize,
      snapshots: _snapshots,
      selectedStroke: _selectedStroke,
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
  final double layerAOpacity;
  final double layerBOpacity;
  final bool showGrid;
  final double stampSize;
  final List<Snapshot> snapshots;
  final Stroke? selectedStroke;

  const AppState({
    super.key,
    required this.canvasState,
    required this.canUndo,
    required this.canRedo,
    required this.selectedTool,
    required this.selectedColor,
    required this.activeLayer,
    required this.layerAOpacity,
    required this.layerBOpacity,
    required this.showGrid,
    required this.stampSize,
    required this.snapshots,
    required this.selectedStroke,
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
      layerAOpacity != oldWidget.layerAOpacity ||
      layerBOpacity != oldWidget.layerBOpacity ||
      showGrid != oldWidget.showGrid ||
      stampSize != oldWidget.stampSize ||
      snapshots != oldWidget.snapshots ||
      !identical(selectedStroke, oldWidget.selectedStroke);
}
