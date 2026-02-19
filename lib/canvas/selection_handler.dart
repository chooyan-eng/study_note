import 'dart:math' as math;

import 'package:draw_your_image/draw_your_image.dart';
import 'package:flutter/material.dart';

/// オブジェクト選択のヒットテストとバウンディング計算を担うユーティリティクラス。
class StrokeSelectionHandler {
  static const double hitThreshold = 20.0;

  /// [strokes] 中でアクティブレイヤーの [pos] に最も近い（前面の）Stroke を返す。
  /// 見つからなければ null を返す。
  static Stroke? findStrokeAt(
    Offset pos,
    List<Stroke> strokes,
    int activeLayer,
  ) {
    for (final s in strokes.reversed) {
      if ((s.data?['layer'] as int? ?? 0) != activeLayer) continue;
      if (hitTest(pos, s)) return s;
    }
    return null;
  }

  /// [stroke] が [pos] に重なっているかどうかをテストする。
  static bool hitTest(Offset pos, Stroke stroke) {
    final tool = stroke.data?['tool'] as String?;
    switch (tool) {
      case 'freehand':
        return _hitTestFreehand(pos, stroke);
      case 'lineSolid':
      case 'lineDashed':
        return _hitTestLine(pos, stroke);
      case 'shape':
      case 'freeRect':
        return _hitTestBounds(pos, stroke);
      case 'freeOval':
        return _hitTestOval(pos, stroke);
      default:
        return false;
    }
  }

  /// フリーハンド: 各点との距離判定
  static bool _hitTestFreehand(Offset pos, Stroke stroke) {
    for (final p in stroke.points) {
      if ((p.position - pos).distance <= hitThreshold) return true;
    }
    return false;
  }

  /// 直線: 線分との距離判定
  static bool _hitTestLine(Offset pos, Stroke stroke) {
    if (stroke.points.length < 2) return false;
    final a = stroke.points.first.position;
    final b = stroke.points.last.position;
    return _distanceToSegment(pos, a, b) <= hitThreshold;
  }

  /// 図形スタンプ / freeRect: バウンディング Rect の内部判定
  static bool _hitTestBounds(Offset pos, Stroke stroke) {
    return getBounds(stroke).inflate(hitThreshold).contains(pos);
  }

  /// freeOval: 円の内外判定
  static bool _hitTestOval(Offset pos, Stroke stroke) {
    final cx = stroke.data?['cx'] as double?;
    final cy = stroke.data?['cy'] as double?;
    final r = stroke.data?['radius'] as double?;
    if (cx == null || cy == null || r == null) {
      return _hitTestBounds(pos, stroke);
    }
    return (pos - Offset(cx, cy)).distance <= r + hitThreshold;
  }

  /// [stroke] の全点を包むバウンディング Rect を返す。
  static Rect getBounds(Stroke stroke) {
    if (stroke.points.isEmpty) return Rect.zero;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in stroke.points) {
      minX = math.min(minX, p.position.dx);
      minY = math.min(minY, p.position.dy);
      maxX = math.max(maxX, p.position.dx);
      maxY = math.max(maxY, p.position.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// 点 [p] から線分 [a]-[b] までの最短距離
  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    final clamped = math.max(0.0, math.min(1.0, t));
    final closest = a + Offset(ab.dx * clamped, ab.dy * clamped);
    return (p - closest).distance;
  }
}
