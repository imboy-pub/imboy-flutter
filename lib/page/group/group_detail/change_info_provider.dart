import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';

part 'change_info_provider.g.dart';

/// 修改群信息状态
class ChangeInfoState {
  final String text;
  final bool valueChanged;
  final bool isSaving;
  final GroupModel? group;

  const ChangeInfoState({
    this.text = '',
    this.valueChanged = false,
    this.isSaving = false,
    this.group,
  });

  ChangeInfoState copyWith({
    String? text,
    bool? valueChanged,
    bool? isSaving,
    GroupModel? group,
  }) {
    return ChangeInfoState(
      text: text ?? this.text,
      valueChanged: valueChanged ?? this.valueChanged,
      isSaving: isSaving ?? this.isSaving,
      group: group ?? this.group,
    );
  }
}

/// 修改群信息 Notifier
@Riverpod(keepAlive: false)
class ChangeInfoNotifier extends _$ChangeInfoNotifier {
  @override
  ChangeInfoState build() {
    return const ChangeInfoState();
  }

  /// 设置群组信息
  void setGroup(GroupModel group) {
    state = state.copyWith(group: group, text: group.title);
  }

  /// 更新文本
  void updateText(String text) {
    final changed = text.trim() != (state.group?.title ?? '');
    state = state.copyWith(text: text, valueChanged: changed);
  }

  /// 清空文本
  void clearText() {
    state = state.copyWith(text: '', valueChanged: true);
  }

  /// 设置保存状态
  void setSaving(bool value) {
    state = state.copyWith(isSaving: value);
  }

  /// 保存群信息
  Future<GroupModel?> saveGroupInfo(String groupId) async {
    if (!state.valueChanged) {
      return null;
    }

    final service = ChangeInfoService();
    setSaving(true);

    try {
      final result = await service.updateGroup(
        groupId: groupId,
        title: state.text.trim(),
      );
      return result;
    } finally {
      setSaving(false);
    }
  }
}

/// 修改群信息服务
class ChangeInfoService {
  Future<GroupModel?> updateGroup({
    required String groupId,
    String? title,
    String? avatar,
    String? notice,
  }) async {
    final provider = GroupApi();

    // 构建更新数据
    final data = <String, dynamic>{};
    if (title != null && title.isNotEmpty) {
      data['title'] = title;
    }
    if (avatar != null && avatar.isNotEmpty) {
      data['avatar'] = avatar;
    }
    if (notice != null && notice.isNotEmpty) {
      data['notice'] = notice;
    }

    // 使用 groupEdit 方法
    final success = await provider.groupEdit(gid: groupId, data: data);

    if (success) {
      // 从本地数据库更新群组信息
      final groupRepo = GroupRepo();
      final group = await groupRepo.findById(groupId);
      if (group != null) {
        return group;
      }
    }
    return null;
  }
}
