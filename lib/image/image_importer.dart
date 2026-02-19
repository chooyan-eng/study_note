import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// カメラ撮影・画像加工パイプラインの起点となるクラス。
///
/// T13: MethodChannel 経由で iOS カメラを起動し、撮影した画像を Uint8List で返す。
/// T14: crop_your_image による切り抜き
/// T15: image パッケージによる加工パイプライン（Isolate 上で実行）
class ImageImporter {
  static const _channel = MethodChannel('study_note/photo_picker');

  /// カメラを起動して撮影した画像の PNG バイト列を返す。
  /// キャンセルされた場合は null を返す。
  /// カメラが使用できない場合や撮影に失敗した場合は例外をスローする。
  static Future<Uint8List?> pickPhoto() async {
    final data = await _channel.invokeMethod<Uint8List>('pickPhoto');
    return data;
  }

  /// 切り抜き後の画像バイト列を加工パイプラインで処理して返す。
  ///
  /// Isolate 上で実行するため UI スレッドをブロックしない。
  /// 処理順序: ① ホワイトバランス → ② コントラスト強調 → ③ 彩度強調 → ④ アンシャープマスク
  static Future<Uint8List> processImage(Uint8List bytes) {
    return compute(_processImagePipeline, bytes);
  }
}

// ─── Isolate 上で実行するパイプライン（トップレベル関数） ────────────────────

/// 加工パイプライン本体。compute() から呼び出されるトップレベル関数。
Uint8List _processImagePipeline(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null) return bytes;

  // ① ホワイトバランス補正
  var image = _applyWhiteBalance(src);

  // ② コントラスト強調
  image = img.adjustColor(image, contrast: 1.3);

  // ③ 彩度強調
  image = _boostSaturation(image, 1.4);

  // ④ アンシャープマスク
  image = _applyUnsharpMask(image, radius: 2, amount: 1.5);

  return Uint8List.fromList(img.encodePng(image));
}

// ─── ① ホワイトバランス補正 ──────────────────────────────────────────────────

/// 輝度上位 5% の画素を白基準として各チャンネルをスケーリング（簡易ホワイトパッチ法）。
///
/// 紙の黄ばみや照明偏りを除去し、背景を白に近づける。
img.Image _applyWhiteBalance(img.Image src) {
  // 全画素の輝度を計算
  final luminances = <double>[];
  for (final pixel in src) {
    final lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
    luminances.add(lum);
  }

  // 上位 5% の輝度閾値を求める
  final sorted = List.of(luminances)..sort();
  final thresholdIdx =
      (sorted.length * 0.95).floor().clamp(0, sorted.length - 1);
  final threshold = sorted[thresholdIdx];

  // 閾値以上の画素で R/G/B の平均を求める
  double sumR = 0, sumG = 0, sumB = 0;
  int count = 0;
  for (final pixel in src) {
    final lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
    if (lum >= threshold) {
      sumR += pixel.r;
      sumG += pixel.g;
      sumB += pixel.b;
      count++;
    }
  }

  if (count == 0) return src;

  final avgR = sumR / count;
  final avgG = sumG / count;
  final avgB = sumB / count;

  // 各チャンネルのスケールファクタ（白基準が 255 になるよう調整）
  final scaleR = avgR > 0 ? 255.0 / avgR : 1.0;
  final scaleG = avgG > 0 ? 255.0 / avgG : 1.0;
  final scaleB = avgB > 0 ? 255.0 / avgB : 1.0;

  final dst = img.Image.from(src);
  for (final pixel in dst) {
    pixel.r = (pixel.r * scaleR).clamp(0.0, 255.0);
    pixel.g = (pixel.g * scaleG).clamp(0.0, 255.0);
    pixel.b = (pixel.b * scaleB).clamp(0.0, 255.0);
  }
  return dst;
}

// ─── ③ 彩度強調 ──────────────────────────────────────────────────────────────

/// RGB → HSL 変換後に S 成分を [factor] 倍して RGB に戻す。
///
/// 色鉛筆・蛍光ペンの色を鮮やかに保つ。
img.Image _boostSaturation(img.Image src, double factor) {
  final dst = img.Image.from(src);
  for (final pixel in dst) {
    final r = pixel.r / 255.0;
    final g = pixel.g / 255.0;
    final b = pixel.b / 255.0;

    final maxVal = math.max(r, math.max(g, b));
    final minVal = math.min(r, math.min(g, b));
    final delta = maxVal - minVal;

    // グレー（無彩色）はスキップ
    if (delta == 0) continue;

    final l = (maxVal + minVal) / 2.0;
    final s =
        l > 0.5 ? delta / (2.0 - maxVal - minVal) : delta / (maxVal + minVal);

    double h;
    if (maxVal == r) {
      h = (g - b) / delta + (g < b ? 6.0 : 0.0);
    } else if (maxVal == g) {
      h = (b - r) / delta + 2.0;
    } else {
      h = (r - g) / delta + 4.0;
    }
    h /= 6.0;

    final newS = math.min(1.0, s * factor);
    final rgb = _hslToRgb(h, newS, l);

    pixel.r = (rgb[0] * 255).round().clamp(0, 255);
    pixel.g = (rgb[1] * 255).round().clamp(0, 255);
    pixel.b = (rgb[2] * 255).round().clamp(0, 255);
  }
  return dst;
}

/// HSL → RGB 変換（各値 0.0〜1.0）
List<double> _hslToRgb(double h, double s, double l) {
  if (s == 0) return [l, l, l];

  double hue2rgb(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  return [
    hue2rgb(p, q, h + 1 / 3),
    hue2rgb(p, q, h),
    hue2rgb(p, q, h - 1 / 3),
  ];
}

// ─── ④ アンシャープマスク ─────────────────────────────────────────────────────

/// ガウスぼかし差分をオリジナルに加算してエッジを強調する。
///
/// [radius]: ぼかし半径、[amount]: 強調量（大きいほど強くなる）
img.Image _applyUnsharpMask(
  img.Image src, {
  int radius = 2,
  double amount = 1.5,
}) {
  final blurred = img.gaussianBlur(src, radius: radius);
  final dst = img.Image.from(src);
  for (final pixel in dst) {
    final bp = blurred.getPixel(pixel.x, pixel.y);

    double sharpen(double orig, double blur) =>
        (orig + amount * (orig - blur)).clamp(0.0, 255.0);

    pixel.r = sharpen(pixel.r.toDouble(), bp.r.toDouble());
    pixel.g = sharpen(pixel.g.toDouble(), bp.g.toDouble());
    pixel.b = sharpen(pixel.b.toDouble(), bp.b.toDouble());
  }
  return dst;
}
