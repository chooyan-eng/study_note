import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// 画像切り抜きダイアログ（T14）。
///
/// [imageBytes] を受け取って切り抜き UI をダイアログ内に提供する。
/// 確定すると切り抜き後の [Uint8List] を返す。
/// キャンセルすると null を返す。
///
/// 呼び出し方:
/// ```dart
/// final cropped = await showDialog<Uint8List>(
///   context: context,
///   barrierDismissible: false,
///   builder: (_) => CropImageScreen(imageBytes: bytes),
/// );
/// ```
class CropImageScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const CropImageScreen({super.key, required this.imageBytes});

  @override
  State<CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<CropImageScreen> {
  final _cropController = CropController();
  bool _isCropping = false;

  void _onCrop() {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    _cropController.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;
    if (result is CropSuccess) {
      Navigator.of(context).pop<Uint8List>(result.croppedImage);
    } else {
      setState(() => _isCropping = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('切り抜きに失敗しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 720,
          height: 600,
          child: Column(
            children: [
              // ヘッダー（キャンセル / タイトル / 確定）
              Container(
                color: const Color(0xFF1C1C1E),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    TextButton(
                      onPressed:
                          _isCropping ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(color: Color(0xFF0A84FF)),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '切り抜き',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isCropping ? null : _onCrop,
                      child: _isCropping
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0A84FF),
                              ),
                            )
                          : const Text(
                              '確定',
                              style: TextStyle(
                                color: Color(0xFF0A84FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              // 切り抜きウィジェット
              Expanded(
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  onCropped: _onCropped,
                  maskColor: Colors.black54,
                  baseColor: Colors.black,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(size: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
