import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/detail_settings_tile.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';

import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/photo_view_loading.dart';
import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/i18n/strings.g.dart';

import '../set_nickname/set_nickname_page.dart';
import '../widget/more_page.dart';

/// 个人信息页面 - 像素级对齐 iOS 17 Premium 风格
class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key, this.readOnly = kIsWeb});

  final bool readOnly;

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  static const String _avatarHeroTag = 'personal_info_avatar_hero';
  String? _avatarOverride;
  String get currentUserAvatar =>
      _avatarOverride ?? UserRepoLocal.to.currentUser?.avatar ?? '';
  MediaPickerCapability get _picker =>
      CapabilityLocator.I.get<MediaPickerCapability>();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return IosPageTemplate(
        contentMaxWidth: kIsWeb && widget.readOnly
            ? ResourcePageLayout.maxWidth
            : null,
        title: t.common.personalInformation,
        child: Center(child: Text(t.common.notLoggedIn)),
      );
    }
    final nickname = user.nickname;
    final account = user.account;

    return IosPageTemplate(
      contentMaxWidth: kIsWeb && widget.readOnly
          ? ResourcePageLayout.maxWidth
          : null,
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
              DetailSettingsTile(
                title: Text(t.account.nickname),
                value: nickname.isEmpty ? t.common.notSet : nickname,
                onTap: widget.readOnly
                    ? null
                    : () async {
                        final result = await Navigator.push(
                          context,
                          CupertinoPageRoute<dynamic>(
                            builder: (_) => const SetNicknamePage(),
                          ),
                        );
                        if (result == true && mounted) setState(() {});
                      },
              ),
              DetailSettingsTile(
                title: Text(t.account.account),
                value: account,
              ),
              if (user.email.isNotEmpty)
                DetailSettingsTile(
                  title: Text(t.account.loginEmail),
                  value: user.email,
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
                onTap: () => context.push('/qrcode/user'),
              ),
              ImBoySettingsTile(
                title: Text(t.common.moreInfo),
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => MorePage(readOnly: widget.readOnly),
                  ),
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
                Semantics(
                  label: t.chat.viewLargeImage,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: currentUserAvatar.isEmpty
                        ? null
                        : () => _openAvatarPreview(context),
                    child: Hero(
                      tag: _avatarHeroTag,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.1),
                          image: DecorationImage(
                            image: avatarImageProvider(
                              currentUserAvatar,
                              w: 192,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: currentUserAvatar.isEmpty
                            ? Center(
                                child: AvatarFallbackContent(
                                  name: nickname,
                                  color: AppColors.primary,
                                  iconSize: 44,
                                  textStyle: context.textStyle(
                                    FontSizeType.extraLargeTitle,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                if (!widget.readOnly)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(44, 44),
                      onPressed: () => _showAvatarBottomSheet(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: scaffoldBg, width: 2),
                        ),
                        child: Icon(
                          CupertinoIcons.camera_fill,
                          semanticLabel: t.common.avatarEditAvatar,
                          size: 14,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.verticalMedium,
          Text(
            nickname,
            style: context
                .textStyle(FontSizeType.title, fontWeight: FontWeight.w600)
                .copyWith(letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            'ID: $account',
            style: context
                .textStyle(FontSizeType.normal, color: AppColors.iosGray)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }

  Future<void> _openAvatarPreview(BuildContext context) async {
    if (currentUserAvatar.isEmpty) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            _AvatarPreviewPage(url: currentUserAvatar, heroTag: _avatarHeroTag),
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
              _getImage(useCamera: true);
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

  Future<void> _getImage({bool useCamera = false}) async {
    // 「拍照」此前和「从相册选择」调的是同一个 pickSingle(gallery)，从未
    // 真正唤起相机；useCamera 时走 pickCamera（与头像编辑页同款修复）。
    final media = useCamera
        ? await _picker.pickCamera(context)
        : await _picker.pickSingle(context, MediaType.image);
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
          _avatarOverride = url!;
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
      appBar: GlassAppBar(
        backgroundColor: AppColors.transparent,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            semanticLabel: t.common.buttonClose,
            CupertinoIcons.xmark,
            color: AppColors.onPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Hero(
        tag: heroTag,
        child: PhotoView(
          imageProvider: cachedImageProvider(url, w: 0),
          loadingBuilder: buildPhotoViewLoading,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        ),
      ),
    );
  }
}
