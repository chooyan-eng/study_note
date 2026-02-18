import 'package:flutter/material.dart';

import 'draw_object.dart';

class LineObject extends DrawObject {
  final Offset start;
  final Offset end;
  final bool dashed;

  LineObject({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required super.layerIndex,
    required this.start,
    required this.end,
    required this.dashed,
  });

  LineObject copyWith({
    String? id,
    Color? color,
    double? strokeWidth,
    int? layerIndex,
    Offset? start,
    Offset? end,
    bool? dashed,
  }) {
    return LineObject(
      id: id ?? this.id,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      layerIndex: layerIndex ?? this.layerIndex,
      start: start ?? this.start,
      end: end ?? this.end,
      dashed: dashed ?? this.dashed,
    );
  }
}
