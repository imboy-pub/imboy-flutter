/// 多选消息状态核心（chat_multi_select_v1 / W1-A）。
///
/// `NotifierProvider.autoDispose.family`，family key = conversationUk3：
/// 每个会话一份独立多选状态，跨会话天然隔离；会话页销毁（无监听者）后
/// autoDispose 回收，重建即为初始空状态（不残留上次勾选）。
///
/// 设计边界：
/// - 只保存消息 ID 集合，**不复制完整 Message**（批量操作的排序/取正文由
///   W1-B Batch Coordinator 依据当前消息列表完成）；
/// - 可选性规则全部委托 [evaluateMessageSelectability]（纯函数，
///   message_selectability.dart）；
/// - enter/toggle 返回 `String?`：null=成功，非 null=稳定 reason code
///   （见 [MessageSelectionReason]）；
/// - 上限 100 条（冻结合同 §4.2），第 101 条拒绝 `limit_exceeded`。
///
/// 本文件是 domain/selection 中唯一接触 riverpod 的点（provider 必须靠近
/// 其状态类放置）；纯函数部分见同目录 message_selectability.dart。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_selectability.dart';

/// 多选状态快照（不可变值对象）。
///
/// 值相等（W5-G1 G1-5）：`active` 相同且 `selectedIds` 集合相等即相等
///（与插入顺序无关）—— 供测试断言与 riverpod `select` 等按值比较的场景
/// 使用。
///
/// 注：本想复用 `package:collection` 的 `SetEquality`，但 `collection`
/// 在 pubspec 中仅为传递依赖，直接 import 触发
/// `depend_on_referenced_packages` 告警（pubspec 不在本波次改动范围），
/// 故按集合等价（长度一致 + 互相包含）手写，语义与 SetEquality 相同。
class MessageSelectionState {
  MessageSelectionState({this.active = false, Set<String>? selectedIds})
    : selectedIds = Set.unmodifiable(selectedIds ?? const <String>{});

  /// 是否处于多选模式。
  final bool active;

  /// 已选消息 ID（插入序、不可变视图；不复制完整 Message）。
  final Set<String> selectedIds;

  /// 已选数量。
  int get count => selectedIds.length;

  /// 是否选中某条。
  bool contains(String messageId) => selectedIds.contains(messageId);

  /// 选中集合是否为空。
  bool get isEmpty => selectedIds.isEmpty;

  @override
  bool operator ==(Object other) {
    if (other is! MessageSelectionState) return false;
    if (other.active != active) return false;
    // 集合等价（无视插入序）：长度一致 + 互相包含。
    final otherIds = other.selectedIds;
    return selectedIds.length == otherIds.length &&
        selectedIds.containsAll(otherIds);
  }

  @override
  int get hashCode => Object.hash(
    active,
    // 与 == 同口径的序无关散列：对排序后的 id 求hash。
    Object.hashAllUnordered(selectedIds),
  );
}

/// 每会话多选状态 Notifier（构造参数即 family key：conversationUk3）。
class MessageSelectionNotifier extends Notifier<MessageSelectionState> {
  MessageSelectionNotifier(this.conversationUk3);

  /// 本状态归属的会话（family key）。
  final String conversationUk3;

  /// 多选上限（冻结合同 §4.2：最多 100 条）。
  static const int maxSelectionCount = 100;

  @override
  MessageSelectionState build() => MessageSelectionState();

  /// 进入多选并选中首条（长按菜单「多选」入口）。
  ///
  /// 首条不可选 → 返回 reason 且**不进入**多选；已激活时幂等
  /// （同 id 不重复；新 id 等价于追加选中，受上限约束）。
  String? enter(String messageId, MessageSelectionTraits traits) {
    final decision = evaluateMessageSelectability(traits);
    if (!decision.selectable) {
      return decision.reasonCode;
    }
    final current = state;
    if (current.active && current.contains(messageId)) {
      return null; // 幂等
    }
    if (current.active && current.count >= maxSelectionCount) {
      return MessageSelectionReason.limitExceeded;
    }
    final nextIds = <String>{...current.selectedIds, messageId};
    state = MessageSelectionState(active: true, selectedIds: nextIds);
    return null;
  }

  /// 切换选中：已选则取消；未选则做可选性判定后加入。
  ///
  /// - 未激活 → `inactive`；
  /// - 不可选 → 该消息的稳定 reason code（取消勾选不受此限，见下）；
  /// - 已达 100 条再选新 id → `limit_exceeded`；
  /// - 取消已选 id **始终成功**（即使其当前不满足可选规则——例如选中后
  ///   进入发送中，勾选框必须仍可取消）。
  String? toggle(String messageId, MessageSelectionTraits traits) {
    final current = state;
    if (!current.active) {
      return MessageSelectionReason.inactive;
    }
    if (current.contains(messageId)) {
      final nextIds = <String>{...current.selectedIds}..remove(messageId);
      state = MessageSelectionState(active: true, selectedIds: nextIds);
      return null;
    }
    final decision = evaluateMessageSelectability(traits);
    if (!decision.selectable) {
      return decision.reasonCode;
    }
    if (current.count >= maxSelectionCount) {
      return MessageSelectionReason.limitExceeded;
    }
    final nextIds = <String>{...current.selectedIds, messageId};
    state = MessageSelectionState(active: true, selectedIds: nextIds);
    return null;
  }

  /// 清空已选（「全不选」），保持多选模式激活。
  void clear() {
    final current = state;
    if (!current.active || current.isEmpty) {
      return;
    }
    state = MessageSelectionState(active: true);
  }

  /// 退出多选并清空（返回键/关闭 action bar）。
  void exit() {
    if (!state.active) {
      return;
    }
    state = MessageSelectionState();
  }

  /// 对账：传入当前会话仍存在的消息 ID，删除已失效（被删除/撤回移除）的
  /// 选中项。保持激活态不变（选中清空后是否自动退出由 UI 决定）。
  void reconcile(Iterable<String> existingMessageIds) {
    final current = state;
    if (!current.active) {
      return;
    }
    final existing = existingMessageIds.toSet();
    final retained = current.selectedIds.where(existing.contains).toSet();
    if (retained.length == current.count) {
      return; // 无失效项，no-op（不触发无意义重建）
    }
    state = MessageSelectionState(active: true, selectedIds: retained);
  }
}

/// 多选状态 Provider：autoDispose + family(conversationUk3)。
///
/// 页面侧 `ref.watch(messageSelectionProvider(conversationUk3))` 消费
/// （autoDispose family 只 read 不 listen 会在间隙被销毁丢状态，与仓库
/// workspace_data_providers 的既有告诫一致）。
final messageSelectionProvider = NotifierProvider.autoDispose
    .family<MessageSelectionNotifier, MessageSelectionState, String>(
      MessageSelectionNotifier.new,
    );
