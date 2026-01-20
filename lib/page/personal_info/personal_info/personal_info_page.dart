import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

import '../set_nickname/set_nickname_page.dart';
import 'personal_info_provider.dart';

/// 个人信息页面
class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  String currentUserAvatar = UserRepoLocal.to.current.avatar;
  final ImagePickerPlatform _picker = ImagePickerPlatform.instance;

  Future getImageFromSource(ImageSource source) async {
    iPrint("getImageFromSource start");
    final res = await Connectivity().checkConnectivity();
    if (res.contains(ConnectivityResult.none)) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.networkException)));
      }
      return;
    }
    try {
      final XFile? avatarFile = await _picker.getImageFromSource(
        source: source,
      );

      iPrint("getImageFromSource ${avatarFile.toString()}");
      if (avatarFile != null) {
        return cropImage(avatarFile);
      }
    } catch (e) {
      iPrint("getImageFromSource e ${e.toString()}");
    }
  }

  void cropImage(XFile x) async {
    File originalImage = File(x.path);

    String? url = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => CropImageRoute(
          originalImage,
          "avatar",
          filename: UserRepoLocal.to.current.uid,
        ),
      ),
    );

    if (strNoEmpty(url)) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      bool ok = await ref.read(personalInfoProvider.notifier).changeInfo({
        "field": "avatar",
        "value": url,
      });
      if (ok) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        setState(() {
          currentUserAvatar = url!;
          Map<String, dynamic> payload = UserRepoLocal.to.current.toMap();
          payload["avatar"] = url;
          UserRepoLocal.to.changeInfo(payload);
        });
      }
    }
  }

  /// 构建头像卡片
  Widget _buildAvatarCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10, top: 10),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        child: InkWell(
          onTap: () => _showAvatarBottomSheet(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.avatar,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextColor(
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.borderRadiusSmall,
                    child: Avatar(imgUri: currentUserAvatar),
                  ),
                ),
                Icon(
                  Icons.navigate_next,
                  color: AppColors.getTextColor(
                    Theme.of(context).brightness,
                    isSecondary: true,
                  ),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem({
    required BuildContext context,
    required String title,
    required dynamic value,
    required VoidCallback onTap,
    bool showArrow = true,
    bool isEditable = true,
  }) {
    return Material(
      child: InkWell(
        onTap: isEditable ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: AppColors.getTextColor(Theme.of(context).brightness),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (value is String)
                Expanded(
                  child: Text(
                    value.isEmpty ? '未设置' : value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.getTextColor(
                        Theme.of(context).brightness,
                        isSecondary: true,
                      ),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              if (value is Widget)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [value],
                  ),
                ),
              if (showArrow && isEditable) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.navigate_next,
                  color: AppColors.getTextColor(
                    Theme.of(context).brightness,
                    isSecondary: true,
                  ),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建信息分组
  Widget _buildInfoGroup(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                  padding: const EdgeInsets.only(left: 112),
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
    );
  }

  /// 显示头像选择底部弹窗
  void _showAvatarBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCardBackground
              : AppColors.lightCardBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.getDividerColor(
                    Theme.of(context).brightness,
                  ),
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),
              _buildBottomSheetOption(
                context: context,
                title: t.buttonTakingPictures,
                onTap: () => getImageFromSource(ImageSource.camera),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 0.3,
                  color: AppColors.getDividerColor(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
              _buildBottomSheetOption(
                context: context,
                title: t.chooseFromAlbum,
                onTap: () => getImageFromSource(ImageSource.gallery),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 0.3,
                  color: AppColors.getDividerColor(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
              _buildBottomSheetOption(
                context: context,
                title: t.buttonCancel,
                onTap: () => Navigator.of(context).pop(),
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
    required BuildContext context,
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
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: isCancel
                  ? AppColors.getTextColor(
                      Theme.of(context).brightness,
                      isSecondary: true,
                    )
                  : AppColors.getTextColor(Theme.of(context).brightness),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: t.personalInformation,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAvatarCard(context),
            _buildInfoGroup(context, [
              _buildInfoItem(
                context: context,
                title: t.nickname,
                value: UserRepoLocal.to.current.nickname,
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const SetNicknamePage()),
                  );

                  if (result == true && context.mounted) {
                    setState(() {});
                  }
                },
              ),
              _buildInfoItem(
                context: context,
                title: t.account,
                value: UserRepoLocal.to.current.account,
                onTap: () {},
                showArrow: false,
                isEditable: false,
              ),
              if (UserRepoLocal.to.current.email.isNotEmpty)
                _buildInfoItem(
                  context: context,
                  title: t.loginEmail,
                  value: UserRepoLocal.to.current.email,
                  onTap: () {},
                  showArrow: false,
                  isEditable: false,
                ),
            ]),
            _buildInfoGroup(context, [
              _buildInfoItem(
                context: context,
                title: t.myQrcode,
                value: Icon(
                  Icons.qr_code_2,
                  color: isDark ? Colors.white70 : Colors.black,
                ),
                showArrow: true,
                onTap: () {
                  // TODO: 导航到二维码页面
                },
              ),
              _buildInfoItem(
                context: context,
                title: t.moreInfo,
                value: ' ',
                onTap: () {
                  // TODO: 导航到更多信息页面
                },
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
