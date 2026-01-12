import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/personal_info/personal_info/personal_info_logic.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'set_nickname_state.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 设置昵称页面逻辑控制器
/// 
/// 功能特性：
/// - 输入校验：长度范围、空白字符、表情符号、敏感词检测
/// - 节流提交：防抖输入、防重复提交、loading状态管理
/// - 冲突处理：昵称重复、服务器错误、网络异常处理
/// - 失败回滚：保存失败时恢复原始值，保持数据一致性
/// - macOS 支持：回车提交、Cmd+Z 撤销、焦点管理
class SetNicknameLogic extends GetxController {
  final SetNicknameState state = SetNicknameState();

  // 文本控制器
  late TextEditingController nicknameController;
  
  // 焦点节点（支持 macOS 键盘导航）
  late FocusNode focusNode;
  
  // 响应式变量
  final RxBool canSave = false.obs;
  final RxBool isSaving = false.obs;
  final RxString validationError = ''.obs;

  // 原始昵称（用于回滚和变更检测）
  String originalNickname = '';

  // 剩余可输入字数（2-24）
  final RxInt remainingChars = 24.obs;
  
  // 输入防抖（500ms）
  Timer? _debounce;
  
  // 敏感词列表（简单本地检测，可扩展为服务器检测）
  static const List<String> _sensitiveWords = [
    'admin', 'administrator', 'root', 'system', 'test',
    '管理员', '系统', '测试', '客服', '官方'
  ];

  @override
  void onInit() {
    super.onInit();
    _initControllers();
    _loadCurrentNickname();
  }

