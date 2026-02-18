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
}
