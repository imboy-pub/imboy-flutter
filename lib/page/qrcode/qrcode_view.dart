import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/ui/icon_image_provider.dart';
import 'package:imboy/component/ui/imboy_icon.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:jiffy/jiffy.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'qrcode_logic.dart';
import 'qrcode_state.dart';

class UserQrCodePage extends StatelessWidget {
  final GlobalKey globalKey = GlobalKey();

  UserQrCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    // API_BASE_URL=https://dev.imboy.pub
    String qrcodeData =
        "${Env().apiBaseUrl}/user/qrcode?id=${UserRepoLocal.to.currentUid}&$qrcodeDataSuffix";

    int gender = UserRepoLocal.to.current.gender;
    String filename = "${UserRepoLocal.to.currentUid}_qrcode";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(
        Theme.of(context).brightness,
      ),
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: '我的二维码'.tr,
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
          horizontal: ThemeManager.instance.mainSpace * 2,
          vertical: ThemeManager.instance.mainSpace * 3,
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
                  borderRadius: BorderRadius.circular(16),
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
                      padding: EdgeInsets.all(
                        ThemeManager.instance.mainSpace * 2,
                      ),
                      child: Row(
                        children: [
                          // 头像
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: dynamicAvatar(
                                UserRepoLocal.to.current.avatar,
                              ),
                            ),
                          ),

                          SizedBox(
                            width: ThemeManager.instance.mainSpace * 1.6,
                          ),

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

                                SizedBox(
                                  height: ThemeManager.instance.mainSpace * 0.4,
                                ),

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
                        horizontal: ThemeManager.instance.mainSpace * 2,
                      ),
                      color: AppColors.lightDivider.withValues(alpha: 0.3),
                    ),

                    // 二维码区域
                    Container(
                      padding: EdgeInsets.all(
                        ThemeManager.instance.mainSpace * 3,
                      ),
                      child: Column(
                        children: [
                          // 二维码
                          Container(
                            padding: EdgeInsets.all(
                              ThemeManager.instance.mainSpace,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
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
                              embeddedImage: Get.height < 640
                                  ? null
                                  : cachedImageProvider(
                                      UserRepoLocal.to.current.avatar,
                                    ),
                              embeddedImageStyle: const QrEmbeddedImageStyle(
                                size: Size.square(48),
                              ),
                            ),
                          ),

                          SizedBox(height: ThemeManager.instance.mainSpace * 2),

                          // 提示文字
                          Text(
                            'scanQrCodeAddFriend'.tr,
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

            SizedBox(height: ThemeManager.instance.mainSpace * 4),

            // 操作按钮区域
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.save_alt,
                    text: 'saveQrCode'.tr,
                    onPressed: () => _saveQrCode(context, globalKey, filename),
                  ),
                ),

                SizedBox(width: ThemeManager.instance.mainSpace * 2),

                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.share,
                    text: 'share'.tr,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.08),
            AppColors.primaryGreen.withValues(alpha: 0.12),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          highlightColor: AppColors.primaryGreen.withValues(alpha: 0.05),
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ThemeManager.instance.mainSpace * 1.2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: AppColors.primaryGreen, size: 18),
                ),
                SizedBox(width: ThemeManager.instance.mainSpace),
                Flexible(
                  child: Text(
                    text,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
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

    Get.bottomSheet(
      Container(
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
                  top: ThemeManager.instance.mainSpace * 1.2,
                  bottom: ThemeManager.instance.mainSpace * 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getDividerColor(
                    Theme.of(context).brightness,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 分享选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.share,
                text: 'share'.tr,
                onTap: () {
                  Get.back();
                  _shareQrCode(context, globalKey);
                },
              ),

              // 保存选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.save_alt,
                text: 'saveQrCode'.tr,
                onTap: () {
                  Get.back();
                  _saveQrCode(context, globalKey, filename);
                },
              ),

              // 扫一扫选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.qr_code_scanner,
                text: 'scanQrCode'.tr,
                onTap: () {
                  Get.back();
                  Get.to(
                    () => const ScannerPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),

              // 分割线
              Container(
                height: 8,
                color: AppColors.getDividerColor(
                  Theme.of(context).brightness,
                ).withValues(alpha: 0.3),
                margin: EdgeInsets.symmetric(
                  vertical: ThemeManager.instance.mainSpace,
                ),
              ),

              // 取消选项
              _buildBottomSheetItem(
                context: context,
                text: 'buttonCancel'.tr,
                onTap: () => Get.back(),
                isCancel: true,
              ),

              SizedBox(height: ThemeManager.instance.mainSpace),
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
            horizontal: ThemeManager.instance.mainSpace * 2,
            vertical: ThemeManager.instance.mainSpace * 1.6,
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
                SizedBox(width: ThemeManager.instance.mainSpace * 1.2),
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
            text: 'scanQrCodeAddFriend'.tr,
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
        EasyLoading.showSuccess('saveSuccess'.tr);
      }
    });
  }
}

class GroupQrCodePage extends StatelessWidget {
  final GlobalKey globalKey = GlobalKey();

  final int dayNum = 7;
  final GroupModel group;

  GroupQrCodePage({super.key, required this.group});

  final QrCodeLogic logic = Get.put(QrCodeLogic());
  final QrCodeState state = Get.find<QrCodeLogic>().state;

