import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/qrcode/qrcode_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

import '../set_nickname/set_nickname_page.dart';
import '../widget/more_page.dart';
import 'avatar_fallback_rules.dart';
import 'personal_info_provider.dart';

/// 个人信息页面
class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  /// 头像 Hero tag（personal_info → preview 共享，跨页面平滑过渡）
  static const String _avatarHeroTag = 'personal_info_avatar_hero';

  String currentUserAvatar = UserRepoLocal.to.current.avatar;
  final ImagePickerPlatform _picker = ImagePickerPlatform.instance;

  /// 打开全屏头像查看页（Hero animation 接力 _avatarHeroTag）
  Future<void> _openAvatarPreview(BuildContext context) async {
    if (currentUserAvatar.isEmpty) return; // 默认头像无需放大查看
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
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

      iPrint("getImageFromSource done: ${avatarFile != null}");
      if (avatarFile != null) {
        return cropImage(avatarFile);
      }
    } catch (e) {
      iPrint("getImageFromSource error: ${e.runtimeType}");
    }
  }

  Future<void> cropImage(XFile x) async {
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

  /// 构建头像 Hero 段（iOS Profile 范式：圆形大头像 + 相机角标 + 名字/账号居中）
  ///
  /// 设计依据：DESIGN.md §1 Clarity / Deference 原则 + iOS Settings 顶部 Apple ID 卡范式。
  /// 一次性闭环 5 个头像 bug：
  ///   H1 双层圆角嵌套（外 ClipRRect Small + 内 Avatar Tiny）→ 单层 ClipOval
  ///   H2 Avatar 内部灰底/灰边透出 → 直接用 Image + errorBuilder fallback
  ///   H3 整张 InkWell 误触中央文字 → GestureDetector 仅包头像本体
  ///   H4 64×64 right-aligned 丢失 hero 锚点 → 96×96 居中 + 名字 + 账号 ID
  ///   H5 无"可换头像"暗示 → 28×28 相机角标 FAB
  Widget _buildHeroAvatar(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? Theme.of(context).colorScheme.surface : AppColors.lightPageBackground;
    final nickname = UserRepoLocal.to.current.nickname;
    final account = UserRepoLocal.to.current.account;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          // 头像区域：主体看大图 + 相机角标换头像（两个独立 hit region）
          //
          // iOS Profile 标准交互：点头像主体 → 全屏查看大图；
          // 仅相机角标触发换头像 BottomSheet。
          // 角标视觉 30×30，触达区扩到 44×44pt（DESIGN.md §4.3）。
          SizedBox(
            width: 110, // 96 头像 + 14pt 角标外延空间
            height: 110,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 主体头像（点击查看大图）
                Semantics(
                  button: true,
                  label: t.avatar,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openAvatarPreview(context),
                    child: Hero(
                      tag: _avatarHeroTag,
                      child: ClipOval(
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: Image(
                            image: cachedImageProvider(
                              currentUserAvatar,
                              w: 192,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _AvatarFallback(
                              text: nickname,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 相机角标（44×44pt 隐形触达区 + 30×30 视觉，独立换头像入口）
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Semantics(
                    button: true,
                    label: t.buttonTakingPictures,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showAvatarBottomSheet(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.bottomRight,
                        // 透明 padding 扩大触达，视觉仍是 30×30 角标
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scaffoldBg,
                              width: 2.5,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.camera_fill,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 昵称 Title 2 (22pt w600)
          Text(
            nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextColor(brightness),
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 4),
          // 账号 Footnote (13pt iosGray + tabularFigures)
          Text(
            'ID: $account',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.iosGray,
              letterSpacing: 0,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建信息项（iOS InsetGrouped Cell 风格）
  ///
  /// - 可编辑项：title 主文本色 + value 次文本色 + chevron 右尖角
  /// - 只读项：title 主文本色 + value iosGray，无 chevron，整行不响应点击
  /// - Cell 反馈：按下时 surface 变浅灰高亮（[CellPressable]），禁用 Material Ripple
  Widget _buildInfoItem({
    required BuildContext context,
    required String title,
    required dynamic value,
    VoidCallback? onTap,
    bool showArrow = true,
    bool isEditable = true,
  }) {
    final brightness = Theme.of(context).brightness;
    // 只读项 value 文本色降为 iosGray，与可编辑项的 secondary 文字进一步拉开层级
    final valueColor = isEditable
        ? AppColors.getTextColor(brightness, isSecondary: true)
        : AppColors.iosGray;

    return CellPressable(
      onTap: isEditable ? onTap : null,
      child: Container(
        // iOS Cell 最小高度 44pt：水平 16 + 垂直 12 让单行 17pt 文本 ≈ 44pt
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // title：固定列宽不再用 SizedBox 120 死宽，改为内容自适应 + value Expanded 右对齐
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: AppColors.getTextColor(brightness),
                letterSpacing: -0.41,
              ),
            ),
            const SizedBox(width: 16),
            if (value is String)
              Expanded(
                child: Text(
                  value.isEmpty ? t.notSet : value,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    color: valueColor,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.41,
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
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.iosGray3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建 InsetGrouped 分组（iOS Settings 范式）
  ///
  /// - 16pt 水平 margin + 8pt 垂直 margin（节省 hero 头像下方留白）
  /// - 10pt cell 圆角（DESIGN.md §5.1 radiusCell，iOS HIG 标准）
  /// - 移除 boxShadow（DESIGN.md §5.2 iOS 不用重投影；改用 surfaceGrouped 背景对比制造层级）
  /// - 分隔线 left padding 112pt → 16pt（无头像列时的 iOS 标准起始位置）
  /// - 分隔线色 iosSeparator（亮 #C6C6C8 / 暗 #38383A），符合 Apple 官方
  /// - 内容用 ClipRRect 裁切，让 Cell 按下高亮也尊重圆角
  Widget _buildInfoGroup(BuildContext context, List<Widget> children) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // 暗色用 darkSurfaceGroupedTertiary (#2C2C2E)，比 Scaffold 的 darkSurfaceGrouped (#1C1C1E) 略浅，制造分层
    final cellBackground =
        isDark ? AppColors.darkSurfaceGroupedTertiary : AppColors.lightSurface;
    final separatorColor = AppColors.getIosSeparator(brightness);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cellBackground,
        borderRadius: AppRadius.borderRadiusCell,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusCell,
        child: Column(
          children: children.asMap().entries.map((entry) {
            final int index = entry.key;
            final Widget child = entry.value;
            return Column(
              children: [
                child,
                if (index < children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Container(height: 0.5, color: separatorColor),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 显示头像选择底部弹窗（iOS Modal Sheet 风格）
  ///
  /// DESIGN.md §8.6：顶部 10pt 圆角（cell radius）+ 36×5 grabber + surfaceElevated 背景
  /// 移除 boxShadow（iOS 不用重投影；showModalBottomSheet 自带 scrim）
  ///
  /// 选项编排：
  ///   1. 查看大图（仅在已有头像时显示，跳 [_AvatarPreviewPage]）
  ///   2. 拍照
  ///   3. 从相册选择
  ///   ── 取消（独立组）
  void _showAvatarBottomSheet(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final hasAvatar = currentUserAvatar.isNotEmpty;
    final separator = Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        height: 0.5,
        color: AppColors.getIosSeparator(brightness),
      ),
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        width: MediaQuery.of(sheetContext).size.width,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.cell),
            topRight: Radius.circular(AppRadius.cell),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // iOS HIG 标准 grabber：36×5pt iosGray3，顶部 5pt 边距
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 5, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.iosGray3,
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),
              if (hasAvatar) ...[
                _buildBottomSheetOption(
                  context: sheetContext,
                  title: t.viewLargeImage,
                  onTap: () {
                    // 关闭 sheet 后再 push preview，避免页面动画叠加
                    Navigator.of(sheetContext).pop();
                    _openAvatarPreview(context);
                  },
                ),
                separator,
              ],
              _buildBottomSheetOption(
                context: sheetContext,
                title: t.buttonTakingPictures,
                onTap: () => getImageFromSource(ImageSource.camera),
              ),
              separator,
              _buildBottomSheetOption(
                context: sheetContext,
                title: t.chooseFromAlbum,
                onTap: () => getImageFromSource(ImageSource.gallery),
              ),
              separator,
              _buildBottomSheetOption(
                context: sheetContext,
                title: t.buttonCancel,
                onTap: () => Navigator.of(sheetContext).pop(),
                isCancel: true,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部弹窗选项（iOS Action Sheet 风格）
  ///
  /// 取消按钮用 iosBlue（DESIGN.md §2.1：取消属于 iOS 系统语义位置）+ w600 强调
  Widget _buildBottomSheetOption({
    required BuildContext context,
    required String title,
    required VoidCallback onTap,
    bool isCancel = false,
  }) {
    final brightness = Theme.of(context).brightness;
    return CellPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: isCancel ? FontWeight.w600 : FontWeight.w400,
            color: isCancel
                ? AppColors.getIosBlue(brightness)
                : AppColors.getTextColor(brightness),
            letterSpacing: -0.41,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      // iOS InsetGrouped 范式：Scaffold 用 surfaceGrouped 背景（亮 #F2F2F7 / 暗 #1C1C1E），
      // Cell 用 surface（亮 white）/ darkSurfaceGroupedTertiary（暗 #2C2C2E）—— 通过背景对比制造层级
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      appBar: GlassAppBar(
        title: t.personalInformation,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroAvatar(context),
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
                showArrow: false,
                isEditable: false,
              ),
              if (UserRepoLocal.to.current.email.isNotEmpty)
                _buildInfoItem(
                  context: context,
                  title: t.loginEmail,
                  value: UserRepoLocal.to.current.email,
                  showArrow: false,
                  isEditable: false,
                ),
            ]),
            _buildInfoGroup(context, [
              _buildInfoItem(
                context: context,
                title: t.myQrcode,
                // 用 iosBlue 着色二维码图标，与可点击语义对齐（DESIGN.md §2.1 系统蓝）
                value: Icon(
                  CupertinoIcons.qrcode,
                  color: AppColors.getIosBlue(brightness),
                  size: 24,
                ),
                showArrow: true,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => UserQrCodePage()),
                  );
                },
              ),
              _buildInfoItem(
                context: context,
                title: t.moreInfo,
                value: ' ',
                showArrow: true,
                onTap: () {
                  // 导航到更多信息页面
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const MorePage()),
                  );
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

/// 头像加载失败 / 空 URL 时的兜底首字母圆形 widget
///
/// 不使用 [Avatar] 组件，因为后者自带 0.5 alpha 灰边 + 灰底，
/// 在 ClipOval 圆形遮罩下会出现"灰圈透出"伪影（H2 bug）。
/// 这里直接渲染品牌色背景 + 白字首字母，与 iOS Contacts 默认头像一致。
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: isDark ? AppColors.primaryDark : AppColors.primary,
      child: Text(
        extractAvatarInitial(text),
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

/// 全屏头像查看页（私有，仅供 [PersonalInfoPage] 使用）
///
/// 交互：
///   - Hero animation 接力 [heroTag]，从 96×96 圆形 → 屏宽长边的方形大图
///   - 单击空白处关闭
///   - 双指 / 双击缩放（[InteractiveViewer]，max 4×）
///   - 关闭按钮在左上角（iOS xmark 风格）
///
/// 设计选择（DESIGN.md §1 Clarity）：
///   不引入完整 [IMBoyImageGallery] 框架（仅 1 张图，PageController 多余），
///   纯 InteractiveViewer 已足够。
class _AvatarPreviewPage extends StatelessWidget {
  const _AvatarPreviewPage({required this.url, required this.heroTag});

  final String url;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.xmark,
            color: Colors.white,
            size: 22,
          ),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Hero(
            tag: heroTag,
            // Hero flight 期间 ClipOval → Rectangle 自然过渡（Flutter 内置 RectTween）
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image(
                image: cachedImageProvider(url, w: 0),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  CupertinoIcons.photo,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
