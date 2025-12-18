import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'profile_logic.dart';
import 'profile_state.dart';
import 'widgets/avatar_editor_view.dart';
import 'widgets/profile_completion_widget.dart';
import 'widgets/privacy_settings_view.dart';

/// 个人信息页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  final logic = Get.put(ProfileLogic());
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  /// 初始化动画
  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 自定义AppBar
          _buildSliverAppBar(context),
          
          // 内容区域
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // 头像卡片
                    _buildAvatarCard(context),
                    
                    // 资料完善度卡片
                    const ProfileCompletionWidget(),
                    
                    // 基本信息分组
                    _buildBasicInfoGroup(context),
                    
                    // 联系信息分组
                    _buildContactInfoGroup(context),
                    
                    // 个人展示分组
                    _buildDisplayInfoGroup(context),
                    
                    // 扩展信息分组
                    _buildExtendedInfoGroup(context),
                    
                    // 功能分组
                    _buildFunctionGroup(context),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建SliverAppBar
  Widget _buildSliverAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark 
          ? AppColors.darkBackground 
          : AppColors.lightBackground,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          '个人信息',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Get.theme.primaryColor.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      actions: [
        // 刷新按钮
        Obx(() => IconButton(
          onPressed: logic.state.isLoading.value ? null : () {
            logic.onInit();
          },
          icon: logic.state.isLoading.value
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Get.theme.primaryColor,
                  ),
                )
              : Icon(
                  Icons.refresh,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
        )),
        
        // 更多操作按钮
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          onSelected: (value) {
            switch (value) {
              case 'share':
                _shareProfile();
                break;
              case 'export':
                _exportProfile();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 12),
                  Text('分享资料'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 12),
                  Text('导出资料'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建头像卡片
  Widget _buildAvatarCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像区域
          GestureDetector(
            onTap: () => logic.previewAvatar(),
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Get.theme.primaryColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Obx(() => Avatar(
                      imgUri: logic.state.avatar.value,
                    )),
                  ),
                ),
                
                // 上传状态指示器
                Obx(() => logic.state.isUploading.value
                    ? Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 昵称
                Obx(() => Text(
                  logic.state.nickname.value.isEmpty 
                      ? '未设置昵称' 
                      : logic.state.nickname.value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                )),
                
                const SizedBox(height: 4),
                
                // 账号
                Text(
                  'ID: ${UserRepoLocal.to.current.account}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 编辑头像按钮
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _editAvatar(),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('编辑头像', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建基本信息分组
  Widget _buildBasicInfoGroup(BuildContext context) {
    return _buildInfoGroup(
      context,
      title: '基本信息',
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.person_outline,
          iconColor: const Color(0xFF007AFF),
          title: '昵称',
          value: logic.state.nickname.value.isEmpty ? '未设置' : logic.state.nickname.value,
          onTap: () => _editNickname(),
        ),
        
        _buildInfoItem(
          context: context,
          icon: Icons.wc_outlined,
          iconColor: const Color(0xFFFF9500),
          title: '性别',
          value: logic.getGenderText(logic.state.gender.value),
          onTap: () => _editGender(),
        ),
        
        _buildInfoItem(
          context: context,
          icon: Icons.cake_outlined,
          iconColor: const Color(0xFFFF3B30),
          title: '生日',
          value: logic.state.birthday.value.isEmpty ? '未设置' : logic.state.birthday.value,
          onTap: () => _editBirthday(),
        ),
        
        _buildInfoItem(
          context: context,
          icon: Icons.location_on_outlined,
          iconColor: const Color(0xFF34C759),
          title: '地区',
          value: logic.formatRegion(logic.state.region.value),
          onTap: () => _editRegion(),
        ),
      ],
    );
  }

  /// 构建联系信息分组
  Widget _buildContactInfoGroup(BuildContext context) {
    return _buildInfoGroup(
      context,
      title: '联系信息',
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.email_outlined,
          iconColor: const Color(0xFF007AFF),
          title: '邮箱',
          value: logic.state.email.value.isEmpty ? '未设置' : logic.state.email.value,
          onTap: () => {},
          showArrow: false,
        ),
        
        _buildInfoItem(
          context: context,
          icon: Icons.phone_outlined,
          iconColor: const Color(0xFF34C759),
          title: '手机号',
          value: logic.state.mobile.value.isEmpty ? '未设置' : logic.state.mobile.value,
          onTap: () => {},
          showArrow: false,
        ),
      ],
    );
  }

  /// 构建个人展示分组
  Widget _buildDisplayInfoGroup(BuildContext context) {
    return _buildInfoGroup(
      context,
      title: '个人展示',
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.edit_outlined,
          iconColor: const Color(0xFFFF9500),
          title: '个性签名',
          value: logic.state.signature.value.isEmpty ? '未设置' : logic.state.signature.value,
          onTap: () => _editSignature(),
          maxLines: 2,
        ),
        
        _buildInfoItem(
          context: context,
          icon: Icons.wallpaper_outlined,
          iconColor: const Color(0xFF5856D6),
          title: '个人背景',
          value: '设置背景图片',
          onTap: () => _editBackground(),
        ),
      ],
    );
  }

  /// 构建扩展信息分组
  Widget _buildExtendedInfoGroup(BuildContext context) {
    return _buildInfoGroup(
      context,
      title: '扩展信息',
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.work_outline,
          iconColor: const Color(0xFF007AFF),
          title: '职业',
          value: logic.state.profession.value.isEmpty ? '未设置' : logic.state.profession.value,
          onTap: () => _editProfession(),
        ),
        
        _buildInfoItem(
          context: context,
          icon: Icons.school_outlined,
          iconColor: const Color(0xFF34C759),
          title: '学校',
          value: logic.state.school.value.isEmpty ? '未设置' : logic.state.school.value,
          onTap: () => _editSchool(),
        ),
        
        _buildInfoItem(
          context: context,
          icon: Icons.favorite_outline,
          iconColor: const Color(0xFFFF3B30),
          title: '兴趣爱好',
          value: logic.state.interests.value.isEmpty ? '未设置' : logic.state.interests.value,
          onTap: () => _editInterests(),
        ),
      ],
    );
  }

  /// 构建功能分组
  Widget _buildFunctionGroup(BuildContext context) {
    return _buildInfoGroup(
      context,
      title: '功能设置',
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.qr_code_2,
          iconColor: const Color(0xFF007AFF),
          title: '我的二维码',
          value: '',
          onTap: () => _showQRCode(),
          trailing: Icon(
            Icons.qr_code_2,
            color: Get.isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        
        _buildInfoItem(
          context: context,
          icon: Icons.privacy_tip_outlined,
          iconColor: const Color(0xFFFF9500),
          title: '隐私设置',
          value: '',
          onTap: () => Get.to(
            () => const PrivacySettingsPage(),
            transition: Transition.rightToLeft,
          ),
        ),
      ],
    );
  }

  /// 构建信息分组
  Widget _buildInfoGroup(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        
        // 信息项容器
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 0.5,
                offset: const Offset(0, 0.5),
              ),
            ],
          ),
          child: Column(
            children: children.asMap().entries.map((entry) {
              int index = entry.key;
              Widget child = entry.value;

              return Column(
                children: [
                  child,
                  if (index < children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Container(
                        height: 0.3,
                        color: AppColors.getDividerColor(
                          Theme.of(context).brightness,
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 构建信息项
  Widget _buildInfoItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
    Widget? trailing,
    bool showArrow = true,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),

              const SizedBox(width: 12),

              // 标题
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(width: 12),

              // 值或自定义组件
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (trailing != null)
                      trailing
                    else
                      Flexible(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: maxLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

              // 箭头图标
              if (showArrow) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.navigate_next,
                  color: isDark ? Colors.white54 : Colors.black54,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 编辑方法
  void _editAvatar() {
    Get.to(
      () => AvatarEditorPage(
        currentAvatar: logic.state.avatar.value,
        onAvatarChanged: (url) {
          logic.updateUserInfo('avatar', url);
        },
      ),
      transition: Transition.rightToLeft,
    )?.then((result) {
      if (result != null) {
        // 头像更新成功后刷新数据
      }
    });
  }

  void _editNickname() {
    // 实现昵称编辑逻辑
  }

  void _editGender() {
    // 实现性别编辑逻辑
  }

  void _editBirthday() {
    // 实现生日编辑逻辑
  }

  void _editRegion() {
    // 实现地区编辑逻辑
  }

  void _editSignature() {
    // 实现个性签名编辑逻辑
  }

  void _editBackground() {
    // 实现背景编辑逻辑
  }

  void _editProfession() {
    // 实现职业编辑逻辑
  }

  void _editSchool() {
    // 实现学校编辑逻辑
  }

  void _editInterests() {
    // 实现兴趣爱好编辑逻辑
  }

  void _showQRCode() {
    // 实现二维码显示逻辑
  }

  void _shareProfile() {
    // 实现分享资料逻辑
  }

  void _exportProfile() {
    // 实现导出资料逻辑
  }

  @override
  void dispose() {
    _animationController.dispose();
    Get.delete<ProfileLogic>();
    super.dispose();
  }
}