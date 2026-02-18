# study_note — タスク一覧

実装タスクの分割・進捗管理用ドキュメント。
各タスクは独立して完結するよう粒度を設計している。

---

## タスク一覧

| # | タスク | ステータス | 対応フェーズ |
|---|--------|-----------|-------------|
| T01 | プロジェクト骨格の作成 | 完了 | Phase 1 |
| T02 | データモデルの定義 | 完了 | Phase 1 |
| T03 | 基本UIの実装（非機能） | 完了 | Phase 1 |
| T04 | フリーハンド描画の実装 | 完了 | Phase 1 |
| T05 | 直線（実線・破線）の実装 | 完了 | Phase 1 |
| T06 | Undo / Redo の実装 | 完了 | Phase 1 |
| T07 | 消しゴムの実装 | 完了 | Phase 1 |
| T08 | レイヤー機能の実装 | 未着手 | Phase 3 |
| T09 | 計算記号図形（スタンプ）の実装 | 完了 | Phase 2 |
| T10 | 任意サイズ図形（ドラッグ描画）の実装 | 未着手 | Phase 2 |
| T11 | オブジェクト選択・編集の実装 | 未着手 | Phase 2 |
| T12 | スナップショットの実装 | 未着手 | Phase 4 |
| T13 | 画像取り込みの実装（Swift / PHPicker） | 未着手 | Phase 5 |
| T14 | 画像切り抜きの実装（crop_your_image） | 未着手 | Phase 5 |
| T15 | 画像加工パイプラインの実装 | 未着手 | Phase 5 |
| T16 | キャンバスへの画像貼り付け | 未着手 | Phase 5 |

---

## 詳細

---

### T01 — プロジェクト骨格の作成

**目的:** SPEC §10 のアーキテクチャに沿ったファイル・ディレクトリ構造を空実装で揃え、後続タスクの土台を作る。

**作成するファイル:**

```
lib/
├── main.dart                         # 既存（修正）
├── app_state.dart                    # InheritedWidget の骨格
├── canvas/
│   ├── canvas_controller.dart        # 空クラス
│   ├── canvas_painter.dart           # 空 CustomPainter
│   └── selection_handler.dart        # 空クラス
├── models/
│   ├── draw_object.dart              # 空抽象クラス
│   ├── free_paint.dart               # 空クラス
│   ├── line_object.dart              # 空クラス
│   ├── shape_object.dart             # 空クラス（enum 含む）
│   ├── free_shape.dart               # 空クラス（enum 含む）
│   └── image_object.dart             # 空クラス
├── history/
│   ├── canvas_history.dart           # 空クラス
│   └── snapshot_manager.dart         # 空クラス
├── image/
│   └── image_importer.dart           # 空クラス
├── ui/
│   ├── toolbar.dart                  # 空ウィジェット
│   └── snapshot_panel.dart           # 空ウィジェット
└── screens/
    └── canvas_screen.dart            # 空ウィジェット
```

**完了条件:**
- `flutter analyze` がエラーなしで通る
- `flutter run` でアプリが起動する（白紙でも可）

---

### T02 — データモデルの定義

**目的:** SPEC §11 のデータモデルを実際の Dart クラスとして定義する。

**実装内容:**

- `DrawObject`（抽象基底クラス）: `id`, `color`, `strokeWidth`, `layerIndex`
- `CanvasState`: `List<DrawObject> objects`
- `FreePaint`: `List<Offset> points`
- `LineObject`: `Offset start, end; bool dashed`
- `ShapeObject`: `ShapeType type; Rect bounds; bool filled`
  - `ShapeType` enum: `square, circle, triangle, diamond, star`
- `FreeShape`: `FreeShapeType type; Rect bounds`
  - `FreeShapeType` enum: `rect, oval`
- `ImageObject`: `ui.Image image; Rect bounds`
- `Snapshot`: `CanvasState state; ui.Image thumbnail; DateTime createdAt`

**完了条件:**
- 全モデルが定義され `flutter analyze` がエラーなし
- copyWith / equality は必要に応じて最小限で実装

---

### T03 — 基本UIの実装（非機能）

