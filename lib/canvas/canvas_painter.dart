import 'package:flutter/material.dart';

import '../models/canvas_state.dart';

/// 画像など Draw ウィジェットで扱えない DrawObject を描画する CustomPainter。
/// フリーハンド・直線・図形はすべて Stroke として Draw ウィジェットが担当する。
class CanvasPainter extends CustomPainter {
  final CanvasState state;

  CanvasPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    // T16以降で ImageObject を描画する
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) => true;
}
