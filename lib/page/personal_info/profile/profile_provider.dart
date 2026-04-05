import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/i18n/strings.g.dart';

part 'profile_provider.g.dart';

/// 个人资料状态
class ProfileState {
  final UserModel userModel;
  final String avatar;
  final String nickname;
  final int gender;
  final String region;
  final String signature;
  final String email;
  final String mobile;
  final String birthday;

  // 扩展信息
  final String profession;
  final String school;
  final String interests;

  // 资料完善度
  final int completeness;
  final String completenessLevel;
  final Color completenessColor;

  // 隐私设置
  final bool allowSearch;
  final bool showOnlineStatus;
  final bool allowNearbyVisible;
  final bool allowAddByPhone;
  final bool allowAddByQR;

  // 加载状态
  final bool isLoading;
  final bool isUploading;

  ProfileState({
    UserModel? userModel,
    this.avatar = '',
    this.nickname = '',
    this.gender = 0,
    this.region = '',
    this.signature = '',
    this.email = '',
    this.mobile = '',
    this.birthday = '',
    this.profession = '',
    this.school = '',
    this.interests = '',
    this.completeness = 0,
    this.completenessLevel = '',
    this.completenessColor = Colors.red,
    this.allowSearch = true,
    this.showOnlineStatus = true,
    this.allowNearbyVisible = false,
    this.allowAddByPhone = true,
    this.allowAddByQR = true,
    this.isLoading = false,
    this.isUploading = false,
  }) : userModel = userModel ?? UserModel(uid: '', account: '');

