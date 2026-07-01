import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';

class GroupQrCodePage extends ConsumerStatefulWidget {
  final GroupModel group;
  const GroupQrCodePage({super.key, required this.group});
  @override
  ConsumerState<GroupQrCodePage> createState() => _GroupQrCodePageState();
}

class _GroupQrCodePageState extends ConsumerState<GroupQrCodePage> {
  final GlobalKey globalKey = GlobalKey();
  final int dayNum = 7;

  Future<List<String>> _loadGroupMemberAvatars(String groupId) async {
    final members = await GroupMemberRepo().page(
      where: '${GroupMemberRepo.groupId} = ?',
      whereArgs: [groupId],
      limit: 9,
    );
    return members.map((m) => m.avatar).where((a) => a.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    int expiredAt = DateTimeHelper.millisecond() + dayNum * 86400 * 1000;
    String qrcodeData =
        "${Env().apiBaseUrl}/group/qrcode?id=${widget.group.groupId}&exp=$expiredAt&tk=${EncrypterService.md5("${expiredAt}_${Env().solidifiedKey}")}&$qrcodeDataSuffix";

    return IosPageTemplate(
      title: t.account.groupQrcode,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
          onPressed: () => _showGroupBottomSheet(context),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            RepaintBoundary(
              key: globalKey,
              child: _buildQrCard(
                context,
                isDark,
                header: Column(
                  children: [
                    SmartGroupAvatar(
                      avatar: widget.group.avatar,
                      groupId: widget.group.groupId.toString(),
                      avatarLoader: _loadGroupMemberAvatars,
                      size: 64,
                    ),
                    AppSpacing.verticalRegular,
                    Text(
                      "${t.chat.groupChat}: ${widget.group.title.isEmpty ? widget.group.computeTitle : widget.group.title}",
                      textAlign: TextAlign.center,
                      style: context.textStyle(
                        FontSizeType.large,
                        fontWeight: FontWeight.bold,
                        // 意图：分享卡白底黑字固定外观，刻意不随主题切换
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                qrcodeData: qrcodeData,
                footerText: t.common.groupQrcodeTips(
                  days: dayNum.toString(),
                  date: DateFormat(
                    'y-MM-dd',
                  ).format(DateTime.fromMillisecondsSinceEpoch(expiredAt)),
                ),
              ),
            ),
            AppSpacing.verticalXXXLarge,
            _buildActionButtons(context),
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
          Padding(padding: AppSpacing.allXLarge, child: header),
          Container(
            height: 0.33,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: Colors.black12,
          ),
          Padding(
            padding: AppSpacing.allXXLarge,
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
                AppSpacing.verticalXLarge,
                Text(
                  footerText,
                  textAlign: TextAlign.center,
                  style: context.textStyle(
                    FontSizeType.footnote,
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

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildPremiumBtn(
            context,
            CupertinoIcons.arrow_down_doc,
            t.common.saveQrCode,
            () => _saveGroupQrCode(context),
          ),
        ),
        AppSpacing.horizontalRegular,
        Expanded(
          child: _buildPremiumBtn(
            context,
            CupertinoIcons.share,
            t.common.share,
            () => _shareGroupQrCode(context),
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
            AppSpacing.horizontalSmall,
            Text(
              text,
              style: context.textStyle(
                FontSizeType.subheadline,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupBottomSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _shareGroupQrCode(context);
            },
            child: Text(t.common.share),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _saveGroupQrCode(context);
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

  Future<void> _shareGroupQrCode(BuildContext context) async {
    final res = await RepaintBoundaryHelper().image(context, globalKey);
    if (res != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(res, mimeType: 'png')],
          text: t.common.scanQrcodeAddFriend,
        ),
      );
    }
  }

  Future<void> _saveGroupQrCode(BuildContext context) async {
    final res = await RepaintBoundaryHelper().savePhoto(
      context,
      globalKey,
      "${widget.group.groupId}_qrcode.png",
    );
    if (res != null && ((res['isSuccess'] as bool?) ?? false)) {
      AppLoading.showSuccess(t.common.saveSuccess);
    }
  }
}
