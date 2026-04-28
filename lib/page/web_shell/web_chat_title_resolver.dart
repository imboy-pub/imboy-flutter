/// Phase 2.1.d — Web Shell ChatPanel header 标题决策（纯函数）
///
/// 把"按 chatType 选用 contact / group title + fallback peerId"的决策从异步
/// 副作用代码（_WebChatPanel.initState 内的 ContactRepo / GroupRepo 查询）剥离。
///
/// 调用方典型用法（参见 web_shell_bootstrap.dart `_WebChatPanel.build`）：
/// ```dart
/// final title = pickChatTitle(
///   chatType: widget.selection.chatType,
///   peerId: widget.selection.peerId,
///   contactTitle: _resolvedContact?.title,  // ContactModel.title getter
///   groupTitle: _resolvedGroup?.title,      // GroupModel.title field
/// );
/// ```
///
/// 设计约束：
/// - 零外部依赖（仅 `dart:core`），易于测试，避免拉 sqflite/dio 链
/// - **trim 仅用于"是否为空"判断，不修改返回值**：保留前后空白让 UI 层决定渲染
/// - 未知 chatType（C2S 等）目前一律 fallback peerId，后续切片按需扩展
library;

/// 决定 ChatPanel header 显示的标题
///
/// 优先级：
/// - `chatType == 'C2C'` → contactTitle（remark > nickname > account 已合并在
///   ContactModel.title getter 内）→ fallback peerId
/// - `chatType == 'C2G'` → groupTitle → fallback peerId
/// - 其他 → 直接 fallback peerId
///
/// [contactTitle] / [groupTitle] 为 null 或全空白视为缺失。
String pickChatTitle({
  required String chatType,
  required String peerId,
  String? contactTitle,
  String? groupTitle,
}) {
  switch (chatType) {
    case 'C2C':
      if (_isPresent(contactTitle)) return contactTitle!;
      return peerId;
    case 'C2G':
      if (_isPresent(groupTitle)) return groupTitle!;
      return peerId;
    default:
      return peerId;
  }
}

bool _isPresent(String? s) => s != null && s.trim().isNotEmpty;
