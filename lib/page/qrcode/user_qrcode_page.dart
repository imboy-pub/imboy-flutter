import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/avatar.dart' show Avatar;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:imboy/page/qrcode/qrcode_url.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 个人二维码名片：屏幕与导出共用紧凑、可扫描的固定白色卡片。
class UserQrCodePage extends ConsumerWidget {
  UserQrCodePage({super.key});

  final GlobalKey globalKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = UserRepoLocal.to.current;
    String qrcodeData = buildUserQrcodeUrl(UserRepoLocal.to.currentUid);
    String filename = "${UserRepoLocal.to.currentUid}_qrcode";

    return IosPageTemplate(
      title: t.account.myQrcode,
      useLargeTitle: false,
      contentMaxWidth: 400,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.ellipsis_circle,
            size: 22,
            semanticLabel: t.common.buttonMore,
          ),
          onPressed: () => _showBottomSheet(context, globalKey, filename),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.xLarge,
        ),
        child: Column(
          children: [
            // 二维码卡片
            RepaintBoundary(
              key: globalKey,
              child: _buildQrCard(
                context,
                avatar: user.avatar,
                header: Row(
                  children: [
                    Avatar(
                      imgUri: user.avatar,
                      width: AppSizes.avatarSizeLarge,
                      height: AppSizes.avatarSizeLarge,
                    ),
                    AppSpacing.horizontalRegular,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nickname,
                            style: context
                                .textStyle(
                                  FontSizeType.extraLarge,
                                  fontWeight: FontWeight.bold,
                                  // 意图：分享卡白底黑字固定外观，刻意不随主题切换
                                  color: AppColors.lightTextPrimary,
                                )
                                .copyWith(letterSpacing: -0.5),
                          ),
                          if (user.region.isNotEmpty)
                            Text(
                              user.region,
                              style: context.textStyle(
                                FontSizeType.footnote,
                                color: AppColors.iosGray,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (user.gender > 0) genderIcon(user.gender),
                  ],
                ),
                qrcodeData: qrcodeData,
                footerText: t.common.scanQrcodeAddFriend,
              ),
            ),

            AppSpacing.verticalRegular,

            // 快速操作
            _buildActionButtons(context, globalKey, filename),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(
    BuildContext context, {
    required Widget header,
    required String qrcodeData,
    required String footerText,
    String? avatar,
  }) {
    final ImageProvider embeddedImageProvider;
    if (avatar != null &&
        avatar.isNotEmpty &&
        !avatar.contains("def_avatar.png")) {
      embeddedImageProvider = avatarImageProvider(avatar, w: 100);
    } else {
      embeddedImageProvider = const AssetImage('assets/images/imboy_logo0.png');
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // 导出内容保持固定白底黑字，确保明暗主题下扫描与分享一致。
        color: AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusLarge,
      ),
      child: Column(
        children: [
          Padding(padding: AppSpacing.allRegular, child: header),
          Padding(
            padding: AppSpacing.allRegular,
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(220.0, constraints.maxWidth);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(
                          key: const ValueKey('user-qrcode-image'),
                          data: qrcodeData,
                          version: QrVersions.auto,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          size: size,
                          padding: const EdgeInsets.all(AppSpacing.regular),
                          backgroundColor: AppColors.lightSurface,
                          gapless: true,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.lightTextPrimary,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.lightTextPrimary,
                          ),
                        ),
                        Container(
                          width: size / 5,
                          height: size / 5,
                          decoration: BoxDecoration(
                            color: AppColors.lightSurface,
                            borderRadius: AppRadius.borderRadiusSmall,
                          ),
                          padding: const EdgeInsets.all(AppSpacing.tiny / 2),
                          child: ClipRRect(
                            borderRadius: AppRadius.borderRadiusSmall,
                            child: Image(
                              image: embeddedImageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                AppSpacing.verticalSmall,
                Text(
                  footerText,
                  textAlign: TextAlign.center,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    GlobalKey key,
    String filename,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildPremiumBtn(
              context,
              CupertinoIcons.arrow_down_doc,
              t.common.saveQrCode,
              () => _saveQrCode(context, key, filename),
              primary: true,
            ),
          ),
          AppSpacing.horizontalRegular,
          Expanded(
            child: _buildPremiumBtn(
              context,
              CupertinoIcons.share,
              t.common.share,
              () => _shareQrCode(context, key),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBtn(
    BuildContext context,
    IconData icon,
    String text,
    VoidCallback onTap, {
    bool primary = false,
  }) {
    final foreground = primary
        ? AppColors.onPrimary
        : AppColors.getIosBlue(Theme.of(context).brightness);
    return CupertinoButton(
      minimumSize: const Size(44, AppSpacing.xxxLarge),
      padding: AppSpacing.allSmall,
      borderRadius: AppRadius.borderRadiusRegular,
      color: primary
          ? AppColors.primaryDark
          : Theme.of(context).colorScheme.surface,
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppSizes.iconSizeSmall, color: foreground),
          AppSpacing.horizontalSmall,
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(BuildContext context, GlobalKey key, String filename) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _shareQrCode(context, key);
            },
            child: Text(t.common.share),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _saveQrCode(context, key, filename);
            },
            child: Text(t.common.saveQrCode),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              // 统一走 go_router：原生 push 的 ScannerPage 内扫码
              // 跳 ChatPage/PeopleInfoPage 会失灵（混用排查批次3）
              context.push('/scanner');
            },
            child: Text(t.account.scanQrCode),
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

  Future<void> _shareQrCode(BuildContext context, GlobalKey key) async {
    final res = await RepaintBoundaryHelper().image(context, key);
    if (res != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(res, mimeType: 'png')],
          text: t.common.scanQrcodeAddFriend,
        ),
      );
    }
  }

  Future<void> _saveQrCode(
    BuildContext context,
    GlobalKey key,
    String filename,
  ) async {
    final res = await RepaintBoundaryHelper().savePhoto(context, key, filename);
    if (res != null && ((res['isSuccess'] as bool?) ?? false)) {
      AppLoading.showSuccess(t.common.saveSuccess);
    }
  }
}