**目的:** キャンバス画面・ツールバーのレイアウトを組む。この時点では描画は動作しない。

**実装内容:**

- `canvas_screen.dart`: `Scaffold` + `Stack`（キャンバス領域 + ツールバー）
- `toolbar.dart`: ツール選択ボタン（フリーハンド / 直線 / 消しゴム / 選択）、6色パレット、レイヤー切り替え、Undo/Redo ボタンを配置
  - タップしても何も起きない状態でOK
- `app_state.dart`: `selectedTool`, `selectedColor`, `activeLayer` などの状態フィールドを定義
- `main.dart`: `canvas_screen.dart` を起動画面として表示

**完了条件:**
- アプリ起動でキャンバス画面が表示される
- ツールバーのボタンが視覚的に確認できる（動作不要）

---

### T04 — フリーハンド描画の実装

**目的:** `draw_your_image` を使ったフリーハンドストロークの描画を動作させる。

**実装内容:**

- `pubspec.yaml` に `draw_your_image ^0.12.0` を追加（既存なら確認）
- `canvas_screen.dart` に `Draw` ウィジェットを組み込む
- `onStrokeStarted`: `stylus`、`mouse` を許可。ただし、`mouse` で描画中に `stroke` が追加されたらそちらを優先する
- `onStrokeUpdated`: ~筆圧による線幅変化（任意）~ 筆圧検知は不要
- `strokePainter`: 基本の `Paint` を返す
- ストローク確定時に `FreePaint` へ変換して `CanvasState.objects` に追加
- `canvas_painter.dart` で `FreePaint` を `CustomPainter` で描画

**参照:** TECH_NOTES §1

**完了条件:**
- Apple Pencil（またはマウス）でなぞると線が描ける
- 色選択が反映される

---

### T05 — 直線（実線・破線）の実装

**目的:** 始点→終点ドラッグで直線を描画する。実線・破線の両モードに対応する。

**実装内容:**

- `line_object.dart` の `LineObject` モデルを完成させる
- ツール選択で「直線（実線）」「直線（破線）」に切り替え
- `Draw` の `onStrokeStarted` で現在が「実線」か「破線」かを `Stroke.data` に保存
- `onStrokeUpdated` では、線が常に直線になるように始点と終点のみの2点になるよう `StrokePoint` の内容を調整
- 確定時に `LineObject` を `CanvasState.objects` に追加
- `canvas_painter.dart` で破線を `PathEffect` / `dashPattern` で描画
  - 詳細な破線の実装方法は TECH_NOTES.md を参照

**完了条件:**
- 実線・破線それぞれで始点→終点の直線が描ける
- ドラッグ中にプレビューが表示される

---

### T06 — Undo / Redo の実装

**目的:** キャンバス全体を対象とした Undo/Redo スタックを実装する。

**実装内容:**

- `canvas_history.dart`: `List<CanvasState>` の Undo/Redo スタック
  - `push(CanvasState)`: 操作確定時に現在状態を積む
  - `undo()` / `redo()`: スタックを移動して `CanvasState` を返す
- 操作単位: ストローク完了・直線追加・図形追加・削除・クリア
- `canvas_controller.dart` で履歴への push/pop を管理
- ツールバーの Undo/Redo ボタンと接続

**完了条件:**
- フリーハンド・直線の操作が Undo/Redo で戻せる・やり直せる

---

### T07 — 消しゴムの実装

**目的:** アクティブレイヤーのオブジェクトをなぞって削除する消しゴムモードを実装する。

**実装内容:**

- ツール選択で「消しゴム」に切り替え
- 消しゴムストローク中、各点と `CanvasState.objects` のヒットテストを実行
  - `FreePaint`: ストロークの各点と一定距離以内なら削除
  - `LineObject`: 線分との距離判定
- ヒットしたオブジェクトをアクティブレイヤーの `objects` から除去
- 削除操作を Undo スタックに積む

**参照:** TECH_NOTES §1（消しゴムの項）

**完了条件:**
- 消しゴムでなぞった箇所の線・図形が消える
- Undo で復元できる

---

