import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
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
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

class UserQrCodePage extends ConsumerWidget {
  UserQrCodePage({super.key});

  final GlobalKey globalKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // API_BASE_URL=https://dev.imboy.pub
    String qrcodeData =
        "${Env().apiBaseUrl}/user/qrcode?id=${UserRepoLocal.to.currentUid}&$qrcodeDataSuffix";

    int gender = UserRepoLocal.to.current.gender;
    String filename = "${UserRepoLocal.to.currentUid}_qrcode";

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(
        Theme.of(context).brightness,
      ),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.myQrcode,
        backgroundColor: AppColors.getBackgroundColor(
          Theme.of(context).brightness,
        ),
        rightDMActions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: AppColors.getTextColor(Theme.of(context).brightness),
              size: 24,
            ),
            onPressed: () => _showBottomSheet(context, globalKey, filename),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.regular * 2,
          vertical: AppSpacing.regular * 3,
        ),
        child: Column(
          children: [
            // 二维码卡片
            RepaintBoundary(
              key: globalKey,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.borderRadiusRegular,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 用户信息区域
                    Container(
                      padding: EdgeInsets.all(AppSpacing.regular * 2),
                      child: Row(
                        children: [
                          // 头像
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.borderRadiusMedium,
                              image: dynamicAvatar(
                                UserRepoLocal.to.current.avatar,
                              ),
                            ),
                          ),

                          SizedBox(width: AppSpacing.regular * 1.6),

                          // 用户信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  UserRepoLocal.to.current.nickname,
                                  style: ThemeManager.instance.getTextStyle(
                                    FontSizeType.large,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.lightTextPrimary,
                                  ),
                                ),

                                SizedBox(height: AppSpacing.regular * 0.4),

                                if (UserRepoLocal.to.current.region.isNotEmpty)
                                  Text(
                                    UserRepoLocal.to.current.region,
                                    style: ThemeManager.instance.getTextStyle(
                                      FontSizeType.normal,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // 性别图标
                          if (gender > 0) genderIcon(gender),
                        ],
                      ),
                    ),

                    // 分割线
                    Container(
                      height: 1,
                      margin: EdgeInsets.symmetric(
                        horizontal: AppSpacing.regular * 2,
                      ),
                      color: AppColors.lightDivider.withValues(alpha: 0.3),
                    ),

                    // 二维码区域
                    Container(
                      padding: EdgeInsets.all(AppSpacing.regular * 3),
                      child: Column(
                        children: [
                          // 二维码
                          Container(
                            padding: EdgeInsets.all(AppSpacing.regular),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppRadius.borderRadiusSmall,
                            ),
                            child: QrImageView(
                              data: qrcodeData,
                              version: QrVersions.auto,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                              size: 240,
                              gapless: true,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                              // 使用简单的 AssetImage 避免缓存问题
                              embeddedImage:
                                  MediaQuery.of(context).size.height < 640
                                  ? null
                                  : const AssetImage(
                                      'assets/images/imboy_logo0.png',
                                    ),
                              embeddedImageStyle: const QrEmbeddedImageStyle(
                                size: Size.square(48),
                              ),
                            ),
                          ),

                          SizedBox(height: AppSpacing.regular * 2),

                          // 提示文字
                          Text(
                            t.scanQrcodeAddFriend,
                            style: ThemeManager.instance.getTextStyle(
                              FontSizeType.normal,
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppSpacing.regular * 4),

            // 操作按钮区域
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.save_alt,
                    text: t.saveQrCode,
                    onPressed: () => _saveQrCode(context, globalKey, filename),
                  ),
                ),

                SizedBox(width: AppSpacing.regular * 2),

                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.share,
                    text: t.share,
                    onPressed: () => _shareQrCode(context, globalKey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusRegular,
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.regular * 1.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                SizedBox(width: AppSpacing.regular),
                Flexible(
                  child: Text(
                    text,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示底部弹窗
  void _showBottomSheet(
    BuildContext context,
    GlobalKey globalKey,
    String filename,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCardBackground
              : AppColors.lightCardBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示器
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(
                  top: AppSpacing.regular * 1.2,
                  bottom: AppSpacing.regular * 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getDividerColor(
                    Theme.of(context).brightness,
                  ),
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),

              // 分享选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.share,
                text: t.share,
                onTap: () {
                  Navigator.pop(context);
                  _shareQrCode(context, globalKey);
                },
              ),

              // 保存选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.save_alt,
                text: t.saveQrCode,
                onTap: () {
                  Navigator.pop(context);
                  _saveQrCode(context, globalKey, filename);
                },
              ),

              // 扫一扫选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.qr_code_scanner,
                text: t.scanQrCode,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const ScannerPage(),
                    ),
                  );
                },
              ),

              // 分割线
              Container(
                height: 8,
                color: AppColors.getDividerColor(
                  Theme.of(context).brightness,
                ).withValues(alpha: 0.3),
                margin: EdgeInsets.symmetric(vertical: AppSpacing.regular),
              ),

              // 取消选项
              _buildBottomSheetItem(
                context: context,
                text: t.buttonCancel,
                onTap: () => Navigator.pop(context),
                isCancel: true,
              ),

              SizedBox(height: AppSpacing.regular),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// 构建底部弹窗选项
  Widget _buildBottomSheetItem({
    required BuildContext context,
    IconData? icon,
    required String text,
    required VoidCallback onTap,
    bool isCancel = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.regular * 2,
            vertical: AppSpacing.regular * 1.6,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: isCancel
                      ? AppColors.getTextColor(
                          Theme.of(context).brightness,
                          isSecondary: true,
                        )
                      : AppColors.getTextColor(Theme.of(context).brightness),
                  size: 22,
                ),
                SizedBox(width: AppSpacing.regular * 1.2),
              ],
              Text(
                text,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.medium,
                  fontWeight: FontWeight.w400,
                  color: isCancel
                      ? AppColors.getTextColor(
                          Theme.of(context).brightness,
                          isSecondary: true,
                        )
                      : AppColors.getTextColor(Theme.of(context).brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分享二维码
  void _shareQrCode(BuildContext context, GlobalKey globalKey) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final res = await RepaintBoundaryHelper().image(context, globalKey);
      if (res != null) {
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(res, mimeType: 'png')],
            text: t.scanQrcodeAddFriend,
          ),
        );
        if (result.status == ShareResultStatus.success) {
          // 分享成功
        }
      }
    });
  }

  /// 保存二维码
  void _saveQrCode(
    BuildContext context,
    GlobalKey globalKey,
    String filename,
  ) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final res = await RepaintBoundaryHelper().savePhoto(
        context,
        globalKey,
        filename,
      );
      iPrint("savePhoto res ${res.toString()}");
      bool isSuccess = res != null && res is Map && (res['isSuccess'] ?? false)
          ? true
          : false;
      if (isSuccess) {
        EasyLoading.showSuccess(t.saveSuccess);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    // 计算二维码数据和过期时间
    int expiredAt = DateTimeHelper.millisecond() + dayNum * 86400 * 1000;
    String key = Env().solidifiedKey;
    String tk = EncrypterService.md5("${expiredAt}_$key");
    Map<String, dynamic> query = {
      'id': widget.group.groupId,
      'exp': expiredAt,
      'tk': tk,
    };
    String queryStr = query.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}',
        )
        .join('&');
    String qrcodeData =
        "${Env().apiBaseUrl}/group/qrcode?$queryStr&$qrcodeDataSuffix";

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(
        Theme.of(context).brightness,
      ),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.groupQrcode,
        backgroundColor: AppColors.getBackgroundColor(
          Theme.of(context).brightness,
        ),
        rightDMActions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: AppColors.getTextColor(Theme.of(context).brightness),
              size: 24,
            ),
            onPressed: () => _showGroupBottomSheet(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.regular * 2,
          vertical: AppSpacing.regular * 2,
        ),
        child: Column(
          children: [
            RepaintBoundary(
              key: globalKey,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.borderRadiusRegular,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: AppSpacing.regular * 2),

                    // 群头像
                    SmartGroupAvatar(
                      avatar: widget.group.avatar,
                      groupId: widget.group.groupId,
                      avatarLoader: null, // TODO: 需要从 GroupListLogic 获取
                    ),

                    SizedBox(height: AppSpacing.regular * 1.2),

                    // 群名称
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.regular * 2,
                      ),
                      child: Text(
                        "${t.groupChat}: ${widget.group.title.isEmpty ? widget.group.computeTitle : widget.group.title}",
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.large,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightTextPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: AppSpacing.regular * 2),

                    // 二维码
                    Container(
                      padding: EdgeInsets.all(AppSpacing.regular),
                      child: QrImageView(
                        data: qrcodeData,
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        size: 240,
                        gapless: true,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                        embeddedImage: MediaQuery.of(context).size.height < 640
                            ? null
                            : const AssetImage('assets/images/imboy_logo0.png'),
                      ),
                    ),

                    // 有效期提示
                    Padding(
                      padding: EdgeInsets.all(AppSpacing.regular * 2),
                      child: Text(
                        t.groupQrcodeTips(
                          days: dayNum.toString(),
                          date: DateFormat('y-MM-dd').format(
                            DateTime.fromMillisecondsSinceEpoch(expiredAt),
                          ),
                        ),
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.small,
                          color: AppColors.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppSpacing.regular * 3),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.save_alt,
                    text: t.saveQrCode,
                    onPressed: () => _saveGroupQrCode(context),
                  ),
                ),

                SizedBox(width: AppSpacing.regular * 2),

                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.share,
                    text: t.share,
                    onPressed: () => _shareGroupQrCode(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusRegular,
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.regular * 1.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                SizedBox(width: AppSpacing.regular),
                Flexible(
                  child: Text(
                    text,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示群组底部弹窗
  void _showGroupBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCardBackground
              : AppColors.lightCardBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示器
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(
                  top: AppSpacing.regular * 1.2,
                  bottom: AppSpacing.regular * 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getDividerColor(
                    Theme.of(context).brightness,
                  ),
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),

              // 分享选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.share,
                text: t.share,
                onTap: () {
                  Navigator.pop(context);
                  _shareGroupQrCode(context);
                },
              ),

              // 保存选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.save_alt,
                text: t.saveQrCode,
                onTap: () {
                  Navigator.pop(context);
                  _saveGroupQrCode(context);
                },
              ),

              // 扫一扫选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.qr_code_scanner,
                text: t.scanQrCode,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const ScannerPage(),
                    ),
                  );
                },
              ),

              // 分割线
              Container(
                height: 8,
                color: AppColors.getDividerColor(
                  Theme.of(context).brightness,
                ).withValues(alpha: 0.3),
                margin: EdgeInsets.symmetric(vertical: AppSpacing.regular),
              ),

              // 取消选项
              _buildBottomSheetItem(
                context: context,
                text: t.buttonCancel,
                onTap: () => Navigator.pop(context),
                isCancel: true,
              ),

              SizedBox(height: AppSpacing.regular),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// 构建底部弹窗选项
  Widget _buildBottomSheetItem({
    required BuildContext context,
    IconData? icon,
    required String text,
    required VoidCallback onTap,
    bool isCancel = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.regular * 2,
            vertical: AppSpacing.regular * 1.6,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: isCancel
                      ? AppColors.getTextColor(
                          Theme.of(context).brightness,
                          isSecondary: true,
                        )
                      : AppColors.getTextColor(Theme.of(context).brightness),
                  size: 22,
                ),
                SizedBox(width: AppSpacing.regular * 1.2),
              ],
              Text(
                text,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.medium,
                  fontWeight: FontWeight.w400,
                  color: isCancel
                      ? AppColors.getTextColor(
                          Theme.of(context).brightness,
                          isSecondary: true,
                        )
                      : AppColors.getTextColor(Theme.of(context).brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分享群二维码
  void _shareGroupQrCode(BuildContext context) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final res = await RepaintBoundaryHelper().image(context, globalKey);
      if (res != null) {
        final t = context.t;
        final txt = t.groupQrcodeTips(
          days: dayNum.toString(),
          date: DateTimeHelper.lastTimeFmt(
            DateTimeHelper.millisecond() + dayNum * 86400 * 1000,
            pattern: 'y-MM-dd',
          ),
        );
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(res, mimeType: 'png')],
            text: txt,
          ),
        );
        if (result.status == ShareResultStatus.success) {
          // 分享成功
        }
      }
    });
  }

  /// 保存群二维码
  void _saveGroupQrCode(BuildContext context) async {
    String filename = "${widget.group.groupId}_qrcode.png";
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final res = await RepaintBoundaryHelper().savePhoto(
        context,
        globalKey,
        filename,
      );
      iPrint("savePhoto group res ${res.toString()}");
      bool isSuccess = res != null && res is Map && (res['isSuccess'] ?? false)
          ? true
          : false;
      if (isSuccess) {
        EasyLoading.showSuccess(context.t.saveSuccess);
      }
    });
  }
}
