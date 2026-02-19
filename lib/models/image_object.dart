import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'draw_object.dart';

class ImageObject extends DrawObject {
  final Uint8List imageBytes;
  final Rect bounds;

  ImageObject({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required super.layerIndex,
    required this.imageBytes,
    required this.bounds,
  });
}
