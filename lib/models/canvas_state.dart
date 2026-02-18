import 'package:draw_your_image/draw_your_image.dart';

import 'draw_object.dart';

class CanvasState {
  /// フリーハンドストローク（draw_your_image の Draw ウィジェットが描画）
  final List<Stroke> strokes;

  /// その他オブジェクト（直線・図形・画像など。CanvasPainter が描画）
  final List<DrawObject> objects;

  const CanvasState({this.strokes = const [], this.objects = const []});

  CanvasState copyWith({List<Stroke>? strokes, List<DrawObject>? objects}) {
    return CanvasState(
      strokes: strokes ?? this.strokes,
      objects: objects ?? this.objects,
    );
  }
}
