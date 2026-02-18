import 'package:flutter/material.dart';

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

  @override
  State<AppStateWidget> createState() => _AppStateWidgetState();
}

class _AppStateWidgetState extends State<AppStateWidget> {
  ToolType _selectedTool = ToolType.freehand;
  Color _selectedColor = Colors.black;
  int _activeLayer = 0; // 0 = Layer A, 1 = Layer B

  void _setTool(ToolType tool) => setState(() => _selectedTool = tool);
  void _setColor(Color color) => setState(() => _selectedColor = color);
  void _setLayer(int layer) => setState(() => _activeLayer = layer);

  @override
  Widget build(BuildContext context) {
    return AppState(
      selectedTool: _selectedTool,
      selectedColor: _selectedColor,
      activeLayer: _activeLayer,
      onToolChanged: _setTool,
      onColorChanged: _setColor,
      onLayerChanged: _setLayer,
      child: widget.child,
    );
  }
}

/// InheritedWidget: 状態と変更コールバックをツリー下へ提供
class AppState extends InheritedWidget {
  final ToolType selectedTool;
  final Color selectedColor;
  final int activeLayer;
  final ValueChanged<ToolType> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<int> onLayerChanged;

  const AppState({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.activeLayer,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onLayerChanged,
    required super.child,
  });

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppState>()!;
  }

  @override
  bool updateShouldNotify(AppState oldWidget) =>
      selectedTool != oldWidget.selectedTool ||
      selectedColor != oldWidget.selectedColor ||
      activeLayer != oldWidget.activeLayer;
}
