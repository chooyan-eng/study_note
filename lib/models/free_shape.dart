import 'package:flutter/material.dart';

import 'draw_object.dart';

enum FreeShapeType { rect, oval }

class FreeShape extends DrawObject {
  final FreeShapeType type;
  final Rect bounds;

  FreeShape({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required super.layerIndex,
    required this.type,
    required this.bounds,
  });
}
