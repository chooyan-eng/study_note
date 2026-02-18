import 'dart:ui' as ui;

import 'canvas_state.dart';

class Snapshot {
  final CanvasState state;
  final ui.Image thumbnail;
  final DateTime createdAt;

  const Snapshot({
    required this.state,
    required this.thumbnail,
    required this.createdAt,
  });
}
