# study_note — 仕様書

## 1. プロジェクト概要

| 項目 | 内容 |
|------|------|
| アプリ名 | study_note |
| 目的 | 小学生の算数・学習問題を解説するためのキャンバスツール |
| 主な使用シーン | 先生が問題をキャンバスに描き、生徒がその上に書き込む |
| ターゲット端末 | **iPad（Apple Pencil / スタイラス利用）最優先** |

---

## 2. 非機能要件・設計方針

- **起動即新規キャンバス**（保存機能なし）
- **1問1ページ**の固定キャンバス（無限スクロール不要）
- ツール切り替えをすばやく行えるUI設計（タブレット操作に最適化）
- セッション内のデータはメモリのみで管理し、アプリ終了で消える前提

---

## 3. キャンバス仕様

| 項目 | 仕様 |
|------|------|
| サイズ | 画面いっぱい（A4比率推奨） |
| スクロール | なし（固定） |
| 起動時 | 即新規キャンバス |
| レイヤー | 2層（後述） |

---

## 4. レイヤー仕様

### 構造

- **2層構造**（Layer A / Layer B）
- 両レイヤーは同じ仕様・同じ機能を持つ（区別なし）
- **アクティブなレイヤーのみ**が描画・消去・削除操作の対象
- 非アクティブなレイヤーは表示されるが操作できない

### 操作

- UIでアクティブレイヤーをワンタップで切り替え
- アクティブレイヤーの一括クリアボタン

### 使い方の例

> Layer A に問題の図形を描いてから Layer B に切り替え
> → Layer B 上に解答を書き込む
> → Layer B だけクリアしても Layer A は残る

---

## 5. 描画ツール

### 5-1. 色

6色固定：**黒 / 赤 / 青 / 緑 / オレンジ / 紫**

### 5-2. ペン・線ツール

| ツール | 説明 |
|--------|------|
| フリーハンド | 基本1種類のペン |
| 直線（実線） | 始点→終点 |
| 直線（破線） | 始点→終点 |
| 消しゴム | アクティブレイヤーのオブジェクトのみ消去 |

### 5-3. 計算記号図形（スタンプ型）

タップで配置。配置後からサイズ・色・線種を変更可能。

| 図形 | 用途例 |
|------|--------|
| 正方形 | □ × 3 = など |
| 円形 | ○ ÷ 2 など |
| 三角形 | △ |
| 菱形 | ◇ |
| 星形 | ★ |

### 5-4. 任意サイズ図形（ドラッグ描画）

| 図形 | 操作 |
|------|------|
| 四角形 | ドラッグで描画 |
| 円形 | ドラッグで描画 |

---

## 6. オブジェクト選択・編集

- 選択ツールでオブジェクトをタップ → 選択ハンドル表示
- 選択後に変更できるプロパティ：
  - **色**（6色パレット）
  - **線種**（実線 / 破線）
  - **サイズ**（ハンドルでリサイズ）
- **削除**（選択後にDeleteボタン or ジェスチャー）

対象オブジェクト：フリーハンドのストローク、直線、図形、画像 すべて

---

## 7. 履歴管理

### 7-1. Undo / Redo

- **スコープ: キャンバス全体**（Layer A・Layer B 両方を含む一本の履歴）
- 操作単位でスタックを積む

### 7-2. スナップショット

| 項目 | 仕様 |
|------|------|
| 保持件数 | 最大 **10件** |
| 対象 | キャンバス全体（Layer A + Layer B） |
| 永続化 | なし（セッション内のみ） |
| サムネイル | 保存時にキャンバスを画像化して紐づけ |
| 復元UI | サムネイル一覧パネルから選択して任意の時点へ復元 |

---

## 8. 画像取り込み

### フロー

```
カメラ撮影 or ギャラリー選択
    ↓
切り抜き（crop_your_image）
    ↓
画像加工（色情報を保持した鮮明化）
    ↓
アクティブレイヤーへ貼り付け
```

### 8-1. 切り抜き

`crop_your_image ^2.0.0` パッケージを使用。

### 8-2. 画像加工（色情報を保持した鮮明化）

ノート・教科書の写真を、色を保持したまま見やすく加工する。
`image` パッケージで以下の処理を**順次パイプライン適用**する（プリセット固定・UIなし）。

