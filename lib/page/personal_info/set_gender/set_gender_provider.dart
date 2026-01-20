import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import '../personal_info/personal_info_provider.dart';

part 'set_gender_provider.g.dart';

/// 设置性别状态
class SetGenderState {
  final String selectedGender;
  final String pendingGender;
  final bool isSaving;

  const SetGenderState({
    this.selectedGender = '',
    this.pendingGender = '',
    this.isSaving = false,
  });

  SetGenderState copyWith({
    String? selectedGender,
    String? pendingGender,
    bool? isSaving,
  }) {
    return SetGenderState(
      selectedGender: selectedGender ?? this.selectedGender,
      pendingGender: pendingGender ?? this.pendingGender,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// 设置性别 Provider
@riverpod
class SetGenderNotifier extends _$SetGenderNotifier {
  String originalGender = '';

  @override
  SetGenderState build() {
    _loadCurrentGender();
    return SetGenderState(selectedGender: originalGender);
  }

  /// 加载当前性别
  void _loadCurrentGender() {
    try {
      final userInfo = UserRepoLocal.to.current;
      originalGender = userInfo.gender.toString();
    } catch (e) {
      iPrint('加载性别失败: $e');
    }
  }

  /// 选择性别
  Future<bool> selectGender(String gender, WidgetRef ref) async {
    final currentState = state;
    // 若正在提交或选择相同值，忽略
    if (currentState.isSaving) return false;
    if (currentState.selectedGender == gender) return false;

    // 标记为正在提交并记录 pending
    state = currentState.copyWith(isSaving: true, pendingGender: gender);

    try {
      final apiResult = await _updateGenderAPI(gender, ref);

      if (apiResult) {
        // 更新本地用户信息
        await _updateLocalUserInfo(int.tryParse(gender) ?? 0);

        // 更新状态
        state = SetGenderState(
          selectedGender: gender,
          pendingGender: '',
          isSaving: false,
        );
        originalGender = gender;
        return true;
      } else {
        await _handleSaveError('', '');
        return false;
      }
    } catch (e) {
      iPrint('设置性别失败: $e');
      // 网络异常回滚并提示
      await _revertToOriginal();
      return false;
    } finally {
      // 清理 pending 与保存状态
      state = state.copyWith(pendingGender: '', isSaving: false);
    }
  }

  /// 更新本地用户信息
  Future<void> _updateLocalUserInfo(int genderInt) async {
    try {
      final payload = UserRepoLocal.to.current.toMap();
      payload['gender'] = genderInt;
      UserRepoLocal.to.changeInfo(payload);
    } catch (e) {
      iPrint('本地用户信息更新失败: $e');
    }
  }

  /// 处理保存错误并回滚
  Future<void> _handleSaveError(String errorCode, String errorMessage) async {
    await _revertToOriginal();
  }

  /// 回滚到原始性别
  Future<void> _revertToOriginal() async {
    state = state.copyWith(selectedGender: originalGender);
  }

  /// 调用 API 更新性别
  Future<bool> _updateGenderAPI(String gender, WidgetRef ref) async {
    return await ref.read(personalInfoProvider.notifier).changeInfo({
      "field": "gender",
      "value": gender,
    });
  }
}
