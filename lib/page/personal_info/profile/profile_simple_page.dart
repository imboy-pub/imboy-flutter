import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/personal_info/set_nickname/set_nickname_page.dart';
import 'package:imboy/page/personal_info/set_gender/set_gender_page.dart';
import 'package:imboy/page/personal_info/update/update_page.dart';
import 'package:imboy/page/personal_info/set_region/set_region_page.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 个人信息管理页面
class ProfileSimplePage extends StatefulWidget {
  const ProfileSimplePage({super.key});

  @override
  State<ProfileSimplePage> createState() => _ProfileSimplePageState();
}

class _ProfileSimplePageState extends State<ProfileSimplePage>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _completeness = 0;
  String _completenessLevel = t.toBeCompleted;
  Color _completenessColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _calculateCompleteness();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  void _calculateCompleteness() {
    final user = UserRepoLocal.to.current;
    final completedFields = [
      user.avatar.isNotEmpty,
      user.nickname.isNotEmpty,
      user.gender > 0,
      user.region.isNotEmpty,
      user.sign.isNotEmpty,
      user.email.isNotEmpty,
    ].where((e) => e).length;

    setState(() {
      _completeness = (completedFields / 6 * 100).round();

      if (_completeness >= 80) {
        _completenessLevel = '优秀';
        _completenessColor = Colors.green;
      } else if (_completeness >= 60) {
        _completenessLevel = '良好';
        _completenessColor = Colors.orange;
      } else {
        _completenessLevel = t.toBeCompleted;
        _completenessColor = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    _buildCompletenessCard(context),

                    // 基本信息分组
                    _buildBasicInfoGroup(context),

                    // 联系信息分组
                    _buildContactInfoGroup(context),

                    // 个人展示分组
                    _buildDisplayInfoGroup(context),

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
          ? const Color(0xFF1E1E1E).withValues(alpha: 0.75)
          : Colors.white.withValues(alpha: 0.75),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: FlexibleSpaceBar(
            title: Text(
              t.personalInfo,
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
                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        // 刷新按钮
        IconButton(
          onPressed: () {
            _calculateCompleteness();
            setState(() {});
          },
          icon: Icon(
            Icons.refresh,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),

        // 更多操作按钮
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          onSelected: (value) {
            switch (value) {
              case 'privacy':
                _showPrivacySettings();
                break;
              case 'share':
                _shareProfile();
                break;
              case 'export':
                _exportProfile();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'privacy',
              child: ListTile(
                leading: Icon(Icons.privacy_tip),
                title: Text(t.privacySettings),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text(t.profileShareProfile),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.file_download),
                title: Text(t.profileExportProfile),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建头像卡片
  Widget _buildAvatarCard(BuildContext context) {
    final user = UserRepoLocal.to.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: AppRadius.borderRadiusRegular,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // 头像
          GestureDetector(
            onTap: _previewAvatar,
            child: Hero(
              tag: 'avatar',
              child: Avatar(imgUri: user.avatar, width: 80, height: 80),
            ),
          ),

          const SizedBox(width: 16),

          // 基本信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname.isEmpty ? t.nicknameNotSet : user.nickname,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'ID: ${user.account}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),

                const SizedBox(height: 8),

                // 在线状态
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '在线',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 编辑按钮
          IconButton(
            onPressed: _chooseAvatar,
            icon: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
          ),
        ],
      ),
    );
  }

  /// 构建资料完善度卡片
  Widget _buildCompletenessCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
            Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.profileCompleteness,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _completenessColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusMedium,
                ),
                child: Text(
                  _completenessLevel,
                  style: TextStyle(
                    fontSize: 12,
                    color: _completenessColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 进度条
          LinearProgressIndicator(
            value: _completeness / 100,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(_completenessColor),
          ),

          const SizedBox(height: 8),

          Text(
            '$_completeness% 已完成',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建基本信息分组
  Widget _buildBasicInfoGroup(BuildContext context) {
    final user = UserRepoLocal.to.current;

    return _buildInfoGroup(
      context,
      title: t.basicInfo,
      icon: Icons.person,
      items: [
        _buildInfoItem(
          context,
          icon: Icons.badge,
          title: t.nickname,
          subtitle: user.nickname.isEmpty ? t.notSet : user.nickname,
          onTap: _editNickname,
        ),
        _buildInfoItem(
          context,
          icon: Icons.wc,
          title: t.gender,
          subtitle: _getGenderText(user.gender),
          onTap: _editGender,
        ),
        _buildInfoItem(
          context,
          icon: Icons.location_on,
          title: t.region,
          subtitle: _formatRegion(user.region),
          onTap: _editRegion,
        ),
      ],
    );
  }

  /// 构建联系信息分组
  Widget _buildContactInfoGroup(BuildContext context) {
    final user = UserRepoLocal.to.current;

    return _buildInfoGroup(
      context,
      title: t.contactInfo,
      icon: Icons.contact_mail,
      items: [
        _buildInfoItem(
          context,
          icon: Icons.email,
          title: t.email,
          subtitle: user.email.isEmpty ? t.notBound : user.email,
          onTap: () {
            // TODO: 实现邮箱编辑
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t.emailEditFeaturePending)));
          },
        ),
      ],
    );
  }

  /// 构建个人展示分组
  Widget _buildDisplayInfoGroup(BuildContext context) {
    final user = UserRepoLocal.to.current;

    return _buildInfoGroup(
      context,
      title: t.personalDisplay,
      icon: Icons.info,
      items: [
        _buildInfoItem(
          context,
          icon: Icons.format_quote,
          title: t.personalSignature,
          subtitle: user.sign.isEmpty ? t.lazyUserNoSignature : user.sign,
          onTap: _editSignature,
          maxLines: 2,
        ),
      ],
    );
  }

  /// 构建功能分组
  Widget _buildFunctionGroup(BuildContext context) {
    return _buildInfoGroup(
      context,
      title: t.functionSettings,
      icon: Icons.settings,
      items: [
        _buildInfoItem(
          context,
          icon: Icons.privacy_tip,
          title: t.privacySettings,
          subtitle: t.manageVisibility,
          onTap: _showPrivacySettings,
          showArrow: true,
        ),
        _buildInfoItem(
          context,
          icon: Icons.share,
          title: t.shareProfile,
          subtitle: t.shareWithFriends,
          onTap: _shareProfile,
          showArrow: true,
        ),
        _buildInfoItem(
          context,
          icon: Icons.file_download,
          title: t.exportProfile,
          subtitle: t.exportToLocal,
          onTap: _exportProfile,
          showArrow: true,
        ),
      ],
    );
  }

  /// 构建信息分组容器
  Widget _buildInfoGroup(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: AppRadius.borderRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // 分割线
          Divider(
            height: 1,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),

          // 列表项
          ...items,
        ],
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int maxLines = 1,
    bool showArrow = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusSmall,
              ),
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
            ),

            const SizedBox(width: 12),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 箭头
            if (showArrow)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
          ],
        ),
      ),
    );
  }

  /// 获取性别文本
  String _getGenderText(int gender) {
    switch (gender) {
      case 1:
        return '男';
      case 2:
        return '女';
      default:
        return t.notSet;
    }
  }

  /// 选择头像
  void _chooseAvatar() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),
              const SizedBox(height: 20),

              _buildBottomSheetItem(
                context,
                icon: Icons.camera_alt,
                title: t.camera,
                onTap: () => _pickImage(ImageSource.camera),
              ),

              _buildBottomSheetItem(
                context,
                icon: Icons.photo_library,
                title: t.selectFromAlbum,
                onTap: () => _pickImage(ImageSource.gallery),
              ),

              _buildBottomSheetItem(
                context,
                icon: Icons.cancel,
                title: t.buttonCancel,
                onTap: () => Navigator.of(context).pop(),
                isCancel: true,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部弹窗项
  Widget _buildBottomSheetItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isCancel = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isCancel ? Colors.grey : Theme.of(context).primaryColor,
          borderRadius: AppRadius.borderRadiusMedium,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isCancel
                    ? Colors.grey
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择图片
  void _pickImage(ImageSource source) async {
    try {
      Navigator.of(context).pop(); // 关闭底部弹窗

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        // TODO: 实现图片上传
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.avatarSelectedUploadPending)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.selectImageFailedWithError}: $e')),
      );
    }
  }

  /// 编辑昵称
  void _editNickname() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const SetNicknamePage()),
    ).then((result) {
      if (result == true) {
        _calculateCompleteness();
        setState(() {});
      }
    });
  }

  /// 编辑性别
  void _editGender() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const SetGenderPage()),
    ).then((result) {
      if (result == true) {
        _calculateCompleteness();
        setState(() {});
      }
    });
  }

  /// 编辑地区
  void _editRegion() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => SetRegionPage(
          title: t.setRegion,
          currentValue: UserRepoLocal.to.current.region,
          onSave: (region) async {
            // TODO: 实现地区更新逻辑
            return true;
          },
        ),
      ),
    );
  }

  /// 编辑个性签名
  void _editSignature() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => UpdatePage(
          title: t.setSignature,
          value: UserRepoLocal.to.current.sign,
          field: 'text',
          callback: (sign) async {
            // TODO: 实现签名更新逻辑
            return true;
          },
        ),
      ),
    );
  }

  /// 预览头像
  void _previewAvatar() {
    final user = UserRepoLocal.to.current;
    if (user.avatar.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderRadiusMedium,
              image: DecorationImage(
                image: cachedImageProvider(user.avatar),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示隐私设置
  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.privacySettings),
        content: Text(t.featureInDevelopment),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.buttonOk),
          ),
        ],
      ),
    );
  }

  /// 分享资料
  void _shareProfile() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.featureInDevelopment)));
  }

  /// 导出资料
  void _exportProfile() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.featureInDevelopment)));
  }

  /// 格式化地区显示
  String _formatRegion(String region) {
    if (region.isEmpty) return t.notSet;

    List<String> parts = region.split(' ');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]} ${parts[parts.length - 1]}';
    }
    return region;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
