# study_note — 技術メモ

各機能の実装方針・ライブラリ使用方法に関するメモ。

---

## 1. フリーハンド描画 — `draw_your_image`

**パッケージ:** `draw_your_image ^0.12.0`
**参考:** [AI_GUIDE.md](https://github.com/chooyan-eng/draw_your_image/blob/main/AI_GUIDE.md)

### 基本設計思想

`draw_your_image` は**宣言的 API** のキャンバスライブラリ。以下の機能を**意図的に省いて**いる（開発者側で実装する）:

- Undo / Redo
- 画像エクスポート
- ズーム / パン
- 消しゴム・選択（コールバックで合成する設計）

### コアデータ構造

| 型 | 概要 |
|----|------|
| `Stroke` | 1ストローク。color / width / device kind / points / data（メタデータ）を持つ |
| `StrokePoint` | ストローク内の1点。position / pressure / tilt / orientation などセンサ値を含む |
| `PointerDeviceKind` | stylus / touch / mouse を区別 |

`Stroke.data` フィールドは任意の `Map<String, dynamic>` を付与できる。消しゴム判定などのタグ付けに活用する。

### 主要コールバック

#### `onStrokeStarted`

新ストロークを開始するか否かを制御する。

```dart
onStrokeStarted: (deviceKind, currentStroke) {
  // currentStroke != null なら既存ストローク継続中
  if (currentStroke != null) return StrokeAction.continueStroke();

  // Apple Pencil のみ描画を許可
  if (deviceKind == PointerDeviceKind.stylus) {
    return StrokeAction.startNewStroke(
      color: selectedColor,
      width: strokeWidth,
    );
  }
  return StrokeAction.reject();
}
```

**ポイント:** `currentStroke != null` チェックを必ず先頭に入れること（ガイド強調事項）。

#### `onStrokeUpdated`

ドロー中にリアルタイムでポイントを操作できる。筆圧による線幅変化などに使用。

```dart
onStrokeUpdated: (stroke, newPoint) {
  // 筆圧に応じて線幅を動的変更
  final pressure = newPoint.pressure ?? 0.5;
  return stroke.copyWith(width: baseWidth * pressure * 2);
}
```

#### `strokePainter`

複数の `Paint` を返すことで、影・縁取り・グラデーションなどの合成描画が可能。

```dart
strokePainter: (stroke) => [
  Paint()
    ..color = stroke.color
    ..strokeWidth = stroke.width
    ..strokeCap = StrokeCap.round,
]
```

### 実装方針（本プロジェクト向け）

#### Apple Pencil 優先 + パームリジェクション

```
stylus  → 描画許可
finger  → 消しゴムモード時のみ許可（or 完全拒否）
mouse   → デバッグ用に許可（実機では finger 扱い）
```

`onStrokeStarted` で `deviceKind` を見て制御する。

#### 消しゴム

`draw_your_image` に消しゴムモードは**ない**。以下の方式で合成する:

1. ストローク開始時に `Stroke.data = {'erasing': true}` をセット
2. `strokePainter` で `data['erasing'] == true` なら `BlendMode.clear` で描画
3. または、完成済みストロークとの交差判定でオブジェクトを削除する方式

本プロジェクトは「アクティブレイヤーのオブジェクト削除」方式のため、ストロークとの**交差ヒットテスト**で削除対象を特定して `objects` リストから除去するアプローチが適切。

#### Undo / Redo

`draw_your_image` は Undo/Redo を提供しない。本プロジェクトでは:

- `canvas/canvas_history.dart` に操作スタックを実装
- `CanvasState`（`objects` リスト全体）のスナップショットをスタックに積む
- 操作単位: ストローク完了・図形追加・削除・クリア など

#### フリーハンドの `DrawObject` モデル

```dart
class FreePaint extends DrawObject {
  List<Offset> points;
  // draw_your_image の Stroke から変換して保持
}
```

`Stroke` が確定したら `FreePaint` へ変換して `CanvasState.objects` に追加する。
`draw_your_image` 側のストローク一覧とは分離し、**本プロジェクトのオブジェクトモデルを正として管理する**。

---

## 2. 画像切り抜き — `crop_your_image`

**パッケージ:** `crop_your_image ^2.0.0`
**pub.dev:** https://pub.dev/packages/crop_your_image

### 概要

キャンバス上でシームレスな切り抜き操作が可能なパッケージ。Flutter の `CustomPainter` ベースで動作し、ピンチ・ドラッグによるインタラクティブなトリミングUIを提供する。

### 実装方針

#### 取り込みフロー

```
写真選択（Swift / image_picker）
    ↓
CropController を生成して Crop ウィジェットを表示
    ↓
ユーザーが切り抜き範囲をドラッグで調整
    ↓
onCropped コールバックで切り抜き後の Uint8List を取得
    ↓
画像加工パイプライン（image パッケージ）へ渡す
    ↓
アクティブレイヤーへ ImageObject として配置
```

#### 基本的な使い方

```dart
final _cropController = CropController();

Crop(
  image: imageBytes,          // Uint8List
  controller: _cropController,
  onCropped: (result) {
    // result は CropSuccess or CropFailure
    if (result is CropSuccess) {
      final croppedBytes = result.croppedImage;
      // → 加工パイプラインへ
    }
  },
  aspectRatio: null,          // 自由比率（固定しない）
  initialRectBuilder: ...,    // 初期トリミング枠
)
```

#### UI設計

- 切り抜き操作は**フルスクリーンのモーダル画面**として表示
- 確定ボタンで `_cropController.crop()` を呼び出す
- キャンセルで元画面へ戻る（オブジェクトは追加しない）

---

## 3. 写真選択 — Swift コード自前実装

**方針:** `image_picker` パッケージを使わず、iOS の `PHPickerViewController` を Swift で直接実装する。

### 採用理由・目的

- パッケージへの依存を減らし、iOS ネイティブ API を直接学ぶ
- `PHPickerViewController`（iOS 14+）は権限不要で使えるモダンな API
- カスタマイズの自由度が高い

### 実装方針

#### Flutter ↔ Swift 連携（Method Channel）

```
Flutter 側                   Swift 側（AppDelegate / Plugin）
─────────────────────────────────────────────────────────────
channel.invokeMethod(        MethodChannel を登録して受信
  'pickPhoto'                PHPickerViewController を表示
)                            ↓
                             選択完了後に画像を Data（PNG）に変換
                             ↓
result: Uint8List     ←      result(flutterResult(pngData))
```

#### Swift 実装のポイント

```swift
import PhotosUI

// PHPickerConfiguration で選択設定
var config = PHPickerConfiguration()
config.selectionLimit = 1
config.filter = .images

let picker = PHPickerViewController(configuration: config)
picker.delegate = self
present(picker, animated: true)

// delegate で画像を取り出す
func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider,
          provider.canLoadObject(ofClass: UIImage.self) else { return }

    provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
        guard let uiImage = image as? UIImage,
              let pngData = uiImage.pngData() else { return }
        DispatchQueue.main.async {
            self?.flutterResult?(pngData)
        }
    }
}
```

#### Flutter 側の受け取り

```dart
static const _channel = MethodChannel('study_note/photo_picker');

Future<Uint8List?> pickPhoto() async {
  final bytes = await _channel.invokeMethod<Uint8List>('pickPhoto');
  return bytes;
}
```

#### ファイル構成（想定）

```
ios/Runner/
├── AppDelegate.swift
└── PhotoPickerPlugin.swift   # Method Channel + PHPickerViewController
```

---

## 4. 共通：画像加工パイプライン

**パッケージ:** `image`（pub.dev）

SPEC §8-2 に記載の処理を `image_importer.dart` に実装する。

| 順序 | 処理 | API例 |
|------|------|-------|
| ① | ホワイトバランス補正 | 輝度上位 5% を白基準にチャンネルスケーリング |
| ② | コントラスト強調 | `adjustColor(contrast: 1.3)` |
| ③ | 彩度強調 | HSL変換 → S成分 × 1.4 → RGB変換 |
| ④ | アンシャープマスク | ガウスぼかし差分をオリジナルに加算 |

処理はすべて **Isolate 上で実行**し、UI スレッドをブロックしない。

## 5. 「破線」の描画方法

以下、ChatGPT に生成してもらったサンプルコード

2点を結ぶ直線だけなら PathMetric は使わず、線分上を「dash / gap」単位で刻んで drawLine を繰り返すのがシンプルで速いです。

2点の直線を破線で描く（CustomPainter向け）

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

void drawDashedLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  double dashLength = 10,
  double gapLength = 6,
}) {
  final delta = b - a;
  final length = delta.distance;
  if (length == 0) return;

  final direction = delta / length; // 単位ベクトル
  double distance = 0.0;

  while (distance < length) {
    final start = a + direction * distance;
    final endDistance = math.min(distance + dashLength, length);
    final end = a + direction * endDistance;

    canvas.drawLine(start, end, paint);

    distance = endDistance + gapLength;
  }
}

class DashedSegmentPainter extends CustomPainter {
  final Offset a;
  final Offset b;

  DashedSegmentPainter({required this.a, required this.b});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round; // 見た目が良いことが多い
      // ..color = Colors.black; // 必要なら

    drawDashedLine(
      canvas,
      a,
      b,
      paint,
      dashLength: 10,
      gapLength: 6,
    );
  }

  @override
  bool shouldRepaint(covariant DashedSegmentPainter oldDelegate) =>
      oldDelegate.a != a || oldDelegate.b != b;
}
```