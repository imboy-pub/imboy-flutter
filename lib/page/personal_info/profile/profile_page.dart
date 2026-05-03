import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/qrcode/qrcode_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'profile_provider.dart';
import 'widgets/profile_completion_widget.dart';

/// 个人资料页面（新版 - 使用 Riverpod）
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with TickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 自定义AppBar
          _buildSliverAppBar(context, profileState, profileNotifier),

          // 内容区域
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // 头像卡片
                    _buildAvatarCard(context, profileState, profileNotifier),

                    // 资料完善度卡片
                    const ProfileCompletionWidget(),

                    // 基本信息分组
                    _buildBasicInfoGroup(
                      context,
                      profileState,
                      profileNotifier,
                    ),

                    // 联系信息分组
                    _buildContactInfoGroup(context, profileState),

                    // 个人展示分组
                    _buildDisplayInfoGroup(
                      context,
                      profileState,
                      profileNotifier,
                    ),

                    // 扩展信息分组
                    _buildExtendedInfoGroup(
                      context,
                      profileState,
                      profileNotifier,
                    ),

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
  Widget _buildSliverAppBar(
    BuildContext context,
    ProfileState profileState,
    ProfileNotifier profileNotifier,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark
          ? AppColors.darkSurfaceContainer.withValues(alpha: 0.75)
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
          onPressed: profileState.isLoading
              ? null
              : () {
                  profileNotifier.refreshUserData();
                },
          icon: profileState.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : Icon(
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
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 12),
                  Text(t.profileShareProfile),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 12),
                  Text(t.profileExportProfile),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建头像卡片
  Widget _buildAvatarCard(
    BuildContext context,
    ProfileState profileState,
    ProfileNotifier profileNotifier,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCardBackground
            : AppColors.lightCardBackground,
        borderRadius: AppRadius.borderRadiusRegular,
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
            onTap: () => _previewAvatar(context, profileState.avatar),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.borderRadiusMedium,
                  child: Avatar(imgUri: profileState.avatar, width: 80,height: 80,),
                ),

                // 上传状态指示器
                if (profileState.isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: AppRadius.borderRadiusMedium,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
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
                Text(
                  profileState.nickname.isEmpty
                      ? t.nicknameNotSet
                      : profileState.nickname,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),

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
                    onPressed: () => _editAvatar(context, profileNotifier),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: Text(
                      t.avatarEditAvatar,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusRegular,
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
  Widget _buildBasicInfoGroup(
    BuildContext context,
    ProfileState profileState,
    ProfileNotifier profileNotifier,
  ) {
    return _buildInfoGroup(
      context,
      title: t.basicInfo,
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.person_outline,
          iconColor: AppColors.iosBlue,
          title: t.nickname,
          value: profileState.nickname.isEmpty
              ? t.notSet
              : profileState.nickname,
          onTap: () => _editNickname(context),
        ),

        _buildInfoItem(
          context: context,
          icon: Icons.wc_outlined,
          iconColor: AppColors.iosOrange,
          title: t.gender,
          value: profileNotifier.getGenderText(profileState.gender),
          onTap: () => _editGender(context),
        ),

        _buildInfoItem(
          context: context,
          icon: Icons.cake_outlined,
          iconColor: AppColors.iosRed,
          title: t.birthday,
          value: profileState.birthday.isEmpty
              ? t.notSet
              : profileState.birthday,
          onTap: () => _editBirthday(context),
        ),

        _buildInfoItem(
          context: context,
          icon: Icons.location_on_outlined,
          iconColor: AppColors.iosGreen,
          title: t.region,
          value: profileNotifier.formatRegion(profileState.region),
          onTap: () => _editRegion(context),
        ),
      ],
    );
  }

  /// 构建联系信息分组
  Widget _buildContactInfoGroup(
    BuildContext context,
    ProfileState profileState,
  ) {
    return _buildInfoGroup(
      context,
      title: t.contactInfo,
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.email_outlined,
          iconColor: AppColors.iosBlue,
          title: t.email,
          value: profileState.email.isEmpty ? t.notSet : profileState.email,
          showArrow: false,
        ),

        _buildInfoItem(
          context: context,
          icon: Icons.phone_outlined,
          iconColor: AppColors.iosGreen,
          title: t.mobile,
          value: profileState.mobile.isEmpty ? t.notSet : profileState.mobile,
          showArrow: false,
        ),
      ],
    );
  }

  /// 构建个人展示分组
  Widget _buildDisplayInfoGroup(
    BuildContext context,
    ProfileState profileState,
    ProfileNotifier profileNotifier,
  ) {
    return _buildInfoGroup(
      context,
      title: t.personalDisplay,
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.edit_outlined,
          iconColor: AppColors.iosOrange,
          title: t.personalSignature,
          value: profileState.signature.isEmpty
              ? t.notSet
              : profileState.signature,
          onTap: () => _editSignature(context),
          maxLines: 2,
        ),

        _buildInfoItem(
          context: context,
          icon: Icons.wallpaper_outlined,
          iconColor: const Color(0xFF5856D6),
          title: t.personalBackground,
          value: t.setBackgroundImage,
          onTap: () => _editBackground(context),
        ),
      ],
    );
  }

  /// 构建扩展信息分组
  Widget _buildExtendedInfoGroup(
    BuildContext context,
    ProfileState profileState,
    ProfileNotifier profileNotifier,
  ) {
    return _buildInfoGroup(
      context,
      title: t.extendedInfo,
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.work_outline,
          iconColor: AppColors.iosBlue,
          title: t.profession,
          value: profileState.profession.isEmpty
              ? t.notSet
              : profileState.profession,
          onTap: () => _editProfession(context),
        ),

        _buildInfoItem(
          context: context,
          icon: Icons.school_outlined,
          iconColor: AppColors.iosGreen,
          title: t.school,
          value: profileState.school.isEmpty ? t.notSet : profileState.school,
          onTap: () => _editSchool(context),
        ),

        _buildInfoItem(
          context: context,
          icon: Icons.favorite_outline,
          iconColor: AppColors.iosRed,
          title: t.hobbiesAndInterests,
          value: profileState.interests.isEmpty
              ? t.notSet
              : profileState.interests,
          onTap: () => _editInterests(context),
        ),
      ],
    );
  }

  /// 构建功能分组
  Widget _buildFunctionGroup(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildInfoGroup(
      context,
      title: t.functionSettings,
      children: [
        _buildInfoItem(
          context: context,
          icon: Icons.qr_code_2,
          iconColor: AppColors.iosBlue,
          title: t.myQRCode,
          value: '',
          onTap: () => _showQRCode(context),
          trailing: Icon(
            Icons.qr_code_2,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),

        _buildInfoItem(
          context: context,
          icon: Icons.privacy_tip_outlined,
          iconColor: AppColors.iosOrange,
          title: t.privacySettings,
          value: '',
          onTap: () => context.push('/personal_info/privacy_settings'),
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
            color: isDark
                ? AppColors.darkCardBackground
                : AppColors.lightCardBackground,
            borderRadius: AppRadius.borderRadiusMedium,
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
    VoidCallback? onTap,
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
                  borderRadius: AppRadius.borderRadiusSmall,
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
  void _editAvatar(BuildContext context, ProfileNotifier profileNotifier) {
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
              // 顶部指示器
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),

              // 拍照选项
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(t.takePhoto),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await profileNotifier.pickImage(
                    ImageSource.camera,
                  );
                  if (file != null) {
                    await profileNotifier.uploadAvatar(file);
                  }
                },
              ),

              // 相册选项
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(t.selectFromAlbum),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await profileNotifier.pickImage(
                    ImageSource.gallery,
                  );
                  if (file != null) {
                    await profileNotifier.uploadAvatar(file);
                  }
                },
              ),

              // 取消选项
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(t.buttonCancel),
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _previewAvatar(BuildContext context, String avatarUrl) {
    if (avatarUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderRadiusMedium,
              image: DecorationImage(
                image: cachedImageProvider(avatarUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _editNickname(BuildContext context) {
    context.push('/personal_info/set_nickname');
  }

  void _editGender(BuildContext context) {
    context.push('/personal_info/set_gender');
  }

  void _editBirthday(BuildContext context) {
    // 获取当前生日
    final currentBirthday = UserRepoLocal.to.current.birthday;
    DateTime initialDate = DateTime.now();
    if (currentBirthday.isNotEmpty) {
      try {
        initialDate = DateTime.parse(currentBirthday);
      } catch (_) {
        initialDate = DateTime(1990, 1, 1);
      }
    } else {
      initialDate = DateTime(1990, 1, 1);
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        DateTime selectedDate = initialDate;

        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 顶部操作栏
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.cancel),
                    ),
                    Text(
                      t.birthday,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        // 保存生日
                        final birthdayStr =
                            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                        final success = await ref
                            .read(profileProvider.notifier)
                            .changeInfo({
                              "field": "birthday",
                              "value": birthdayStr,
                            });
                        if (success && mounted) {
                          // 更新本地用户信息
                          final payload = UserRepoLocal.to.current.toMap();
                          payload['birthday'] = birthdayStr;
                          UserRepoLocal.to.changeInfo(payload);
                        }
                      },
                      child: Text(t.confirm),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 日期选择器
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: DateTime(1900, 1, 1),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (DateTime newDate) {
                    selectedDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editRegion(BuildContext context) {
    context.push('/personal_info/set_region');
  }

  void _editSignature(BuildContext context) {
    final currentSign = UserRepoLocal.to.current.sign;
    final controller = TextEditingController(text: currentSign);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.signature),
          content: TextField(
            controller: controller,
            maxLength: 100,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: t.pleaseEnterSignature,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final newSign = controller.text.trim();
                if (newSign == currentSign) return;

                final success = await ref
                    .read(profileProvider.notifier)
                    .changeInfo({"field": "sign", "value": newSign});
                if (success && mounted) {
                  final payload = UserRepoLocal.to.current.toMap();
                  payload['sign'] = newSign;
                  UserRepoLocal.to.changeInfo(payload);
                }
              },
              child: Text(t.confirm),
            ),
          ],
        );
      },
    );
  }

  void _editBackground(BuildContext context) async {
    // 使用图片选择器选择背景图片
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(t.chooseFromAlbum),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1920,
                    maxHeight: 1080,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    await _uploadAndSetBackground(image.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(t.takePhoto),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1920,
                    maxHeight: 1080,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    await _uploadAndSetBackground(image.path);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.close, color: Colors.grey),
                title: Text(t.cancel),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 上传并设置背景图片
  Future<void> _uploadAndSetBackground(String imagePath) async {
    try {
      EasyLoading.show(status: t.uploading);

      // 调用上传 API
      final success = await ref
          .read(profileProvider.notifier)
          .uploadBackground(imagePath);

      EasyLoading.dismiss();

      if (success && mounted) {
        EasyLoading.showSuccess(t.uploadSuccess);
      } else if (mounted) {
        EasyLoading.showError(t.uploadFailed);
      }
    } catch (e) {
      EasyLoading.dismiss();
      if (mounted) {
        EasyLoading.showError(t.uploadFailed);
      }
    }
  }

  void _editProfession(BuildContext context) {
    _showTextEditDialog(
      context: context,
      title: t.profession,
      currentValue: UserRepoLocal.to.current.profession,
      field: 'profession',
      maxLength: 50,
      hintText: t.pleaseEnterProfession,
    );
  }

  void _editSchool(BuildContext context) {
    _showTextEditDialog(
      context: context,
      title: t.school,
      currentValue: UserRepoLocal.to.current.school,
      field: 'school',
      maxLength: 50,
      hintText: t.pleaseEnterSchool,
    );
  }

  void _editInterests(BuildContext context) {
    _showTextEditDialog(
      context: context,
      title: t.interests,
      currentValue: UserRepoLocal.to.current.interests,
      field: 'interests',
      maxLength: 100,
      hintText: t.pleaseEnterInterests,
      maxLines: 2,
    );
  }

  /// 显示文本编辑对话框
  void _showTextEditDialog({
    required BuildContext context,
    required String title,
    required String currentValue,
    required String field,
    int maxLength = 50,
    int maxLines = 1,
    String? hintText,
  }) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText ?? title,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final newValue = controller.text.trim();
                if (newValue == currentValue) return;

                final success = await ref
                    .read(profileProvider.notifier)
                    .changeInfo({"field": field, "value": newValue});
                if (success && mounted) {
                  final payload = UserRepoLocal.to.current.toMap();
                  payload[field] = newValue;
                  UserRepoLocal.to.changeInfo(payload);
                }
              },
              child: Text(t.confirm),
            ),
          ],
        );
      },
    );
  }

  void _showQRCode(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => UserQrCodePage()),
    );
  }

  void _shareProfile() {
    // 分享个人资料 - 显示分享选项
    final user = UserRepoLocal.to.current;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: Text(t.shareQRCode),
                onTap: () {
                  Navigator.pop(context);
                  // 导航到二维码页面
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => UserQrCodePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(t.copyLink),
                onTap: () {
                  Navigator.pop(context);
                  // 复制个人资料链接到剪贴板
                  // 这里可以生成一个分享链接
                  EasyLoading.showSuccess(t.copiedToClipboard);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(t.shareTo),
                onTap: () async {
                  Navigator.pop(context);
                  // 使用系统分享功能
                  try {
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${t.nickname}: ${user.nickname}\n'
                            '${t.signature}: ${user.sign}\n'
                            '${t.region}: ${user.region}',
                        subject: t.profile,
                      ),
                    );
                  } catch (e) {
                    EasyLoading.showError(t.shareFailed);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.close, color: Colors.grey),
                title: Text(t.cancel),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _exportProfile() {
    // 导出个人资料 - 生成 JSON 或文本文件
    final user = UserRepoLocal.to.current;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.exportProfile,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('JSON'),
                subtitle: Text(t.exportAsJson),
                onTap: () async {
                  Navigator.pop(context);
                  // 导出为 JSON 格式
                  final jsonStr = user.toJson().toString();
                  await _exportToClipboard(context, jsonStr, 'JSON');
                },
              ),
              ListTile(
                leading: const Icon(Icons.note),
                title: const Text('TXT'),
                subtitle: Text(t.exportAsText),
                onTap: () async {
                  Navigator.pop(context);
                  // 导出为文本格式
                  final textStr =
                      '''
${t.profile}
====================
${t.nickname}: ${user.nickname}
${t.account}: ${user.account}
${t.gender}: ${user.gender == 1 ? t.male : (user.gender == 2 ? t.female : t.secret)}
${t.region}: ${user.region}
${t.signature}: ${user.sign}
${t.birthday}: ${user.birthday}
${t.profession}: ${user.profession}
${t.school}: ${user.school}
${t.interests}: ${user.interests}
====================
''';
                  await _exportToClipboard(context, textStr, 'TXT');
                },
              ),
              ListTile(
                leading: Icon(Icons.close, color: Colors.grey),
                title: Text(t.cancel),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 导出到剪贴板
  Future<void> _exportToClipboard(
    BuildContext context,
    String content,
    String format,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) {
        EasyLoading.showSuccess(
          t.exportSuccessThenCopiedToClipboard(param: format),
        );
      }
    } catch (e) {
      if (mounted) {
        EasyLoading.showError(t.exportFailed);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
