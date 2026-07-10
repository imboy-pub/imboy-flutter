import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import '../personal_info/personal_info_provider.dart';

part 'set_nickname_provider.g.dart';

/// 设置昵称状态
class SetNicknameState {
  final String nickname;
  final bool canSave;
  final bool isSaving;
  final String validationError;
  final int remainingChars;

  const SetNicknameState({
    this.nickname = '',
    this.canSave = false,
    this.isSaving = false,
    this.validationError = '',
    this.remainingChars = 24,
  });

  SetNicknameState copyWith({
    String? nickname,
    bool? canSave,
    bool? isSaving,
    String? validationError,
    int? remainingChars,
  }) {
    return SetNicknameState(
      nickname: nickname ?? this.nickname,
      canSave: canSave ?? this.canSave,
      isSaving: isSaving ?? this.isSaving,
      validationError: validationError ?? this.validationError,
      remainingChars: remainingChars ?? this.remainingChars,
    );
  }
}

/// 设置昵称 Provider
@riverpod
class SetNicknameNotifier extends _$SetNicknameNotifier {
  Timer? _debounce;
  String originalNickname = '';

  // 敏感词列表
  static const List<String> _sensitiveWords = [
    'admin',
    'administrator',
    'root',
    'system',
    'test',
    '管理员',
    '系统',
    '测试',
    '客服',
    '官方',
  ];

  @override
  SetNicknameState build() {
    _initData();
    return SetNicknameState(
      nickname: originalNickname,
      remainingChars: 24 - originalNickname.length,
    );
  }

  /// 初始化数据
  void _initData() {
    try {
      final userInfo = UserRepoLocal.to.current;
      if (userInfo.nickname.isNotEmpty) {
        originalNickname = userInfo.nickname;
      }
    } catch (e) {
      iPrint('加载昵称失败: $e');
    }
  }

  /// 昵称输入变化处理（带防抖）
  void onNicknameChanged(String value, WidgetRef ref) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _updateState(value, ref);
    });
  }

  /// 更新状态
  void _updateState(String value, WidgetRef ref) {
    final trimmedText = value.trim();
    String validationError = '';

    // 输入校验
    validationError = _validateNickname(value);

    final canSave = validationError.isEmpty && trimmedText != originalNickname;

    // 更新剩余字数
    final currentLength = value.length;
    final remainingChars = (24 - currentLength).clamp(0, 24);

    state = state.copyWith(
      nickname: value,
      canSave: canSave,
      validationError: validationError,
      remainingChars: remainingChars,
    );
  }

  /// 昵称输入校验
  String _validateNickname(String nickname) {
    final trimmed = nickname.trim();

    // 1. 长度校验
    if (trimmed.isEmpty) {
      return t.common.nicknameEmptyError;
    }

    if (trimmed.length < 2) {
      return t.common.nicknameLengthError;
    }

    if (nickname.length > 24) {
      return t.common.nicknameLengthError;
    }

    // 2. 空白字符校验
    if (trimmed != nickname || trimmed.isEmpty) {
      return t.common.nicknameWhitespaceError;
    }

    // 3. 仅表情符号校验
    if (_isOnlyEmojis(trimmed)) {
      return t.common.nicknameEmojiOnlyError;
    }

    // 4. 敏感词校验
    if (_containsSensitiveWords(trimmed)) {
      return t.common.nicknameSensitiveWordError;
    }

    return '';
  }

  /// 检测是否仅包含表情符号
  bool _isOnlyEmojis(String text) {
    final withoutEmojis = text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
        unicode: true,
      ),
      '',
    );
    return withoutEmojis.trim().isEmpty && text.trim().isNotEmpty;
  }

  /// 检测是否包含敏感词
  bool _containsSensitiveWords(String text) {
    final lowerText = text.toLowerCase();
    return _sensitiveWords.any(
      (word) => lowerText.contains(word.toLowerCase()),
    );
  }

  /// 保存昵称
  Future<bool> saveNickname(WidgetRef ref) async {
    final currentState = state;
    if (!currentState.canSave || currentState.isSaving) return false;

    final nickname = currentState.nickname.trim();

    // 最终校验
    final validation = _validateNickname(currentState.nickname);
    if (validation.isNotEmpty) {
      return false;
    }

    try {
      state = currentState.copyWith(isSaving: true);

      // 调用API更新昵称
      final result = await ref.read(personalInfoProvider.notifier).changeInfo({
        "field": "nickname",
        "value": nickname,
      });

      if (result) {
        // 更新本地用户信息
        await _updateLocalUserInfo(nickname);
        originalNickname = nickname;
        _updateState(nickname, ref);
        return true;
      } else {
        await _revertToOriginal(ref);
        return false;
      }
    } catch (e) {
      iPrint('保存昵称失败: $e');
      await _revertToOriginal(ref);
      return false;
    } finally {
      // 用最新 state（可能已被 _updateState/_revertToOriginal 更新）收尾，
      // 而非保存前捕获的 currentState 快照——否则会用过期数据覆盖刚写入的
      // 成功态/回滚态，导致失败回滚形同虚设（真 bug）。
      state = state.copyWith(isSaving: false);
    }
  }

  /// 更新本地用户信息
  Future<void> _updateLocalUserInfo(String nickname) async {
    try {
      final payload = UserRepoLocal.to.current.toMap();
      payload["nickname"] = nickname;
      UserRepoLocal.to.changeInfo(payload);
    } catch (e) {
      iPrint('更新本地用户信息失败: $e');
    }
  }

  /// 回滚到原始昵称
  Future<void> _revertToOriginal(WidgetRef ref) async {
    _updateState(originalNickname, ref);
  }

  /// 撤销操作
  void undoChanges(WidgetRef ref) {
    _revertToOriginal(ref);
  }
}

/// 文本控制器 Provider
final nicknameControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

/// 焦点节点 Provider
final nicknameFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode();
  ref.onDispose(() => node.dispose());
  return node;
});
