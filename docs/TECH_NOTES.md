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

新ストロークを開始するか否かを制御する。戻り値が `null` ならキャンセル、`Stroke` を返せば描画開始。

```dart
// シグネチャ: Stroke? Function(Stroke newStroke, Stroke? currentStroke)?
onStrokeStarted: (newStroke, currentStroke) {
  // currentStroke != null なら既存ストローク継続中
  if (currentStroke != null) return currentStroke;

  // Apple Pencil / マウスのみ描画を許可
  if (newStroke.deviceKind == PointerDeviceKind.stylus ||
      newStroke.deviceKind == PointerDeviceKind.mouse) {
    return newStroke.copyWith(
      color: selectedColor,
      width: strokeWidth,
      data: {'tool': 'freehand'},
    );
  }
  return null; // キャンセル
}
```

**ポイント:** `currentStroke != null` チェックを必ず先頭に入れること（ガイド強調事項）。

#### `onStrokeUpdated`

各ポイント追加後に呼ばれる。**注意: ポイントはすでに `stroke.points` に追加済み**の状態でコールバックが来る。
戻り値でストローク全体を上書きする。`null` を返すとストロークをキャンセル。

```dart
// シグネチャ: Stroke? Function(Stroke currentStroke)?
onStrokeUpdated: (stroke) {
  // 例: 直線ツールは始点と最新点の2点のみに制約
  if (stroke.data?['tool'] == 'lineSolid' || stroke.data?['tool'] == 'lineDashed') {
    if (stroke.points.length < 2) return stroke;
    return stroke.copyWith(points: [stroke.points.first, stroke.points.last]);
  }
  return stroke;
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

#### 描画物の統一方針

**画像を除くすべての描画物**（フリーハンド・直線・図形スタンプ）は **`Stroke` に落とし込んで `Draw` ウィジェット上で描画する**。`CustomPainter`（`CanvasPainter`）は **`ImageObject` 専用**であり、それ以外には使用しない。

| 描画物 | Stroke への変換方法 |
|--------|-------------------|
| フリーハンド | ポインタ入力を `StrokePoint` として逐次追加 |
| 直線（実線） | 始点と終点の2点のみを持つ `Stroke`。catmullRom（2点）が直線を生成する |
| 直線（破線） | 始点と終点の2点のみを持つ `Stroke`。`pathBuilder` で破線 `Path` を生成して描画 |
| 図形スタンプ | 輪郭頂点を `StrokePoint` 列として生成。`pathBuilder` で直線パスを返す（§6参照） |

`CanvasState.strokes` が唯一の描画ソースであり、`Draw(strokes: ...)` に渡すだけでレンダリングが完結する。

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

## 5. 「破線」の描画方法 — `Draw.pathBuilder` を使う

直線ツール（破線）は `Draw` ウィジェットの `pathBuilder` パラメータで実現する。
`CustomPainter` による独立レイヤーは**使用しない**。

### 仕組み

`pathBuilder: PathBuilder` は `Path Function(Stroke)` 型のコールバック。
Stroke の `data['tool']` を見て、破線ストロークには破線 `Path` を返す。

```dart
Path _buildStrokePath(Stroke stroke) {
  if (stroke.data?['tool'] == 'lineDashed') {
    return _buildDashedLinePath(stroke);
  }
  // フリーハンド・実線はデフォルトの Catmull-Rom（2点では直線になる）
  return generateCatmullRomPath(stroke);
}

Path _buildDashedLinePath(Stroke stroke, {double dashLength = 10, double gapLength = 6}) {
  if (stroke.points.length < 2) return Path();
  final a = stroke.points.first.position;
  final b = stroke.points.last.position;

  final path = Path();
  final delta = b - a;
  final length = delta.distance;
  if (length == 0) return path;

  final direction = delta / length;
  double distance = 0.0;

  while (distance < length) {
    final start = a + direction * distance;
    final endDistance = math.min(distance + dashLength, length);
    final end = a + direction * endDistance;
    path.moveTo(start.dx, start.dy);
    path.lineTo(end.dx, end.dy);
    distance = endDistance + gapLength;
  }
  return path;
}
```

### Stroke への変換フロー（直線ツール）

1. `onStrokeStarted`: `data: {'tool': 'lineSolid' or 'lineDashed'}` をセット
2. `onStrokeUpdated`: `stroke.points` を `[first, last]` の2点に制約（直線プレビュー）
3. `onStrokeDrawn`: 通常通り `canvasState.strokes` に追加
4. `pathBuilder` が描画時に `data['tool']` を見て破線 Path を生成

---

## 6. 計算記号図形（スタンプ）の描画方法 — `Stroke.points` で輪郭を表現

図形スタンプは `Stroke` として描画する。**消しゴムの交差判定（`IntersectionMode.segmentDistance`）は `Stroke.points` の隣接点間の線分を対象にする**ため、輪郭座標を `points` に持つことが必須。`CanvasPainter`（CustomPainter）は使わない。

### 実装フロー

1. `onStrokeStarted`: `data: {'tool': 'shape', 'shapeType': '<toolName>'}` をセット
2. `onStrokeDrawn`: タップ位置（`stroke.points.first.position`）を中心に輪郭の `StrokePoint` 列を生成し `stroke.copyWith(points: ...)` で上書きして `canvasState.strokes` に追加
3. `pathBuilder`: `data['tool'] == 'shape'` を検出し、点を直線で結ぶポリゴン `Path` を返す

### 各図形の StrokePoint 生成（80×80 基準）

| 図形 | 点の構成 |
|------|---------|
| 正方形 | 4隅 + 閉じる点（5点） |
| 円形 | 36分割の円周上の点（37点） |
| 三角形 | 3頂点 + 閉じる点（4点） |
| 菱形 | 上・右・下・左 + 閉じる点（5点） |
| 星形 | 外・内を交互に10点 + 閉じる点（11点） |

合成した `StrokePoint` のセンサ値（pressure / tilt 等）はデフォルト値（`pressure: 0.5` など）を使用。

### pathBuilder での描画

```dart
Path _buildShapeOutlinePath(Stroke stroke) {
  final path = Path();
  path.moveTo(...first point...);
  for (final point in stroke.points.skip(1)) {
    path.lineTo(point.position.dx, point.position.dy);
  }
  return path; // 最終点が先頭と同じなので視覚的に閉じている
}
```