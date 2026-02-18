import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'draw_object.dart';

class ImageObject extends DrawObject {
  final ui.Image image;
  final Rect bounds;

  ImageObject({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required super.layerIndex,
    required this.image,
    required this.bounds,
  });
}
