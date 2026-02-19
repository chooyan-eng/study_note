import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// 画像切り抜きモーダル画面（T14）。
///
/// [imageBytes] を受け取って切り抜き UI を提供する。
/// 確定すると切り抜き後の [Uint8List] を返す。
/// キャンセルすると null を返す。
///
/// 呼び出し方:
/// ```dart
/// final cropped = await Navigator.push<Uint8List>(
///   context,
///   MaterialPageRoute(
///     fullscreenDialog: true,
///     builder: (_) => CropImageScreen(imageBytes: bytes),
///   ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('切り抜きに失敗しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        title: const Text(
          '切り抜き',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: TextButton(
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'キャンセル',
            style: TextStyle(color: Color(0xFF0A84FF), fontSize: 16),
          ),
        ),
        leadingWidth: 96,
        actions: [
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _cropController,
        onCropped: _onCropped,
        aspectRatio: null,
        interactive: false,
        maskColor: Colors.black54,
        baseColor: Colors.black,
      ),
    );
  }
}
