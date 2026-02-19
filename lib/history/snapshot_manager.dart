import '../models/snapshot.dart';

/// スナップショットの一覧を管理するクラス（最大10件）
class SnapshotManager {
  static const _maxCount = 10;
  final List<Snapshot> _snapshots = [];

  List<Snapshot> get snapshots => List.unmodifiable(_snapshots);

  /// スナップショットを先頭に追加する。10件を超えた場合は最古のものを削除する。
  void add(Snapshot snapshot) {
    _snapshots.insert(0, snapshot);
    if (_snapshots.length > _maxCount) {
      _snapshots.removeLast();
    }
  }
}
