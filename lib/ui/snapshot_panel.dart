import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/snapshot.dart';

/// キャンバス上部中央に表示するスナップショット一覧パネル。
/// スナップショットが 0 件の場合は非表示。
class SnapshotPanel extends StatelessWidget {
  const SnapshotPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshots = AppState.of(context).snapshots;
    if (snapshots.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 88,
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: const Color(0xE82C2C2E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: snapshots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) => _SnapshotTile(snapshot: snapshots[i], index: snapshots.length - i),
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final Snapshot snapshot;
  final int index;
  const _SnapshotTile({required this.snapshot, required this.index});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '#$index  ${_formatTime(snapshot.createdAt)}',
      child: GestureDetector(
        onTap: () => AppStateWidget.of(context).restoreSnapshot(snapshot),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 96,
            color: Colors.white,
            child: RawImage(image: snapshot.thumbnail, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
