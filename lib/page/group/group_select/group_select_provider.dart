import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/conversation_model.dart';

import 'group_select_service.dart';

part 'group_select_provider.g.dart';

/// 群组选择状态
class GroupSelectState {
  final List<ConversationModel> items;
  final bool isLoading;

  const GroupSelectState({this.items = const [], this.isLoading = false});

  GroupSelectState copyWith({List<ConversationModel>? items, bool? isLoading}) {
    return GroupSelectState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 群组选择服务 Provider
final groupSelectServiceProvider = Provider<GroupSelectService>((ref) {
  return GroupSelectService();
});

/// 群组选择 Notifier
@riverpod
class GroupSelectNotifier extends _$GroupSelectNotifier {
  @override
  GroupSelectState build() {
    return const GroupSelectState();
  }

  /// 设置加载状态
  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  /// 设置会话列表
  void setItems(List<ConversationModel> items) {
    state = state.copyWith(items: items);
  }

  /// 加载数据
  Future<void> loadData() async {
    final service = ref.read(groupSelectServiceProvider);
    setLoading(true);
    try {
      final items = await service.loadGroupConversations();
      setItems(items);
    } finally {
      setLoading(false);
    }
  }

  /// 重置状态
  void reset() {
    state = const GroupSelectState();
  }
}
