/// Phase 1.1.b — Web Shell 全局状态 + 选中项密封变体
///
/// 设计原则：
/// - **不可变**：所有字段 `final`，状态变更通过 [WebShellState.copyWith]
/// - **sealed selection**：[WebSelection] 4 个具体子类对应 4 个 Tab 的选中项语义
///   （Tab 索引：0 会话 / 1 联系人 / 2 频道 / 3 我的，对齐既有 BottomNavigationPage）
/// - **显式 clear 标志**：copyWith 用 `clearSelection: true` 显式置空，避免
///   传 `null` 与"未传"的语义混淆（项目内既有切片如 group_member_repo `update`
///   也采用同样模式）
/// - **==/hashCode 全实现**：让 Riverpod 3 的 selector 能高效短路重建
library;

import 'package:flutter/foundation.dart';

/// Web Shell 选中项的密封变体（穷尽 4 个 Tab 的选中语义）。
///
/// switch 时必须穷尽所有变体，编译器强制（sealed class 契约）。
sealed class WebSelection {
  const WebSelection();
}

/// Tab 0（会话）选中：进入聊天面板
final class ChatSelection extends WebSelection {
  /// 对端 ID（C2C uid 或 C2G groupId，TSID 字符串）
  final String peerId;

  /// 'C2C' / 'C2G'（与 ConversationModel.type / chat_page 入参对齐）
  final String chatType;

  const ChatSelection({required this.peerId, required this.chatType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSelection &&
          other.peerId == peerId &&
          other.chatType == chatType;

  @override
  int get hashCode => Object.hash(peerId, chatType);

  @override
  String toString() => 'ChatSelection(peerId: $peerId, type: $chatType)';
}

/// Tab 1（联系人）选中：展示联系人详情
final class ContactSelection extends WebSelection {
  /// 联系人 uid（TSID 字符串）
  final String uid;

  const ContactSelection({required this.uid});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactSelection && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'ContactSelection(uid: $uid)';
}

/// Tab 2（频道）选中：展示频道详情
final class ChannelSelection extends WebSelection {
  /// 频道 ID（TSID 字符串）
  final String channelId;

  const ChannelSelection({required this.channelId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelSelection && other.channelId == channelId;

  @override
  int get hashCode => channelId.hashCode;

  @override
  String toString() => 'ChannelSelection(channelId: $channelId)';
}

/// Tab 3（我的）选中：展示设置详情面板
final class MineSelection extends WebSelection {
  /// 具体设置分组键（null = 概览面板，非 null = 具体设置子项）
  final String? section;

  const MineSelection({this.section});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MineSelection && other.section == section;

  @override
  int get hashCode => section.hashCode;

  @override
  String toString() => 'MineSelection(section: $section)';
}

/// Web Shell 全局状态
///
/// Riverpod 3 NotifierProvider 持有的不可变 state。
@immutable
class WebShellState {
  /// 当前 Tab 索引（0..3，对齐 BottomNavigationPage 的 4 Tab 顺序）
  final int currentTab;

  /// 当前选中项（null = 显示右栏欢迎屏）
  final WebSelection? selectedItem;

  const WebShellState({
    this.currentTab = 0,
    this.selectedItem,
  });

  /// 不可变更新。
  ///
  /// `selectedItem` 通过 [clearSelection] 显式置空（语义清晰）：
  /// - `clearSelection: true` → selectedItem 强制置 null（其他参数仍可生效）
  /// - 否则若 [selectedItem] 入参非 null → 用新值
  /// - 否则保留旧值
  WebShellState copyWith({
    int? currentTab,
    WebSelection? selectedItem,
    bool clearSelection = false,
  }) {
    return WebShellState(
      currentTab: currentTab ?? this.currentTab,
      selectedItem: clearSelection
          ? null
          : (selectedItem ?? this.selectedItem),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebShellState &&
          other.currentTab == currentTab &&
          other.selectedItem == selectedItem;

  @override
  int get hashCode => Object.hash(currentTab, selectedItem);

  @override
  String toString() =>
      'WebShellState(currentTab: $currentTab, selectedItem: $selectedItem)';
}
