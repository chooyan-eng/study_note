import 'package:flutter/material.dart';

import '../models/canvas_state.dart';

/// 直線・図形・画像など DrawObject を描画する CustomPainter
/// フリーハンドストロークは Draw ウィジェットが担当するため、ここでは扱わない
class CanvasPainter extends CustomPainter {
  final CanvasState state;

  CanvasPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    // T05以降で LineObject、ShapeObject、FreeShape、ImageObject を描画する
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) => true;
}
