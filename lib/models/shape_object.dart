import 'package:flutter/material.dart';

import 'draw_object.dart';

enum ShapeType { square, circle, triangle, diamond, star }

class ShapeObject extends DrawObject {
  final ShapeType type;
  final Rect bounds;
  final bool filled;

  ShapeObject({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required super.layerIndex,
    required this.type,
    required this.bounds,
    required this.filled,
  });

  ShapeObject copyWith({
    String? id,
    Color? color,
    double? strokeWidth,
    int? layerIndex,
    ShapeType? type,
    Rect? bounds,
    bool? filled,
  }) {
    return ShapeObject(
      id: id ?? this.id,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      layerIndex: layerIndex ?? this.layerIndex,
      type: type ?? this.type,
      bounds: bounds ?? this.bounds,
      filled: filled ?? this.filled,
    );
  }
}