  @override
  void onClose() {
    nicknameController.dispose();
    focusNode.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  /// 初始化控制器
  /// 用途：设置文本控制器、焦点节点和输入监听
  /// 参数：无
  /// 返回：void
  /// 异常：无
  void _initControllers() {
    nicknameController = TextEditingController();
    focusNode = FocusNode();
    
    // 监听输入框变化（带防抖）
    nicknameController.addListener(_onTextChanged);
  }

  /// 加载当前昵称
  /// 用途：从本地用户信息中获取当前昵称并初始化界面
  /// 参数：无
  /// 返回：\`Future<void>\`
  /// 异常：捕获并记录加载失败
  Future<void> _loadCurrentNickname() async {
    try {
      final userInfo = UserRepoLocal.to.current;
      if (userInfo.nickname.isNotEmpty) {
        originalNickname = userInfo.nickname;
        nicknameController.text = originalNickname;
        _updateState();
      }
    } catch (e) {
      iPrint('加载昵称失败: $e');
    }
  }

  /// 文本变化监听（带防抖）
  /// 用途：输入变化时延迟执行状态更新，避免频繁计算
  /// 参数：无
  /// 返回：void
  /// 异常：无
  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _updateState();
    });
  }

  /// 昵称输入变化处理（外部调用）
  /// 用途：提供给视图层的输入变化回调
  /// 参数：value 输入的文本值
  /// 返回：void
  /// 异常：无
  void onNicknameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _updateState();
    });
  }

  /// 更新状态
  /// 用途：根据当前输入内容更新保存按钮状态、剩余字数和校验错误
  /// 参数：无
  /// 返回：void
  /// 异常：无
  void _updateState() {
    final text = nicknameController.text;
    final trimmedText = text.trim();
    
    // 清空之前的错误信息
    validationError.value = '';
    
    // 输入校验
    final validation = _validateNickname(text);
    if (validation.isNotEmpty) {
      validationError.value = validation;
      canSave.value = false;
    } else {
      // 检查是否与原昵称不同
      canSave.value = trimmedText != originalNickname;
    }
    
    // 更新剩余字数（基于实际字符长度）
    final currentLength = text.length;
    remainingChars.value = (24 - currentLength).clamp(0, 24);
  }

  /// 昵称输入校验
  /// 用途：对输入的昵称进行完整性校验
  /// 参数：nickname 待校验的昵称
  /// 返回：\`String\` 错误信息，空字符串表示校验通过
  /// 异常：无
  String _validateNickname(String nickname) {
    final trimmed = nickname.trim();
    
    // 1. 长度校验
    if (trimmed.isEmpty) {
      return t.nicknameEmptyError;
    }
    
    if (trimmed.length < 2) {
      return t.nicknameLengthError;
    }
    
    if (nickname.length > 24) {
      return t.nicknameLengthError;
    }
    
    // 2. 空白字符校验
    if (trimmed != nickname || trimmed.isEmpty) {
      return t.nicknameWhitespaceError;
    }
    
    // 3. 仅表情符号校验（简单检测）
    if (_isOnlyEmojis(trimmed)) {
      return t.nicknameEmojiOnlyError;
    }
    
    // 4. 敏感词校验
    if (_containsSensitiveWords(trimmed)) {
      return t.nicknameSensitiveWordError;
    }
    
    return '';
  }

  /// 检测是否仅包含表情符号
  /// 用途：简单检测昵称是否仅由表情符号组成
  /// 参数：text 待检测文本
  /// 返回：\`bool\`
  /// 异常：无
  bool _isOnlyEmojis(String text) {
    // 简单的表情符号检测：如果去除所有 Unicode 表情符号后为空，则认为仅包含表情
    final withoutEmojis = text.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true), '');
    return withoutEmojis.trim().isEmpty && text.trim().isNotEmpty;
  }

  /// 检测是否包含敏感词
  /// 用途：本地敏感词检测，可扩展为服务器端检测
  /// 参数：text 待检测文本
  /// 返回：\`bool\`
  /// 异常：无
  bool _containsSensitiveWords(String text) {
    final lowerText = text.toLowerCase();
    return _sensitiveWords.any((word) => lowerText.contains(word.toLowerCase()));
  }

  /// 保存昵称（支持 macOS 回车提交）
  /// 用途：提交昵称修改请求，处理各种错误情况并提供用户反馈
  /// 参数：无
  /// 返回：\`Future<void>\`
  /// 异常：捕获网络异常、服务器错误等并提供相应提示
  Future<void> saveNickname() async {
    if (!canSave.value || isSaving.value) return;
    
    final nickname = nicknameController.text.trim();
    
    // 最终校验
    final validation = _validateNickname(nicknameController.text);
    if (validation.isNotEmpty) {
      Get.snackbar(t.tipTips, validation);
      return;
    }

    try {
      // 防重复提交
      isSaving.value = true;

      // 调用API更新昵称
      final result = await _updateNicknameAPI(nickname);
      
      if (result) {
        // 更新本地用户信息
        await _updateLocalUserInfo(nickname);
        
        originalNickname = nickname;
        _updateState();
        
        Get.snackbar(t.tipSuccess, t.nicknameUpdateSuccess);
        Get.back(result: true);
      } else {
        // 根据错误类型提供不同的提示
        await _handleSaveError('','SERVER_ERROR');
      }
    } catch (e) {
      iPrint('保存昵称失败: $e');
      await _revertToOriginal();
      Get.snackbar(t.tipFailed, t.nicknameNetworkError);
    } finally {
      isSaving.value = false;
    }
  }

  /// 更新本地用户信息
  /// 用途：保存成功后同步更新本地缓存的用户信息
  /// 参数：nickname 新昵称
  /// 返回：\`Future<void>\`
  /// 异常：捕获并记录更新失败
  Future<void> _updateLocalUserInfo(String nickname) async {
    try {
      Map<String, dynamic> payload = UserRepoLocal.to.current.toMap();
      payload["nickname"] = nickname;
      UserRepoLocal.to.changeInfo(payload);
      
      // TODO: 通知其他页面刷新用户昵称（如聊天界面、联系人列表等）
      // Get.find<UserController>().updateNickname(nickname);
      
    } catch (e) {
      iPrint('更新本地用户信息失败: $e');
    }
  }

  /// 处理保存错误
  /// 用途：根据不同的错误类型提供相应的用户提示和处理
  /// 参数：
  /// - errorCode 错误代码
  /// - errorMessage 错误消息
  /// 返回：\`Future<void>\`
  /// 异常：无
  Future<void> _handleSaveError(String errorCode, String errorMessage) async {
    await _revertToOriginal();
    
    switch (errorCode) {
      case 'NICKNAME_CONFLICT':
        Get.snackbar(t.tipFailed, t.nicknameConflictError);
        break;
      case 'NICKNAME_SENSITIVE':
        Get.snackbar(t.tipFailed, t.nicknameSensitiveWordError);
        break;
      case 'NICKNAME_INVALID':
        Get.snackbar(t.tipFailed, t.nicknameLengthError);
        break;
      case 'SERVER_ERROR':
        Get.snackbar(t.tipFailed, t.nicknameServerError);
        break;
      default:
        Get.snackbar(t.tipFailed, t.nicknameUpdateFailed);
        break;
    }
  }

  /// 回滚到原始昵称
  /// 用途：保存失败时恢复到进入页面前的昵称，保持数据一致性
  /// 参数：无
  /// 返回：\`Future<void>\`
  /// 异常：无
  Future<void> _revertToOriginal() async {
    nicknameController.text = originalNickname;
    _updateState();
  }

  /// 撤销操作（支持 macOS Cmd+Z）
  /// 用途：提供撤销功能，恢复到上一次的状态
  /// 参数：无
  /// 返回：void
  /// 异常：无
  void undoChanges() {
    _revertToOriginal();
  }

  /// 调用API更新昵称
  /// 用途：发送昵称更新请求到服务器
  /// 参数：nickname 新昵称
  /// 返回：\`Future<bool>\` API调用结果
  /// 异常：网络异常时抛出
  Future<bool> _updateNicknameAPI(String nickname) async {
    bool ok = await Get.find<PersonalInfoLogic>().changeInfo({
      "field": "nickname",
      "value": nickname,
    });
    return ok;
    // try {
    //   final response = await HttpClient().post(
    //     '/user/update_info',
    //     data: {
    //       'field': 'nickname',
    //       'value': nickname,
    //     },
    //   );
    //
    //   if (response.code == 0) {
    //     return _ApiResult(success: true);
    //   } else {
    //     // 根据服务器返回的错误码进行分类处理
    //     String errorCode = 'UNKNOWN_ERROR';
    //     if (response.data != null && response.data['error_code'] != null) {
    //       errorCode = response.data['error_code'].toString();
    //     }
    //
    //     return _ApiResult(
    //       success: false,
    //       errorCode: errorCode,
    //       errorMessage: response.msg ?? 'Unknown error',
    //     );
    //   }
    // } catch (e) {
    //   iPrint('更新昵称API调用失败: $e');
    //   rethrow;
    // }
  }
}
