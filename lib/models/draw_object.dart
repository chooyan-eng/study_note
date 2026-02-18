import 'package:flutter/material.dart';

abstract class DrawObject {
  final String id;
  final Color color;
  final double strokeWidth;
  final int layerIndex; // 0 = Layer A, 1 = Layer B

  DrawObject({
    required this.id,
    required this.color,
    required this.strokeWidth,
    required this.layerIndex,
  });
}
