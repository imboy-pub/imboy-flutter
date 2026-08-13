import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

part 'profile_provider.g.dart';

/// 个人资料状态
class ProfileState {
  final UserModel userModel;
  final String avatar;
  final String background;
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
    this.background = '',
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
    this.completenessColor = AppColors.iosRed,
    this.allowSearch = true,
    this.showOnlineStatus = false,
    this.allowNearbyVisible = false,
    this.allowAddByPhone = true,
    this.allowAddByQR = true,
    this.isLoading = false,
    this.isUploading = false,
  }) : userModel = userModel ?? UserModel(uid: '', account: '');

  ProfileState copyWith({
    UserModel? userModel,
    String? avatar,
    String? background,
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
      background: background ?? this.background,
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
  @override
  ProfileState build() {
    final user = UserRepoLocal.to.current;
    final setting = UserRepoLocal.to.setting;

    final initialState = ProfileState(
      userModel: user,
      avatar: user.avatar,
      background: user.background,
      nickname: user.nickname,
      gender: user.gender,
      birthday: user.birthday,
      region: user.region,
      signature: user.sign,
      email: user.email,
      mobile: user.mobile,
      profession: user.profession,
      school: user.school,
      interests: user.interests,
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
      background: user.background,
      nickname: user.nickname,
      gender: user.gender,
      birthday: user.birthday,
      region: user.region,
      signature: user.sign,
      email: user.email,
      mobile: user.mobile,
      profession: user.profession,
      school: user.school,
      interests: user.interests,
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
      completenessLevel = t.main.good; // 使用 "很棒" / "Great"
      completenessColor = AppColors.iosGreen;
    } else if (completeness >= 60) {
      completenessLevel = t.main.good; // 使用 "很棒" / "Great"
      completenessColor = AppColors.iosOrange;
    } else {
      completenessLevel = t.main.toBeCompleted;
      completenessColor = AppColors.iosRed;
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

      // 统一走 UserProfileService：PUT 更新 + 本地缓存同步（含 setting 字段归属处理），
      // 与 PersonalInfoPage 共用同一实现，避免双入口逻辑漂移。
      final ok = await UserProfileService.updateField(field, value);

      if (ok) {
        // 更新内存状态
        switch (field) {
          case 'avatar':
            state = state.copyWith(avatar: value as String?);
            break;
          case 'background':
            state = state.copyWith(background: value as String?);
            break;
          case 'nickname':
            state = state.copyWith(nickname: value as String?);
            break;
          case 'gender':
            state = state.copyWith(
              gender: value is int
                  ? value
                  : int.tryParse(value.toString()) ?? 0,
            );
            break;
          case 'region':
            state = state.copyWith(region: value as String?);
            break;
          case 'sign':
            state = state.copyWith(signature: value as String?);
            break;
          case 'email':
            state = state.copyWith(email: value as String?);
            break;
          case 'mobile':
            state = state.copyWith(mobile: value as String?);
            break;
          case 'birthday':
            state = state.copyWith(birthday: value as String?);
            break;
          case 'profession':
            state = state.copyWith(profession: value as String?);
            break;
          case 'school':
            state = state.copyWith(school: value as String?);
            break;
          case 'interests':
            state = state.copyWith(interests: value as String?);
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
      iPrint('更新用户信息失败: ${e.runtimeType}');
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

  /// 相机拍照
  Future<File?> pickCamera(BuildContext context) async {
    try {
      final media = await CapabilityLocator.I
          .get<MediaPickerCapability>()
          .pickCamera(context);
      return media != null ? File(media.path) : null;
    } catch (e) {
      iPrint('拍照失败: ${e.runtimeType}');
      return null;
    }
  }

  /// 选择图片
  Future<File?> pickImage(BuildContext context) async {
    try {
      final media = await CapabilityLocator.I
          .get<MediaPickerCapability>()
          .pickSingle(context, MediaType.image);
      return media != null ? File(media.path) : null;
    } catch (e) {
      iPrint('选择图片失败: ${e.runtimeType}');
      return null;
    }
  }

  /// 上传头像
  Future<bool> uploadAvatar(File imageFile) async {
    try {
      state = state.copyWith(isUploading: true);

      final Completer<bool> completer = Completer<bool>();
      String? avatarUrl;

      await AttachmentApi.uploadFileViaPresignCompat(
        'avatar',
        imageFile,
        (Map<String, dynamic> resp, String url) async {
          final status = resp['status'] ?? '';
          if (status == 'ok') {
            // 头像为公共资源（scope=public），url 为 object_key（方案 B，
            // 见 resource-access-control.md §9），直接作为 user.avatar 值。
            avatarUrl = url;
          }
          completer.complete(status == 'ok');
        },
        (Object e) {
          iPrint('上传头像失败: ${e.runtimeType}');
          completer.complete(false);
        },
        process: true,
        // 头像走公开读桶：scope=public，无 scope_ref。
        scope: 'public',
      );

      final uploaded = await completer.future;
      if (!uploaded || avatarUrl == null) return false;

      // 统一走 confirm 链路落库 + 更新 user.avatar，禁止旁路写 avatar。
      return await updateUserInfo('avatar', avatarUrl!);
    } catch (e) {
      iPrint('上传头像失败: ${e.runtimeType}');
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
        iPrint('背景图片文件不存在');
        return false;
      }

      // 使用 AttachmentApi 上传文件
      Completer<bool> completer = Completer<bool>();
      String? backgroundUrl;

      await AttachmentApi.uploadFileViaPresignCompat(
        'background',
        imageFile,
        (Map<String, dynamic> resp, String url) {
          String status = resp['status'] as String? ?? '';
          if (status == 'ok') {
            backgroundUrl = url;
            iPrint('背景图片上传成功');
            completer.complete(true);
          } else {
            iPrint('背景图片上传失败');
            completer.complete(false);
          }
        },
        (Object error) {
          iPrint('背景图片上传异常: ${error.runtimeType}');
          completer.complete(false);
        },
        process: true,
        // 背景图为公共资源（scope=public），url 为 object_key（方案 B），
        // 与 avatar 同机制：他人查看资料页时经 AssetsService.viewUrl 授权渲染。
        // 若走 private 桶，他人侧 presign 无法授权（仅 owner 可）。
        scope: 'public',
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
      iPrint('上传背景图片失败: ${e.runtimeType}');
      return false;
    } finally {
      state = state.copyWith(isUploading: false);
    }
  }

  /// 获取性别文本
  String getGenderText(int gender) {
    switch (gender) {
      case 1:
        return t.main.male;
      case 2:
        return t.main.female;
      case 3:
        return t.main.secret;
      default:
        return t.common.notSet;
    }
  }

  /// 格式化地区显示
  String formatRegion(String region) {
    if (region.isEmpty) return t.common.notSet;

    List<String> parts = region.split(' ');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]} ${parts[parts.length - 1]}';
    }
    return region;
  }

  /// 获取完善度建议。
  ///
  /// 返回 (key, label)：label 用于展示，key 用于让 profile_page 分发到对应编辑入口
  /// —— 建议 chip 此前是纯展示，点了没反应。key 不参与展示，故不需要 i18n。
  List<ProfileSuggestion> getCompletionSuggestions() {
    return [
      if (state.avatar.isEmpty) (key: 'avatar', label: t.chat.setAvatar),
      if (state.nickname.isEmpty)
        (key: 'nickname', label: t.account.setNickname),
      if (state.gender == 0) (key: 'gender', label: t.account.setGender),
      if (state.region.isEmpty) (key: 'region', label: t.common.setRegion),
      if (state.signature.isEmpty)
        (key: 'signature', label: t.chat.setSignature),
      if (state.birthday.isEmpty)
        (key: 'birthday', label: t.account.setBirthday),
    ];
  }
}

/// 完善度建议项：`key` 是稳定标识（用于跳转分发），`label` 是已本地化的展示文案。
typedef ProfileSuggestion = ({String key, String label});