| 順序 | 処理 | 目的 | 手法 |
|------|------|------|------|
| ① | ホワイトバランス補正 | 紙の黄ばみ・照明偏りを除去し背景を白に近づける | 輝度上位数%の画素を白基準として各チャンネルをスケーリング（簡易ホワイトパッチ法） |
| ② | コントラスト強調 | 文字・線をくっきりさせる | `adjustColor(contrast: ...)` またはヒストグラムストレッチ |
| ③ | 彩度強調 | 色鉛筆・蛍光ペンの色を鮮やかに保つ | HSL変換後にS成分をブースト |
| ④ | アンシャープマスク | ボケを軽減してエッジを強調 | ガウスぼかし差分をオリジナルに加算 |

### 8-3. キャンバスへの貼り付け

- アクティブレイヤーに `ImageObject` として配置
- 貼り付け後：移動・リサイズ可能

---

## 9. 技術スタック

| 項目 | 選定 |
|------|------|
| Flutter | 3.41.1（FVM管理） |
| Dart SDK | ^3.11.0 |
| 描画エンジン | `CustomPainter` |
| 状態管理 | `InheritedWidget + setState`（外部パッケージなし） |
| 画像切り抜き | `crop_your_image ^2.0.0`（既存） |
| 画像描画支援 | `draw_your_image ^0.12.0`（既存） |
| 画像選択 | `image_picker`（要追加） |
| 画像加工 | `image`パッケージ（要追加） |

---

## 10. アーキテクチャ概要

```
lib/
├── main.dart
├── app_state.dart                # InheritedWidget: アプリ全体の状態
├── canvas/
│   ├── canvas_controller.dart   # 描画操作ロジック・Undo/Redo管理
│   ├── canvas_painter.dart      # CustomPainter実装（Layer A/B描画）
│   └── selection_handler.dart   # オブジェクト選択・ヒットテスト
├── models/
│   ├── draw_object.dart         # 描画オブジェクト基底クラス
│   ├── free_paint.dart          # フリーハンド
│   ├── line_object.dart         # 直線（実線・破線）
│   ├── shape_object.dart        # 計算記号図形（5種）
│   ├── free_shape.dart          # 任意サイズ図形
│   └── image_object.dart        # 画像オブジェクト
├── history/
│   ├── canvas_history.dart      # Undo/Redo スタック
│   └── snapshot_manager.dart    # スナップショット（最大10件・サムネイル付き）
├── image/
│   └── image_importer.dart      # 取り込み・切り抜き・加工パイプライン
├── ui/
│   ├── toolbar.dart             # メインツールバー（ツール・色・レイヤー切り替え）
│   └── snapshot_panel.dart      # サムネイル一覧パネル
└── screens/
    └── canvas_screen.dart       # メイン画面
```

---

## 11. データモデル概念

```dart
// 全描画オブジェクトの基底クラス
abstract class DrawObject {
  String id;
  Color color;
  double strokeWidth;
  int layerIndex; // 0 = Layer A, 1 = Layer B
}

// 各オブジェクト型
class FreePaint   extends DrawObject { List<Offset> points; }
class LineObject  extends DrawObject { Offset start, end; bool dashed; }
class ShapeObject extends DrawObject { ShapeType type; Rect bounds; bool filled; }
class FreeShape   extends DrawObject { FreeShapeType type; Rect bounds; }
class ImageObject extends DrawObject { ui.Image image; Rect bounds; }

// ShapeType  : square | circle | triangle | diamond | star
// FreeShapeType: rect | oval

// キャンバスの状態（Layer A + Layer B 合算）
class CanvasState {
  List<DrawObject> objects; // layerIndex で区別
}

// スナップショット
class Snapshot {
  CanvasState state;
  ui.Image thumbnail; // 保存時に生成したサムネイル
  DateTime createdAt;
}
```

---

## 12. 開発フェーズ（ロードマップ）

| フェーズ | 内容 |
|----------|------|
| Phase 1 | 基本キャンバス・フリーハンド・直線・6色選択・Undo/Redo |
| Phase 2 | 計算記号図形・任意サイズ図形・オブジェクト選択と編集 |
| Phase 3 | レイヤー機能（Layer A/B 切り替え・アクティブレイヤーのクリア） |
| Phase 4 | スナップショット（サムネイル生成・一覧パネル・復元） |
| Phase 5 | 画像取り込み・加工パイプライン・キャンバスへの貼り付け |
| Phase 6 | iPad / スタイラス最適化・ツール切り替え UI/UX 改善 |
