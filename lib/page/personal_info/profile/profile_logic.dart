import 'dart:io';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/model/user_model.dart';

import 'profile_state.dart';

/// 个人信息管理逻辑控制器
class ProfileLogic extends GetxController {
  final ProfileState state = ProfileState();
  final HttpClient httpclient = Get.put(HttpClient.client);
  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    _initUserData();
    _calculateCompleteness();
  }

  /// 初始化用户数据
  void _initUserData() {
    final user = UserRepoLocal.to.current;
    state.userModel.value = user;
    state.avatar.value = user.avatar;
    state.nickname.value = user.nickname;
    state.gender.value = user.gender;
    state.region.value = user.region;
    state.signature.value = user.sign;
    state.email.value = user.email;
    state.mobile.value = user.mobile;
  }

  /// 计算资料完善度
  void _calculateCompleteness() {
    int completedFields = 0;
    int totalFields = 8; // 总字段数

    // 检查各个字段是否完善
    if (state.avatar.value.isNotEmpty) completedFields++;
    if (state.nickname.value.isNotEmpty) completedFields++;
    if (state.gender.value > 0) completedFields++;
    if (state.region.value.isNotEmpty) completedFields++;
    if (state.signature.value.isNotEmpty) completedFields++;
    if (state.email.value.isNotEmpty) completedFields++;
    if (state.mobile.value.isNotEmpty) completedFields++;
    if (state.birthday.value.isNotEmpty) completedFields++;

    state.completeness.value = (completedFields / totalFields * 100).round();
    
    // 更新完善度等级
    if (state.completeness.value >= 80) {
      state.completenessLevel.value = '优秀';
      state.completenessColor.value = Colors.green;
    } else if (state.completeness.value >= 60) {
      state.completenessLevel.value = '良好';
      state.completenessColor.value = Colors.orange;
    } else {
      state.completenessLevel.value = '待完善';
      state.completenessColor.value = Colors.red;
    }
  }

  /// 更新用户信息
  Future<bool> updateUserInfo(String field, dynamic value) async {
    try {
      state.isLoading.value = true;
      
      IMBoyHttpResponse resp = await httpclient.put(
        API.userUpdate, 
        data: {"field": field, "value": value}
      );
      
      if (resp.ok) {
        // 更新本地数据
        Map<String, dynamic> payload = UserRepoLocal.to.current.toMap();
        payload[field] = value;
        UserRepoLocal.to.changeInfo(payload);
        
        // 更新状态
        switch (field) {
          case 'avatar':
            state.avatar.value = value;
            break;
          case 'nickname':
            state.nickname.value = value;
            break;
          case 'gender':
            state.gender.value = value;
            break;
          case 'region':
            state.region.value = value;
            break;
          case 'sign':
            state.signature.value = value;
            break;
          case 'email':
            state.email.value = value;
            break;
          case 'mobile':
            state.mobile.value = value;
            break;
          case 'birthday':
            state.birthday.value = value;
            break;
        }
        
        _calculateCompleteness();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('更新用户信息失败: $e');
      return false;
    } finally {
      state.isLoading.value = false;
    }
  }

  /// 选择头像来源
  Future<void> selectAvatarSource() async {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示器
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 拍照选项
              _buildBottomSheetOption(
                icon: Icons.camera_alt,
                title: '拍照',
                onTap: () => _pickImage(ImageSource.camera),
              ),
              
              const Divider(height: 1),
              
              // 相册选项
              _buildBottomSheetOption(
                icon: Icons.photo_library,
                title: '从相册选择',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              
              const Divider(height: 1),
              
              // 取消选项
              _buildBottomSheetOption(
                icon: Icons.close,
                title: '取消',
                onTap: () => Get.back(),
                isCancel: true,
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部弹窗选项
  Widget _buildBottomSheetOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isCancel = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isCancel ? Colors.grey : Get.theme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isCancel ? Colors.grey : Get.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      Get.back(); // 关闭底部弹窗
      
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        // 这里可以添加图片裁剪功能
        await _uploadAvatar(File(image.path));
      }
    } catch (e) {
      Get.snackbar('错误', '选择图片失败: $e');
    }
  }

  /// 上传头像
  Future<void> _uploadAvatar(File imageFile) async {
    try {
      state.isUploading.value = true;
      
      // 这里应该调用实际的上传接口
      // 暂时模拟上传成功
      await Future.delayed(const Duration(seconds: 2));
      
      // 模拟返回的头像URL
      String avatarUrl = 'https://example.com/avatar/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      bool success = await updateUserInfo('avatar', avatarUrl);
      if (success) {
        Get.snackbar('成功', '头像更新成功');
      } else {
        Get.snackbar('失败', '头像更新失败');
      }
    } catch (e) {
      Get.snackbar('错误', '上传头像失败: $e');
    } finally {
      state.isUploading.value = false;
    }
  }

  /// 预览头像
  void previewAvatar() {
    if (state.avatar.value.isEmpty) return;
    
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: Get.width * 0.8,
            height: Get.width * 0.8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: cachedImageProvider(state.avatar.value),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取性别文本
  String getGenderText(int gender) {
    switch (gender) {
      case 1:
        return '男';
      case 2:
        return '女';
      case 3:
        return '保密';
      default:
        return '未设置';
    }
  }

  /// 格式化地区显示
  String formatRegion(String region) {
    if (region.isEmpty) return '未设置';
    
    List<String> parts = region.split(' ');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]} ${parts[parts.length - 1]}';
    }
    return region;
  }

  /// 获取完善度建议
  List<String> getCompletionSuggestions() {
    List<String> suggestions = [];
    
    if (state.avatar.value.isEmpty) suggestions.add('设置头像');
    if (state.nickname.value.isEmpty) suggestions.add('设置昵称');
    if (state.gender.value == 0) suggestions.add('设置性别');
    if (state.region.value.isEmpty) suggestions.add('设置地区');
    if (state.signature.value.isEmpty) suggestions.add('设置个性签名');
    if (state.birthday.value.isEmpty) suggestions.add('设置生日');
    
    return suggestions;
  }

  @override
  void onClose() {
    super.onClose();
  }
}
