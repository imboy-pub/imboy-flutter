import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/page/chat/rtc_room/rtc_room_page.dart';
import 'package:imboy/store/api/rtc_room_api.dart';

import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class ExtraItem extends StatelessWidget {
  const ExtraItem({
    super.key,
    required this.onPressed,
    required this.image,
    required this.title,
    this.width,
    this.height,
  });

  final Widget image;
  final void Function()? onPressed;
  final double? width;
  final double? height;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap:
            onPressed ?? () => AppLoading.showToast(t.common.featureComingSoon),
        borderRadius: AppRadius.borderRadiusRegular,
        child: Container(
          width: width ?? 64,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.tiny,
            vertical: AppSpacing.tiny,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标容器 - 使用现代设计风格
              Container(
                width: width ?? 56, // 稍微加大触控区域
                height: height ?? 56,
                decoration: BoxDecoration(
                  // iOS 分组背景 token（DESIGN.md 第 10 章）
                  color: isDark
                      ? AppColors.darkSurfaceGrouped
                      : AppColors.lightSurfaceGrouped,
                  borderRadius: AppRadius.borderRadiusLarge, // 更圆润的角
                  // 移除硬边框，使用极淡的内描边来增加精致感
                  // 注：5% 黑无对应 token 保留字面量；10% 白用 overlayWhite10
                  border: Border.all(
                    color: isDark
                        ? AppColors.overlayWhite10
                        : Colors.black.withValues(alpha: 0.05),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      //图标颜色：深色用白 / 浅色用次级文字色，保持工具属性不随主题色漂移
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextSecondary,
                      size: 26,
                    ),
                    child: image is ImageProvider
                        ? Image(
                            image: image as ImageProvider,
                            width: 26,
                            height: 26,
                          )
                        : image,
                  ),
                ),
              ),
              AppSpacing.verticalSmall,
              // 标题文字
              Flexible(
                child: Text(
                  title,
                  style: context
                      .textStyle(
                        FontSizeType.small,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.8),
                      )
                      .copyWith(height: 1.1),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExtraItems extends ConsumerStatefulWidget {
  const ExtraItems({
    super.key,
    this.handleImageSelection,
    this.handleFileSelection,
    this.handlePickerSelection,
    this.handleLocationSelection,
    this.handleVisitCardSelection,
    this.handleCollectSelection,
    this.handleStickerSelection,
    this.handleRedPacketSelection,
    this.handleTransferSelection,
    required this.type,
    required this.options,
  });

  final String type; // [C2C | C2G | C2S]
  final Map<String, dynamic> options;
  final void Function()? handleImageSelection;
  final void Function()? handleFileSelection;
  final void Function(BuildContext)? handlePickerSelection;
  final void Function(String, Uint8List, String, String, String, String)?
  handleLocationSelection;
  final void Function()? handleVisitCardSelection;
  final void Function()? handleCollectSelection;
  final void Function()? handleStickerSelection;
  final void Function(Map<String, dynamic>)? handleRedPacketSelection;
  final void Function(Map<String, dynamic>)? handleTransferSelection;

  @override
  ConsumerState<ExtraItems> createState() => _ExtraItemsState();
}

class _ExtraItemsState extends ConsumerState<ExtraItems> {
  /// 当前分页索引（CarouselSlider 圆点指示器）
  int _current = 0;
  final CarouselSliderController _controller = CarouselSliderController();

  /// 群通话：join 拿到 LiveKit 入场券后进群通话页
  Future<void> _joinGroupCall(BuildContext context) async {
    final gid = '${widget.options['to'] ?? ''}';
    if (gid.isEmpty) return;
    AppLoading.show(status: context.t.common.loading);
    final res = await RtcRoomApi().joinRoom(
      kind: 'group',
      targetId: gid,
      did: deviceId,
    );
    await AppLoading.dismiss();
    if (!context.mounted) return;
    if (res == null) {
      AppLoading.showError(context.t.common.operationFailedAgainLater);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RtcRoomPage(
          wsUrl: res['wsUrl'] ?? '',
          token: res['token'] ?? '',
          roomName: res['roomName'] ?? '',
          title: '${widget.options['title'] ?? ''}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t; // 获取翻译实例
    final colorScheme = Theme.of(context).colorScheme;
    const double iconSize = 28; // 调整图标大小
    final isC2G = widget.type == 'C2G';

    // —— 媒体（最常用，置顶）——
    final mediaItems = <ExtraItem>[
      ExtraItem(
        title: t.main.album,
        image: const Icon(Icons.photo_library_outlined, size: iconSize),
        onPressed: widget.handleImageSelection,
      ),
      ExtraItem(
        title: t.main.camera,
        image: const Icon(Icons.camera_alt_outlined, size: iconSize),
        onPressed: () {
          if (widget.handlePickerSelection != null) {
            widget.handlePickerSelection!(context);
          }
        },
      ),
      ExtraItem(
        title: t.groupSchedule.location,
        image: const Icon(Icons.location_on_outlined, size: iconSize),
        onPressed: () async {
          if (!context.mounted) return;

          // 定位（尤其是高德失败降级到 geolocator 时）可能要等几秒，
          // 之前点击后界面毫无反应，像按钮坏了；先给一个 loading 反馈。
          AppLoading.show(status: t.common.loading);
          AMapPosition? l = await LocationService().getCurrentPosition();
          await AppLoading.dismiss();
          if (!context.mounted) return;
          if (l == null) {
            AppLoading.showError(t.common.failedGetMapTryAgain);
            return;
          }
          if (context.mounted) {
            // 使用 go_router 进行导航
            final result = await context.push<Map<String, dynamic>>(
              '/map_location_picker',
              extra: {
                "lat": double.parse(l.latLng.latitude.toString()),
                "lng": double.parse(l.latLng.longitude.toString()),
                "citycode": AMapApi.getCityNameByGaoDe(l.adCode),
                "isMapImage": true,
              },
            );

            if (result != null && context.mounted) {
              if (result["image"] == null) {
                AppLoading.showError(t.common.failedGetMapTryAgain);
                FocusScope.of(context).requestFocus(FocusNode());
                return;
              }
              if (widget.handleLocationSelection != null &&
                  result["image"] != null) {
                widget.handleLocationSelection!(
                  result["id"] as String,
                  result["image"] as Uint8List,
                  result["address"] as String,
                  result["title"] as String,
                  result["latitude"].toString(),
                  result["longitude"].toString(),
                );
              }
            }
          }
        },
      ),
      ExtraItem(
        title: t.chat.file,
        image: const Icon(Icons.insert_drive_file_outlined, size: iconSize),
        onPressed: widget.handleFileSelection,
      ),
      ExtraItem(
        title: t.common.expression,
        image: const Icon(Icons.face_outlined, size: iconSize),
        onPressed: widget.handleStickerSelection,
      ),
      ExtraItem(
        title: t.main.favorites,
        image: const Icon(Icons.collections_bookmark_outlined, size: iconSize),
        onPressed: widget.handleCollectSelection,
      ),
      ExtraItem(
        title: t.common.personalCard,
        image: const Icon(Icons.person_outline, size: iconSize),
        onPressed: widget.handleVisitCardSelection,
      ),
      if (widget.type != 'C2G')
        ExtraItem(
          title: t.common.voiceCall,
          image: const Icon(Icons.phone_outlined, size: iconSize),
          onPressed: () {
            openCallScreen(
              context,
              ContactModel.fromMap({
                "id": widget.options["to"],
                "nickname": widget.options["title"],
                "avatar": widget.options["avatar"],
                "sign": widget.options["sign"],
              }),
              {'media': 'audio'},
            );
          },
        ),
      if (widget.type != 'C2G')
        ExtraItem(
          title: t.common.videoCall,
          image: const Icon(Icons.videocam_outlined, size: iconSize),
          onPressed: () {
            openCallScreen(
              context,
              ContactModel.fromMap({
                "id": widget.options["to"],
                "nickname": widget.options["title"],
                "avatar": widget.options["avatar"],
                "sign": widget.options["sign"],
              }),
              {'media': 'video'},
            );
          },
        ),
    ];

    // —— 群协作（仅群聊 C2G，直达创建表单）——
    final collabItems = <ExtraItem>[
      if (isC2G)
        ExtraItem(
          title: t.common.groupCall,
          image: const Icon(Icons.video_call_outlined, size: iconSize),
          onPressed: () => _joinGroupCall(context),
        ),
      if (isC2G)
        ExtraItem(
          title: t.groupVote.title,
          image: const Icon(Icons.poll_outlined, size: iconSize),
          onPressed: () =>
              context.push('/group/${widget.options['to']}/vote?create=1'),
        ),
      if (isC2G)
        ExtraItem(
          title: t.groupSchedule.title,
          image: const Icon(Icons.event_outlined, size: iconSize),
          onPressed: () =>
              context.push('/group/${widget.options['to']}/schedule?create=1'),
        ),
      if (isC2G)
        ExtraItem(
          title: t.groupTask.title,
          image: const Icon(Icons.checklist_outlined, size: iconSize),
          onPressed: () =>
              context.push('/group/${widget.options['to']}/task?create=1'),
        ),
    ];

    // —— 资金 ——
    final fundItems = <ExtraItem>[
      ExtraItem(
        title: t.common.redPacket,
        image: const Icon(
          Icons.redeem,
          size: iconSize,
          color: AppColors.iosRed,
        ),
        onPressed: () async {
          FocusScope.of(context).requestFocus(FocusNode());
          final result = await context.push<Map<String, dynamic>>(
            '/red_packet_send',
            extra: {'type': widget.type, 'to': widget.options['to']},
          );
          if (result != null && widget.handleRedPacketSelection != null) {
            widget.handleRedPacketSelection!(result);
          }
        },
      ),
      if (widget.type != 'C2G')
        ExtraItem(
          title: t.common.transfer,
          image: const Icon(
            Icons.swap_horiz,
            size: iconSize,
            color: AppColors.iosOrange,
          ),
          onPressed: () async {
            FocusScope.of(context).requestFocus(FocusNode());
            final result = await context.push<Map<String, dynamic>>(
              '/transfer_send',
              extra: {'to': widget.options['to']},
            );
            if (result != null && widget.handleTransferSelection != null) {
              widget.handleTransferSelection!(result);
            }
          },
        ),
    ];

    // 合并所有按钮，每页 8 个（2 行 × 4 列），超出自动分页，启用左右滑动 + 底部圆点
    final allItems = [...mediaItems, ...collabItems, ...fundItems];
    const int perPage = 8;
    final pages = <Widget>[
      for (var i = 0; i < allItems.length; i += perPage)
        _buildItemsGrid(
          allItems.sublist(
            i,
            i + perPage > allItems.length ? allItems.length : i + perPage,
          ),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // 顶部拖拽指示器
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: AppRadius.borderRadiusTiny,
            ),
          ),
          Expanded(
            child: pages.length > 1
                ? CarouselSlider(
                    controller: _controller,
                    options: CarouselOptions(
                      height: double.infinity,
                      viewportFraction: 1.0,
                      aspectRatio: 1.0,
                      scrollDirection: Axis.horizontal,
                      enableInfiniteScroll: false,
                      initialPage: 0,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _current = index;
                        });
                      },
                    ),
                    items: pages,
                  )
                : pages.first,
          ),
          // 页面指示器（圆点）
          if (pages.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: pages.asMap().entries.map((entry) {
                  return GestureDetector(
                    onTap: () => _controller.animateToPage(entry.key),
                    child: Container(
                      width: 8.0,
                      height: 8.0,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _current == entry.key
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建网格布局的项目
  Widget _buildItemsGrid(List<ExtraItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        // 用固定 mainAxisExtent 而非 childAspectRatio：格高不随屏宽等比缩放，
        // 避免窄屏(如 iPhone SE)下固定 56px 图标框把 Column 撑溢出
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // 每行4个
          mainAxisExtent: 108, // 图标56 + 间距8 + 两行文字 + 内边距，留足余量
          mainAxisSpacing: 8,
          crossAxisSpacing: 12,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}
