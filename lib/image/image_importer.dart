import 'dart:typed_data';

import 'package:flutter/services.dart';

/// カメラ撮影・画像加工パイプラインの起点となるクラス。
///
/// T13: MethodChannel 経由で iOS カメラを起動し、撮影した画像を Uint8List で返す。
/// T14: crop_your_image による切り抜き
/// T15: image パッケージによる加工パイプライン
class ImageImporter {
  static const _channel = MethodChannel('study_note/photo_picker');

  /// カメラを起動して撮影した画像の PNG バイト列を返す。
  /// キャンセルされた場合は null を返す。
  /// カメラが使用できない場合や撮影に失敗した場合は例外をスローする。
  static Future<Uint8List?> pickPhoto() async {
    final data = await _channel.invokeMethod<Uint8List>('pickPhoto');
    return data;
  }
}