### T08 — レイヤー機能の実装

**目的:** Layer A / Layer B の切り替えと、アクティブレイヤーのクリア機能を実装する。

**実装内容:**

- `app_state.dart` に `activeLayer`（0 or 1）を追加
- それぞれのレイヤーを `Stack` に `Draw` を 2 つ重ねる形で実装する
- layerIndex が `0` のオブジェクトは `Draw` A に、`1` のオブジェクトは `Draw` B に描画するようにデータを振り分ける
- ツールバーにレイヤー切り替えボタンを追加（Layer A / Layer B）
- レイヤーはそれぞれ透明度をスライダーで変更できる
- 描画・消しゴム操作は `activeLayer` のオブジェクトのみ対象とする
- アクティブレイヤーのクリアボタン: 対象レイヤーの全オブジェクトを削除
- `canvas_painter.dart`: Layer A → Layer B の順で描画（重ね順）

**完了条件:**
- Layer A に描いた内容が Layer B クリアで消えない
- 切り替え後の描画が正しいレイヤーに乗る

---

### T09 — 計算記号図形（スタンプ）の実装

**目的:** タップで配置できる5種類の図形スタンプを実装する。

**実装内容:**

- `shape_object.dart` の `ShapeObject` を完成させる（`ShapeType`: square / circle / triangle / diamond / star）
- ツールバーに図形選択UIを追加
- タップ座標に固定サイズの `ShapeObject` を配置
- `canvas_painter.dart` で各図形を描画
  - triangle: `Path` で三角形
  - diamond: `Path` で菱形
  - star: `Path` で星形
- 操作を Undo スタックに積む

**完了条件:**
- タップで5種の図形がキャンバスに配置できる

---

### T10 — 任意サイズ図形（ドラッグ描画）の実装

**目的:** ドラッグ操作で任意サイズの四角形・楕円を描画する。

**実装内容:**

- `free_shape.dart` の `FreeShape` を完成させる（`FreeShapeType`: rect / oval）
- ツール選択で「四角形」「楕円」を切り替え
- 四角形は「始点と終点から算出した4つの `StrokePoint` からなる線」として扱う。そうなるように `onStrokeUpdated` でデータを加工する
- 円は、「終点を中心とし、あらかじめ設定した半径を適用した円」として扱う。そうなるように `onStrokeUpdated` でデータを加工し、かつそのデータから円を描く `pathBuilder` を自作する
- 確定時に `FreeShape` を `CanvasState.objects` に追加
- 操作を Undo スタックに積む

**完了条件:**
- ドラッグで四角形・楕円が描ける
- ドラッグ中にプレビューが表示される

---

### T11 — オブジェクト選択・編集の実装

**目的:** 選択ツールでオブジェクトを選んで色・線種・サイズを変更・削除できる。

**実装内容:**

- `selection_handler.dart`: タップ座標からオブジェクトのヒットテスト
  - `FreePaint`: 点群の近傍判定
  - `LineObject`: 線分の近傍判定
  - `ShapeObject` / `FreeShape`: `Rect.contains` 判定
- 選択状態の描画（バウンディングボックス + ハンドル）を `canvas_painter.dart` に追加
- 選択中に表示するプロパティパネル（色 / 線種 / 削除ボタン）
- ハンドルドラッグによるリサイズ（`Rect` の更新）
- 各変更操作を Undo スタックに積む

**完了条件:**
- オブジェクトをタップで選択できる
- 色・線種の変更、リサイズ、削除が動作する

---

### T12 — スナップショットの実装

**目的:** キャンバス全体のスナップショットを最大10件保存・復元できる。

**実装内容:**

- `snapshot_manager.dart`: スナップショットのリスト管理（最大10件、超えたら古いものを削除）
- スナップショット保存時にキャンバスをサムネイル画像として生成（`RepaintBoundary` + `toImage`）
- `snapshot_panel.dart`: サムネイル一覧パネルのUI
  - サムネイルをタップで `CanvasState` を復元
  - 見た目としては画面中央上部にサムネイル一覧が横に並んで選べる感じ
- ツールバーにスナップショット保存ボタンを追加
- 復元操作を Undo スタックに積む（任意）

