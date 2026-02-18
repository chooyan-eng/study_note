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
}
