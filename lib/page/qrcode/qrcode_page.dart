import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar, Avatar;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: Colors.black,
                            ),
                          ),
                          if (user.region.isNotEmpty)
                            Text(
                              user.region,
                              style: const TextStyle(
                                fontSize: 13,
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
                  style: const TextStyle(
                    fontSize: 14,
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
              style: const TextStyle(
                fontSize: 15,
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
    if (res != null)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(res, mimeType: 'png')],
          text: t.common.scanQrcodeAddFriend,
        ),
      );
  }

  Future<void> _saveQrCode(
    BuildContext context,
    GlobalKey key,
    String filename,
  ) async {
    final res = await RepaintBoundaryHelper().savePhoto(context, key, filename);
    if (res != null && ((res['isSuccess'] as bool?) ?? false))
      EasyLoading.showSuccess(t.common.saveSuccess);
  }
}

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
                isDark,
                header: Column(
                  children: [
                    SmartGroupAvatar(
                      avatar: widget.group.avatar,
                      groupId: widget.group.groupId.toString(),
                      avatarLoader: _loadGroupMemberAvatars,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "${t.chat.groupChat}: ${widget.group.title.isEmpty ? widget.group.computeTitle : widget.group.title}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
            const SizedBox(height: 48),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(
    bool isDark, {
    required Widget header,
    required String qrcodeData,
    required String footerText,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
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
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
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
        const SizedBox(width: 16),
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
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
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
    if (res != null)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(res, mimeType: 'png')],
          text: t.common.scanQrcodeAddFriend,
        ),
      );
  }

  Future<void> _saveGroupQrCode(BuildContext context) async {
    final res = await RepaintBoundaryHelper().savePhoto(
      context,
      globalKey,
      "${widget.group.groupId}_qrcode.png",
    );
    if (res != null && ((res['isSuccess'] as bool?) ?? false))
      EasyLoading.showSuccess(t.common.saveSuccess);
  }
}

/// 频道二维码页面 - 像素级对齐 iOS 17 Premium 风格
class ChannelQrCodePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> channelData;
  const ChannelQrCodePage({super.key, required this.channelData});
  @override
  ConsumerState<ChannelQrCodePage> createState() => _ChannelQrCodePageState();
}

class _ChannelQrCodePageState extends ConsumerState<ChannelQrCodePage> {
  final GlobalKey globalKey = GlobalKey();
  final int dayNum = 7;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final channelId = widget.channelData['id'] as String? ?? '';
    final channelName = widget.channelData['name'] as String? ?? '';
    final channelAvatar = widget.channelData['avatar'] as String?;
    int expiredAt = DateTimeHelper.millisecond() + dayNum * 86400 * 1000;
    String qrcodeData =
        "${Env().apiBaseUrl}/channel/qrcode?id=$channelId&exp=$expiredAt&tk=${EncrypterService.md5("${expiredAt}_${Env().solidifiedKey}")}&$qrcodeDataSuffix";

    return IosPageTemplate(
      title: t.channel.qrcode,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
          onPressed: () => _showChannelBottomSheet(context),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            RepaintBoundary(
              key: globalKey,
              child: _buildQrCard(
                isDark,
                header: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        image: channelAvatar != null && channelAvatar.isNotEmpty
                            ? dynamicAvatar(channelAvatar)
                            : null,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: channelAvatar == null || channelAvatar.isEmpty
                          ? const Icon(
                              CupertinoIcons.antenna_radiowaves_left_right,
                              size: 32,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      channelName.isNotEmpty
                          ? channelName
                          : t.channel.defaultName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                qrcodeData: qrcodeData,
                footerText: t.channel.qrcodeTips(
                  days: dayNum.toString(),
                  date: DateFormat(
                    'y-MM-dd',
                  ).format(DateTime.fromMillisecondsSinceEpoch(expiredAt)),
                ),
              ),
            ),
            const SizedBox(height: 48),
            _buildActionButtons(context, channelId),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(
    bool isDark, {
    required Widget header,
    required String qrcodeData,
    required String footerText,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
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
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
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

  Widget _buildActionButtons(BuildContext context, String channelId) {
    return Row(
      children: [
        Expanded(
          child: _buildPremiumBtn(
            context,
            CupertinoIcons.arrow_down_doc,
            t.common.saveQrCode,
            () => _saveChannelQrCode(context, channelId),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPremiumBtn(
            context,
            CupertinoIcons.share,
            t.common.share,
            () => _shareChannelQrCode(context),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChannelBottomSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _shareChannelQrCode(context);
            },
            child: Text(t.common.share),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _saveChannelQrCode(
                context,
                widget.channelData['id'] as String? ?? '',
              );
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

  Future<void> _shareChannelQrCode(BuildContext context) async {
    final res = await RepaintBoundaryHelper().image(context, globalKey);
    if (res != null)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(res, mimeType: 'png')],
          text: t.common.scanQrcodeAddFriend,
        ),
      );
  }

  Future<void> _saveChannelQrCode(
    BuildContext context,
    String channelId,
  ) async {
    final res = await RepaintBoundaryHelper().savePhoto(
      context,
      globalKey,
      "${channelId}_qrcode.png",
    );
    if (res != null && ((res['isSuccess'] as bool?) ?? false))
      EasyLoading.showSuccess(t.common.saveSuccess);
  }
}
