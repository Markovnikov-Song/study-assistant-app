class EditHistory {
  static const int maxSize = 50;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  /// 推入新快照（在执行编辑操作前调用，保存操作前的状态）。
  /// 先清空重做栈，再将快照推入撤销栈；若超过 50 条，移除最旧的一条。
  void push(String snapshot) {
    clearRedo();
    _undoStack.add(snapshot);
    if (_undoStack.length > maxSize) {
      _undoStack.removeAt(0);
    }
  }

  /// 撤销：将 [currentSnapshot] 推入重做栈，弹出并返回撤销栈顶快照。
  /// 若撤销栈为空，返回 null。
  String? undo(String currentSnapshot) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(currentSnapshot);
    return _undoStack.removeLast();
  }

  /// 重做：将 [currentSnapshot] 推入撤销栈，弹出并返回重做栈顶快照。
  /// 若重做栈为空，返回 null。
  String? redo(String currentSnapshot) {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(currentSnapshot);
    return _redoStack.removeLast();
  }

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  /// 清空重做栈（新操作后调用）。
  void clearRedo() => _redoStack.clear();
}