  ProfileState copyWith({
    UserModel? userModel,
    String? avatar,
    String? nickname,
    int? gender,
    String? region,
    String? signature,
    String? email,
    String? mobile,
    String? birthday,
    String? profession,
    String? school,
    String? interests,
    int? completeness,
    String? completenessLevel,
    Color? completenessColor,
    bool? allowSearch,
    bool? showOnlineStatus,
    bool? allowNearbyVisible,
    bool? allowAddByPhone,
    bool? allowAddByQR,
    bool? isLoading,
    bool? isUploading,
  }) {
    return ProfileState(
      userModel: userModel ?? this.userModel,
      avatar: avatar ?? this.avatar,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      region: region ?? this.region,
      signature: signature ?? this.signature,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      birthday: birthday ?? this.birthday,
      profession: profession ?? this.profession,
      school: school ?? this.school,
      interests: interests ?? this.interests,
      completeness: completeness ?? this.completeness,
      completenessLevel: completenessLevel ?? this.completenessLevel,
      completenessColor: completenessColor ?? this.completenessColor,
      allowSearch: allowSearch ?? this.allowSearch,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowNearbyVisible: allowNearbyVisible ?? this.allowNearbyVisible,
      allowAddByPhone: allowAddByPhone ?? this.allowAddByPhone,
      allowAddByQR: allowAddByQR ?? this.allowAddByQR,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

/// 个人资料 Provider
@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  final HttpClient _httpclient = HttpClient.client;
  final ImagePicker _picker = ImagePicker();

  @override
  ProfileState build() {
    final user = UserRepoLocal.to.current;
    final setting = UserRepoLocal.to.setting;

    final initialState = ProfileState(
      userModel: user,
      avatar: user.avatar,
      nickname: user.nickname,
      gender: user.gender,
      region: user.region,
      signature: user.sign,
      email: user.email,
      mobile: user.mobile,
      // 从 UserSetting 初始化所有隐私设置字段
      allowSearch: setting.allowSearch,
      allowNearbyVisible: setting.peopleNearbyVisible,
      showOnlineStatus: setting.showOnlineStatus,
      allowAddByPhone: setting.allowAddByPhone,
      allowAddByQR: setting.allowAddByQR,
    );

    return _calculateCompleteness(initialState);
  }

  /// 刷新用户数据
  void refreshUserData() {
    final user = UserRepoLocal.to.current;
    final setting = UserRepoLocal.to.setting;

    state = ProfileState(
      userModel: user,
      avatar: user.avatar,
      nickname: user.nickname,
      gender: user.gender,
      region: user.region,
      signature: user.sign,
      email: user.email,
      mobile: user.mobile,
      // 从 UserSetting 刷新所有隐私设置字段
      allowSearch: setting.allowSearch,
      allowNearbyVisible: setting.peopleNearbyVisible,
      showOnlineStatus: setting.showOnlineStatus,
      allowAddByPhone: setting.allowAddByPhone,
      allowAddByQR: setting.allowAddByQR,
    );
    state = _calculateCompleteness(state);
  }

  /// 计算资料完善度
  ProfileState _calculateCompleteness(ProfileState currentState) {
    int completedFields = 0;
    int totalFields = 8; // 总字段数

    // 检查各个字段是否完善
    if (currentState.avatar.isNotEmpty) completedFields++;
    if (currentState.nickname.isNotEmpty) completedFields++;
    if (currentState.gender > 0) completedFields++;
    if (currentState.region.isNotEmpty) completedFields++;
    if (currentState.signature.isNotEmpty) completedFields++;
    if (currentState.email.isNotEmpty) completedFields++;
    if (currentState.mobile.isNotEmpty) completedFields++;
    if (currentState.birthday.isNotEmpty) completedFields++;

    final completeness = (completedFields / totalFields * 100).round();

    // 更新完善度等级
    String completenessLevel;
    Color completenessColor;
    if (completeness >= 80) {
      completenessLevel = t.good; // 使用 "很棒" / "Great"
      completenessColor = Colors.green;
    } else if (completeness >= 60) {
      completenessLevel = t.good; // 使用 "很棒" / "Great"
      completenessColor = Colors.orange;
    } else {
      completenessLevel = t.toBeCompleted;
      completenessColor = Colors.red;
    }

    return currentState.copyWith(
      completeness: completeness,
      completenessLevel: completenessLevel,
      completenessColor: completenessColor,
    );
  }

  /// 更新用户信息
  Future<bool> updateUserInfo(String field, dynamic value) async {
    try {
      state = state.copyWith(isLoading: true);

      IMBoyHttpResponse resp = await _httpclient.put(
        API.userUpdate,
        data: {"field": field, "value": value},
      );

      if (resp.ok) {
        // 更新本地数据
        Map<String, dynamic> payload = UserRepoLocal.to.current.toMap();

        // 隐私设置字段需要同时更新 setting 对象
        if ([
          'allow_search',
          'allow_add_by_phone',
          'allow_add_by_qr',
          'show_online_status',
          'allow_nearby_visible',
        ].contains(field)) {
          // 确保 setting 对象存在
          if (payload['setting'] == null) {
            payload['setting'] = <String, dynamic>{};
          } else if (payload['setting'] is! Map) {
            payload['setting'] = <String, dynamic>{};
          }
          // 更新 setting 中的字段
          (payload['setting'] as Map<String, dynamic>)[field] = value;
        } else {
          // 非隐私设置字段，更新顶层字段
          payload[field] = value;
        }

        UserRepoLocal.to.changeInfo(payload);

        // 更新状态
        switch (field) {
          case 'avatar':
            state = state.copyWith(avatar: value);
            break;
          case 'nickname':
            state = state.copyWith(nickname: value);
            break;
          case 'gender':
            state = state.copyWith(
              gender: value is int
                  ? value
                  : int.tryParse(value.toString()) ?? 0,
            );
            break;
          case 'region':
            state = state.copyWith(region: value);
            break;
          case 'sign':
            state = state.copyWith(signature: value);
            break;
          case 'email':
            state = state.copyWith(email: value);
            break;
          case 'mobile':
            state = state.copyWith(mobile: value);
            break;
          case 'birthday':
            state = state.copyWith(birthday: value);
            break;
          // 隐私设置字段
          case 'allow_search':
            state = state.copyWith(
              allowSearch: value is bool ? value : value == 1 || value == '1',
            );
            break;
          case 'allow_add_by_phone':
            state = state.copyWith(
              allowAddByPhone: value is bool
                  ? value
                  : value == 1 || value == '1',
            );
            break;
          case 'allow_add_by_qr':
            state = state.copyWith(
              allowAddByQR: value is bool ? value : value == 1 || value == '1',
            );
            break;
          case 'show_online_status':
            state = state.copyWith(
              showOnlineStatus: value is bool
                  ? value
                  : value == 1 || value == '1',
            );
            break;
          case 'allow_nearby_visible':
            state = state.copyWith(
              allowNearbyVisible: value is bool
                  ? value
                  : value == 1 || value == '1',
            );
            break;
        }

        state = _calculateCompleteness(state);
        return true;
      }
      return false;
    } catch (e) {
      iPrint('更新用户信息失败: $e');
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 修改用户信息的便捷方法
  /// 
  /// 参数 data 格式: {"field": "字段名", "value": "值"}
  /// 返回: 成功返回 true，失败返回 false
  Future<bool> changeInfo(Map<String, dynamic> data) async {
    final field = data['field'] as String?;
    final value = data['value'];
    
    if (field == null) {
      iPrint('changeInfo: field 不能为空');
      return false;
    }
    
    return updateUserInfo(field, value);
  }

  /// 选择图片
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      iPrint('选择图片失败: $e');
      return null;
    }
  }

  /// 上传头像
  Future<bool> uploadAvatar(File imageFile) async {
    try {
      state = state.copyWith(isUploading: true);

      final Completer<bool> completer = Completer<bool>();
      String? avatarUrl;

      await AttachmentApi.uploadFile(
        'avatar',
        imageFile,
        (Map<String, dynamic> resp, String url) async {
          final status = resp['status'] ?? '';
          if (status == 'ok') {
            avatarUrl = url;
          }
          completer.complete(status == 'ok');
        },
        (e) {
          iPrint('上传头像失败: $e');
          completer.complete(false);
        },
        process: true,
      );

      final uploaded = await completer.future;
      if (!uploaded || avatarUrl == null) return false;

      return await updateUserInfo('avatar', avatarUrl!);
    } catch (e) {
      iPrint('上传头像失败: $e');
      return false;
    } finally {
      state = state.copyWith(isUploading: false);
    }
  }

  /// 上传背景图片
  ///
  /// [imagePath] 图片本地路径
  /// Returns: 上传成功返回 true，否则返回 false
  Future<bool> uploadBackground(String imagePath) async {
    try {
      state = state.copyWith(isUploading: true);

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        iPrint('背景图片文件不存在: $imagePath');
        return false;
      }

      // 使用 AttachmentApi 上传文件
      Completer<bool> completer = Completer<bool>();
      String? backgroundUrl;

      await AttachmentApi.uploadFile(
        'background',
        imageFile,
        (Map<String, dynamic> resp, String url) {
          String status = resp['status'] ?? '';
          if (status == 'ok') {
            backgroundUrl = url;
            iPrint('背景图片上传成功: $backgroundUrl');
            completer.complete(true);
          } else {
            iPrint('背景图片上传失败: ${resp['message'] ?? '未知错误'}');
            completer.complete(false);
          }
        },
        (error) {
          iPrint('背景图片上传异常: $error');
          completer.complete(false);
        },
        process: true,
      );

      // 等待上传完成
      final uploadSuccess = await completer.future;

      if (!uploadSuccess || backgroundUrl == null) {
        return false;
      }

      // 更新背景图片字段到用户信息
      bool success = await changeInfo({
        "field": "background",
        "value": backgroundUrl,
      });

      if (success) {
        // 更新本地用户信息
        final payload = UserRepoLocal.to.current.toMap();
        payload['background'] = backgroundUrl;
        UserRepoLocal.to.changeInfo(payload);
      }

      return success;
    } catch (e) {
      iPrint('上传背景图片失败: $e');
      return false;
    } finally {
      state = state.copyWith(isUploading: false);
    }
  }

  /// 获取性别文本
  String getGenderText(int gender) {
    switch (gender) {
      case 1:
        return t.male;
      case 2:
        return t.female;
      case 3:
        return t.secret;
      default:
        return t.notSet;
    }
  }

  /// 格式化地区显示
  String formatRegion(String region) {
    if (region.isEmpty) return t.notSet;

    List<String> parts = region.split(' ');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]} ${parts[parts.length - 1]}';
    }
    return region;
  }

  /// 获取完善度建议
  List<String> getCompletionSuggestions() {
    List<String> suggestions = [];

    if (state.avatar.isEmpty) suggestions.add(t.setAvatar);
    if (state.nickname.isEmpty) suggestions.add(t.setNickname);
    if (state.gender == 0) suggestions.add(t.setGender);
    if (state.region.isEmpty) suggestions.add(t.setRegion);
    if (state.signature.isEmpty) suggestions.add(t.setSignature);
    if (state.birthday.isEmpty) suggestions.add(t.setBirthday);

    return suggestions;
  }
}
