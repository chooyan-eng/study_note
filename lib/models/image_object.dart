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

  ImageObject copyWith({
    String? id,
    Color? color,
    double? strokeWidth,
    int? layerIndex,
    ui.Image? image,
    Rect? bounds,
  }) {
    return ImageObject(
      id: id ?? this.id,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      layerIndex: layerIndex ?? this.layerIndex,
      image: image ?? this.image,
      bounds: bounds ?? this.bounds,
    );
  }
}
