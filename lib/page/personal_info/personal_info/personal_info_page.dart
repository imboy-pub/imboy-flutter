import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';

import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/qrcode/qrcode_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/i18n/strings.g.dart';

import '../set_nickname/set_nickname_page.dart';
import '../widget/more_page.dart';

/// 个人信息页面 - 像素级对齐 iOS 17 Premium 风格
class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  static const String _avatarHeroTag = 'personal_info_avatar_hero';
  String currentUserAvatar = UserRepoLocal.to.current.avatar;
  MediaPickerCapability get _picker =>
      CapabilityLocator.I.get<MediaPickerCapability>();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final nickname = UserRepoLocal.to.current.nickname;
    final account = UserRepoLocal.to.current.account;

    return IosPageTemplate(
      title: t.common.personalInformation,
      useLargeTitle: false,
      child: Column(
        children: [
          // 顶部头像 Hero Section
          _buildHeroAvatar(context, isDark, nickname, account, brightness),

          // 核心资料 Section
          ImBoySettingsSection(
            header: Text(t.common.basicInfo.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.account.nickname),
                trailing: Text(
                  nickname.isEmpty ? t.common.notSet : nickname,
                  style: TextStyle(
                    fontSize: FontSizeType.subheadline.size,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    CupertinoPageRoute<dynamic>(
                      builder: (_) => const SetNicknamePage(),
                    ),
                  );
                  if (result == true && mounted) setState(() {});
                },
              ),
              ImBoySettingsTile(
                title: Text(t.account.account),
                trailing: Text(
                  account,
                  style: TextStyle(
                    fontSize: FontSizeType.subheadline.size,
                    color: AppColors.iosGray,
                  ),
                ),
              ),
              if (UserRepoLocal.to.current.email.isNotEmpty)
                ImBoySettingsTile(
                  title: Text(t.account.loginEmail),
                  trailing: Text(
                    UserRepoLocal.to.current.email,
                    style: TextStyle(
                      fontSize: FontSizeType.subheadline.size,
                      color: AppColors.iosGray,
                    ),
                  ),
                ),
            ],
          ),

          // 扩展资料 Section
          ImBoySettingsSection(
            header: Text(t.common.extendedInfo.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.account.myQrcode),
                leading: const Icon(
                  CupertinoIcons.qrcode,
                  color: AppColors.iosGray,
                  size: 20,
                ),
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(builder: (_) => UserQrCodePage()),
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.common.moreInfo),
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(builder: (_) => const MorePage()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeroAvatar(
    BuildContext context,
    bool isDark,
    String nickname,
    String account,
    Brightness brightness,
  ) {
    final scaffoldBg = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceGrouped;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () => _openAvatarPreview(context),
                  child: Hero(
                    tag: _avatarHeroTag,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        image: DecorationImage(
                          image: avatarImageProvider(currentUserAvatar, w: 192),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: currentUserAvatar.isEmpty
                          ? Center(
                              child: Text(
                                nickname.isNotEmpty
                                    ? nickname.substring(0, 1).toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: FontSizeType.extraLargeTitle.size,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: GestureDetector(
                    onTap: () => _showAvatarBottomSheet(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scaffoldBg, width: 2),
                      ),
                      child: const Icon(
                        CupertinoIcons.camera_fill,
                        size: 14,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nickname,
            style: TextStyle(
              fontSize: FontSizeType.title.size,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ID: $account',
            style: TextStyle(
              fontSize: FontSizeType.normal.size,
              color: AppColors.iosGray,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAvatarPreview(BuildContext context) async {
    if (currentUserAvatar.isEmpty) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: AppColors.darkBackground,
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: _AvatarPreviewPage(
            url: currentUserAvatar,
            heroTag: _avatarHeroTag,
          ),
        ),
      ),
    );
  }

  void _showAvatarBottomSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (currentUserAvatar.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _openAvatarPreview(context);
              },
              child: Text(t.chat.viewLargeImage),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _getImage();
            },
            child: Text(t.common.buttonTakingPictures),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _getImage();
            },
            child: Text(t.main.chooseFromAlbum),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDefaultAction: true,
          child: Text(t.common.buttonCancel),
        ),
      ),
    );
  }

  Future<void> _getImage() async {
    final media = await _picker.pickSingle(context, MediaType.image);
    if (media != null) _cropImage(media.path);
  }

  Future<void> _cropImage(String path) async {
    String? url = await Navigator.push(
      context,
      CupertinoPageRoute<String>(
        builder: (_) => CropImageRoute(
          File(path),
          "avatar",
          filename: UserRepoLocal.to.current.uid,
        ),
      ),
    );
    if (strNoEmpty(url)) {
      // 统一走 UserProfileService：PUT 更新 + 本地缓存同步内聚于一处，
      // 与 ProfilePage 共用同一实现，避免双入口逻辑漂移。
      if (await UserProfileService.updateField("avatar", url)) {
        setState(() {
          currentUserAvatar = url!;
        });
      }
    }
  }
}

class _AvatarPreviewPage extends StatelessWidget {
  final String url;
  final String heroTag;
  const _AvatarPreviewPage({required this.url, required this.heroTag});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.xmark,
            color: AppColors.onPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              child: Image(
                image: cachedImageProvider(url, w: 0),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
