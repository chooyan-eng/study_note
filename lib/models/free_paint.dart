import 'package:flutter/material.dart';

import 'draw_object.dart';

class FreePaint extends DrawObject {
  final List<Offset> points;

  FreePaint({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required super.layerIndex,
    required this.points,
  });

  FreePaint copyWith({
    String? id,
    Color? color,
    double? strokeWidth,
    int? layerIndex,
    List<Offset>? points,
  }) {
    return FreePaint(
      id: id ?? this.id,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      layerIndex: layerIndex ?? this.layerIndex,
      points: points ?? this.points,
    );
  }
}
