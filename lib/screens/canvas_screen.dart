import 'package:flutter/material.dart';

import '../ui/toolbar.dart';

class CanvasScreen extends StatelessWidget {
  const CanvasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Row(
        children: [
          // 左サイドツールバー
          const Toolbar(),
          // キャンバス領域：ツールバーの右を最大限占有
          Expanded(
            child: Container(
              color: Colors.white,
              // T04 以降でここに Draw ウィジェットを組み込む
            ),
          ),
        ],
      ),
    );
  }
}