**完了条件:**
- スナップショットを保存・一覧表示・復元できる
- サムネイルが保存時の状態を反映している

---

### T13 — 画像取り込みの実装（Swift / PHPicker）

**目的:** Swift の `PHPickerViewController` を使ってフォトライブラリから画像を選択する。

**実装内容:**

- `ios/Runner/PhotoPickerPlugin.swift` を新規作成
  - `MethodChannel('study_note/photo_picker')` を登録
  - `pickPhoto` メソッドで `PHPickerViewController` を表示
  - 選択完了後に PNG データを Flutter へ返す
- `AppDelegate.swift` にプラグインを登録
- `image/image_importer.dart` に Flutter 側の呼び出しメソッドを実装

**参照:** TECH_NOTES §3

**完了条件:**
- ツールバーのボタンタップでフォトライブラリが開く
- 選択した画像の `Uint8List` が Flutter 側で受け取れる

---

### T14 — 画像切り抜きの実装（crop_your_image）

**目的:** 選択した画像をユーザーが切り抜いてから次のステップへ渡す。

**実装内容:**

- `pubspec.yaml` に `crop_your_image ^2.0.0` を確認・追加
- フルスクリーンのモーダル画面として切り抜きUIを実装
  - `CropController` を生成して `Crop` ウィジェットを表示
  - 自由比率（`aspectRatio: null`）
- 確定ボタンで `_cropController.crop()` → `onCropped` で `Uint8List` を取得
- キャンセルで元画面に戻る

**参照:** TECH_NOTES §2

**完了条件:**
- 画像の切り抜き範囲をドラッグで指定できる
- 確定で切り抜き後の `Uint8List` が取得できる

---

### T15 — 画像加工パイプラインの実装

**目的:** 切り抜き後の画像を鮮明化処理して使いやすい状態にする。

**実装内容:**

- `pubspec.yaml` に `image` パッケージを追加
- `image_importer.dart` に加工パイプラインを実装（Isolate 上で実行）
  1. ホワイトバランス補正（輝度上位 5% を白基準にチャンネルスケーリング）
  2. コントラスト強調（`adjustColor(contrast: 1.3)`）
  3. 彩度強調（HSL変換 → S成分 × 1.4 → RGB変換）
  4. アンシャープマスク（ガウスぼかし差分をオリジナルに加算）
- 処理中はローディングインジケーターを表示

**参照:** SPEC §8-2、TECH_NOTES §4

**完了条件:**
- 加工後の画像が鮮明で色が保持されている
- UI スレッドがブロックされない

---

### T16 — キャンバスへの画像貼り付け

**目的:** 加工済み画像をアクティブレイヤーに `ImageObject` として配置する。

**実装内容:**

- `image_object.dart` の `ImageObject` を完成させる
- 加工済み `Uint8List` を `ui.Image` に変換してキャンバス中央に配置
- `canvas_painter.dart` で `ImageObject` を描画
- 配置後: 移動（ドラッグ）・リサイズ（ハンドル）が可能（T11 の選択・編集機能と連携）
- 操作を Undo スタックに積む

**完了条件:**
- 画像がキャンバスに表示される
- ドラッグで移動・ハンドルでリサイズできる

---

## 依存関係

```
T01 ─── T02 ─── T03 ─── T04 ──┬── T06 ──── T07
                                ├── T05
                                └── T08
              T02 ─── T09 ──── T11
              T02 ─── T10
T01 ─────────────────────────── T12
T13 ─── T14 ─── T15 ─── T16
```

- T03（基本UI）は T01（骨格）・T02（モデル）完了後に着手
- T04〜T10 は T03 完了後に着手（互いは並行可）
- T06（Undo/Redo）は T04 / T05 の操作を確定する際に必要なため先に実装を完成させておく
- T11（選択・編集）は T04〜T10 のオブジェクトが存在してから着手
- T12（スナップショット）は T03 の基本UIと T06 の Undo 基盤があれば着手可
- T13〜T16 は他タスクと独立して並行着手可（T16 のみ T11 の選択機能と連携）