  Future<void> _initData() async {
    // API_BASE_URL=https://dev.imboy.pub
    int expiredAt = DateTimeHelper.millisecond() + dayNum * 86400 * 1000;
    String key = Env().solidifiedKey;
    String tk = EncrypterService.md5("${expiredAt}_$key");
    Map<String, dynamic> query = {
      'id': group.groupId,
      'exp': expiredAt,
      'tk': tk,
    };
    String queryStr = query.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}',
        )
        .join('&');
    state.qrcodeData.value =
        "${Env().apiBaseUrl}/group/qrcode?$queryStr&$qrcodeDataSuffix";

    state.expiredAt.value = expiredAt;
  }

  @override
  Widget build(BuildContext context) {
    _initData();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(
        Theme.of(context).brightness,
      ),
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: '群二维码'.tr,
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
          horizontal: ThemeManager.instance.mainSpace * 2,
          vertical: ThemeManager.instance.mainSpace * 2,
        ),
        child: Column(
          children: [
            RepaintBoundary(
              key: globalKey,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Obx(
                  () => Column(
                    children: [
                      SizedBox(height: ThemeManager.instance.mainSpace * 2),

                      // 群头像
                      SmartGroupAvatar(
                        avatar: group.avatar,
                        groupId: group.groupId,
                      ),

                      SizedBox(height: ThemeManager.instance.mainSpace * 1.2),

                      // 群名称
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ThemeManager.instance.mainSpace * 2,
                        ),
                        child: Text(
                          "${'groupChat'.tr}: ${group.title.isEmpty ? group.computeTitle : group.title}",
                          style: ThemeManager.instance.getTextStyle(
                            FontSizeType.large,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightTextPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: ThemeManager.instance.mainSpace * 2),

                      // 二维码
                      Container(
                        padding: EdgeInsets.all(
                          ThemeManager.instance.mainSpace,
                        ),
                        child: QrImageView(
                          data: state.qrcodeData.value,
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
                          embeddedImage: Get.height < 640
                              ? null
                              : IconImageProvider(
                                  IMBoyIcon.imboyLogo,
                                  size: 48,
                                  color: Colors.green,
                                  bgColor: Colors.white,
                                ),
                        ),
                      ),

                      // 有效期提示
                      Padding(
                        padding: EdgeInsets.all(
                          ThemeManager.instance.mainSpace * 2,
                        ),
                        child: Text(
                          'groupQrcodeTips'.trArgs([
                            dayNum.toString(),
                            Jiffy.parseFromDateTime(
                              Jiffy.parseFromMillisecondsSinceEpoch(
                                state.expiredAt.value,
                              ).dateTime,
                            ).format(pattern: 'y-MM-dd'),
                          ]),
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
            ),

            SizedBox(height: ThemeManager.instance.mainSpace * 3),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.save_alt,
                    text: 'saveQrCode'.tr,
                    onPressed: () => _saveGroupQrCode(context),
                  ),
                ),

                SizedBox(width: ThemeManager.instance.mainSpace * 2),

                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.share,
                    text: 'share'.tr,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.08),
            AppColors.primaryGreen.withValues(alpha: 0.12),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          highlightColor: AppColors.primaryGreen.withValues(alpha: 0.05),
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ThemeManager.instance.mainSpace * 1.2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: AppColors.primaryGreen, size: 18),
                ),
                SizedBox(width: ThemeManager.instance.mainSpace),
                Flexible(
                  child: Text(
                    text,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
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

    Get.bottomSheet(
      Container(
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
                  top: ThemeManager.instance.mainSpace * 1.2,
                  bottom: ThemeManager.instance.mainSpace * 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getDividerColor(
                    Theme.of(context).brightness,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 分享选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.share,
                text: 'share'.tr,
                onTap: () {
                  Get.back();
                  _shareGroupQrCode(context);
                },
              ),

              // 保存选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.save_alt,
                text: 'saveQrCode'.tr,
                onTap: () {
                  Get.back();
                  _saveGroupQrCode(context);
                },
              ),

              // 扫一扫选项
              _buildBottomSheetItem(
                context: context,
                icon: Icons.qr_code_scanner,
                text: 'scanQrCode'.tr,
                onTap: () {
                  Get.back();
                  Get.to(
                    () => const ScannerPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),

              // 分割线
              Container(
                height: 8,
                color: AppColors.getDividerColor(
                  Theme.of(context).brightness,
                ).withValues(alpha: 0.3),
                margin: EdgeInsets.symmetric(
                  vertical: ThemeManager.instance.mainSpace,
                ),
              ),

              // 取消选项
              _buildBottomSheetItem(
                context: context,
                text: 'buttonCancel'.tr,
                onTap: () => Get.back(),
                isCancel: true,
              ),

              SizedBox(height: ThemeManager.instance.mainSpace),
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
            horizontal: ThemeManager.instance.mainSpace * 2,
            vertical: ThemeManager.instance.mainSpace * 1.6,
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
                SizedBox(width: ThemeManager.instance.mainSpace * 1.2),
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
        final txt = 'groupQrcodeTips'.trArgs([
          dayNum.toString(),
          Jiffy.parseFromDateTime(
            Jiffy.parseFromMillisecondsSinceEpoch(
              state.expiredAt.value,
            ).dateTime,
          ).format(pattern: 'y-MM-dd'),
        ]);
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
    String filename = "${group.groupId}_qrcode.png";
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
        EasyLoading.showSuccess('saveSuccess'.tr);
      }
    });
  }
}
