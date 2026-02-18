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

  FreeShape copyWith({
    String? id,
    Color? color,
    double? strokeWidth,
    int? layerIndex,
    FreeShapeType? type,
    Rect? bounds,
  }) {
    return FreeShape(
      id: id ?? this.id,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      layerIndex: layerIndex ?? this.layerIndex,
      type: type ?? this.type,
      bounds: bounds ?? this.bounds,
    );
  }
}
