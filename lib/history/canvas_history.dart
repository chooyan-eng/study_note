import '../models/canvas_state.dart';

/// Undo / Redo スタック（キャンバス全体対象）
class CanvasHistory {
  final List<CanvasState> _undoStack = [];
  final List<CanvasState> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// 操作確定時に現在の状態をスタックに積む
  void push(CanvasState state) {
    _undoStack.add(state);
    _redoStack.clear();
  }

  /// Undo: 現在の状態を Redo スタックに退避し、1つ前の状態を返す
  CanvasState? undo(CanvasState current) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(current);
    return _undoStack.removeLast();
  }

  /// Redo: 現在の状態を Undo スタックに退避し、1つ先の状態を返す
  CanvasState? redo(CanvasState current) {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(current);
    return _redoStack.removeLast();
  }

  /// Undo / Redo スタックをすべて破棄する
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
