import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/ui/avatar.dart' show Avatar;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 个人二维码页面 - 极致 iOS 17 Premium 风格重构
class UserQrCodePage extends ConsumerWidget {
  UserQrCodePage({super.key});

  final GlobalKey globalKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = UserRepoLocal.to.current;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    String qrcodeData =
        "${Env().apiBaseUrl}/user/qrcode?id=${UserRepoLocal.to.currentUid}&$qrcodeDataSuffix";
    String filename = "${UserRepoLocal.to.currentUid}_qrcode";

    return IosPageTemplate(
      title: t.account.myQrcode,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
          onPressed: () => _showBottomSheet(context, globalKey, filename),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            // 二维码卡片
            RepaintBoundary(
              key: globalKey,
              child: _buildQrCard(
                context,
                isDark,
                header: Row(
                  children: [
                    Avatar(imgUri: user.avatar, width: 60, height: 60),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nickname,
                            style: TextStyle(
                              fontSize: FontSizeType.large.size,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: Colors.black,
                            ),
                          ),
                          if (user.region.isNotEmpty)
                            Text(
                              user.region,
                              style: TextStyle(
                                fontSize: FontSizeType.footnote.size,
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

            const SizedBox(height: 48),

            // 快速操作
            _buildActionButtons(context, globalKey, filename),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(
    BuildContext context,
    bool isDark, {
    required Widget header,
    required String qrcodeData,
    required String footerText,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // 意图：二维码分享卡始终为白底黑字（导出/分享为固定外观的图片），
        // 分享二维码为固定外观（白底黑字），刻意不随明暗主题切换。
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(24), child: header),
          Container(
            height: 0.33,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: Colors.black12,
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                QrImageView(
                  data: qrcodeData,
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  size: 220,
                  gapless: true,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  embeddedImage: const AssetImage(
                    'assets/images/imboy_logo0.png',
                  ),
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size.square(40),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  footerText,
                  style: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    color: AppColors.iosGray,
                    fontWeight: FontWeight.w500,
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
    return Row(
      children: [
        Expanded(
          child: _buildPremiumBtn(
            context,
            CupertinoIcons.arrow_down_doc,
            t.common.saveQrCode,
            () => _saveQrCode(context, key, filename),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPremiumBtn(
            context,
            CupertinoIcons.share,
            t.common.share,
            () => _shareQrCode(context, key),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumBtn(
    BuildContext context,
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: FontSizeType.subheadline.size,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
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
              Navigator.push(
                context,
                CupertinoPageRoute<void>(builder: (_) => const ScannerPage()),
              );
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
      EasyLoading.showSuccess(t.common.saveSuccess);
    }
  }
}
