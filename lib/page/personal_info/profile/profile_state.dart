import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/store/model/user_model.dart';

/// 个人信息管理状态
class ProfileState {
  // 用户模型
  Rx<UserModel> userModel = UserModel(uid: '', account: '').obs;
  
  // 基础信息
  RxString avatar = ''.obs;
  RxString nickname = ''.obs;
  RxInt gender = 0.obs;
  RxString region = ''.obs;
  RxString signature = ''.obs;
  RxString email = ''.obs;
  RxString mobile = ''.obs;
  RxString birthday = ''.obs;
  
  // 扩展信息
  RxString profession = ''.obs;
  RxString school = ''.obs;
  RxString interests = ''.obs;
  
  // 资料完善度
  RxInt completeness = 0.obs;
  RxString completenessLevel = '待完善'.obs;
  Rx<Color> completenessColor = Colors.red.obs;
  
  // 隐私设置
  RxBool allowSearch = true.obs;
  RxBool showOnlineStatus = true.obs;
  RxBool allowNearbyVisible = false.obs;
  RxBool allowAddByPhone = true.obs;
  RxBool allowAddByQR = true.obs;
  
  // 加载状态
  RxBool isLoading = false.obs;
  RxBool isUploading = false.obs;
  
  // 页面状态
  RxInt currentTabIndex = 0.obs;
  
  ProfileState();
}