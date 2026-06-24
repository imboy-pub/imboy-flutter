import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/page/search/search_chat_page.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'chat_setting_provider.dart';

class ChatSettingPage extends ConsumerStatefulWidget {
  final String type;
  final String peerId;
  final Map<String, dynamic>? options;

  const ChatSettingPage(
    this.peerId, {
    super.key,
    required this.type,
    this.options,
  });

  @override
  ConsumerState<ChatSettingPage> createState() => _ChatSettingPageState();
}

class _ChatSettingPageState extends ConsumerState<ChatSettingPage> {
  bool backDoRefresh = false;
  bool _burnEnabled = false;
  int _burnAfterMs = 30000;
  // C7-α-2: 本地 DND 开关
  bool _muteEnabled = false;
  int? _conversationId;

  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _loadBurnSetting();
    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadBurnSetting() async {
    try {
      final conversation = await ConversationRepo().findByPeerId(
        widget.type,
        widget.peerId,
      );
      final payload = conversation?.payload;
      if (!mounted) return;
      setState(() {
        _burnEnabled = payload?['burn_enabled'] == true;
        final raw = payload?['burn_after_ms'];
        if (raw is int && raw > 0) {
          _burnAfterMs = raw;
        } else if (raw is String) {
          final v = int.tryParse(raw);
          if (v != null && v > 0) _burnAfterMs = v;
        }
        // C7-α-2: 加载 DND 状态
        _muteEnabled = (conversation?.isMuted ?? 0) > 0;
        _conversationId = conversation?.id;
      });
    } catch (e) {
      debugPrint('[chat_setting_page] block error: $e');
    }
  }

  /// C7-α-2: 持久化 DND 开关到 conversation.is_muted 列
  Future<void> _persistMuteSetting(bool muted) async {
    if (_conversationId == null || _conversationId == 0) return;
    try {
      await ConversationRepo().updateById(_conversationId!, {
        ConversationRepo.isMuted: muted ? 1 : 0,
      });
      backDoRefresh = true;
    } catch (e) {
      debugPrint('[chat_setting_page] ConversationRepo error: $e');
    }
  }

  Future<void> _persistBurnSetting() async {
    final repo = ConversationRepo();
    final conversation = await repo.findByPeerId(widget.type, widget.peerId);
    if (conversation == null) return;
    final newPayload = <String, dynamic>{
      ...?conversation.payload,
      'burn_enabled': _burnEnabled,
      'burn_after_ms': _burnAfterMs,
    };
    await repo.updateById(conversation.id, {
      ConversationRepo.payload: newPayload,
    });
    backDoRefresh = true;
  }

  String _formatBurnAfterMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    if (ms % 60000 == 0) return t.common.durationMinutes(count: ms ~/ 60000);
    if (ms % 1000 == 0) return t.common.durationSeconds(count: ms ~/ 1000);
    return t.common.durationSeconds(count: (ms / 1000).toStringAsFixed(1));
  }

  Future<void> _selectBurnDuration() async {
    final options = <int>[5000, 10000, 30000, 60000, 300000, 600000];
    int selectedIndex = options.indexWhere((e) => e == _burnAfterMs);
    if (selectedIndex < 0) selectedIndex = 2;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (ctx) {
        int tempIndex = selectedIndex;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 280,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(t.common.buttonCancel),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            setState(() => _burnAfterMs = options[tempIndex]);
                            await _persistBurnSetting();
                            AppLoading.showToast(t.common.tipSuccess);
                          },
                          child: Text(t.common.buttonConfirm),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: selectedIndex,
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => tempIndex = i,
                      children: options
                          .map(
                            (ms) => Center(child: Text(_formatBurnAfterMs(ms))),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建现代化的列表项
  Widget _buildSettingTile({
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    bool isFirst = false,
    IconData? icon,
    Color? iconColor,
    String? subtitle,
    bool isDestructive = false,
  }) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 16.0 : 8.0,
        bottom: 8.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        // DESIGN.md §5.2 + §8.3：Cell 用边框区分而非投影
        // 移除 boxShadow（违反 InsetGrouped 范式：Cell 应靠 surfaceGrouped 背景对比制造层级）
        border: Border.all(
          color: isDestructive
              ? AppColors.getIosRed(
                  Theme.of(context).brightness,
                ).withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      // ClipRRect 让 CellPressable 按下高亮按 cell 圆角裁切（与 mine 模块统一）
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusRegular,
        child: CellPressable(
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.allRegular,
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          (iconColor ?? Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: iconColor ?? Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  AppSpacing.horizontalMedium,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.w500,
                          color: isDestructive
                              ? AppColors.getIosRed(
                                  Theme.of(context).brightness,
                                )
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        AppSpacing.verticalTiny,
                        Text(
                          subtitle,
                          style: context.textStyle(
                            FontSizeType.small,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建现代化开关列表项
  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData? icon,
    Color? iconColor,
    String? subtitle,
    bool isFirst = false,
  }) {
    return _buildSettingTile(
      title: title,
      icon: icon,
      iconColor: iconColor,
      subtitle: subtitle,
      isFirst: isFirst,
      trailing: Transform.scale(
        scale: 0.8,
        child: CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      onTap: () => onChanged(!value),
    );
  }

  /// 获取当前加密模式（从会话选项或默认配置）
  EncryptionMode get _currentEncryptionMode {
    final modeStr = widget.options?['encryption_mode'] as String?;
    if (modeStr != null) return EncryptionModeExt.fromApiString(modeStr);
    return EncryptionModeService
        .current; // ponytail: fall back to global policy
  }

  /// 构建加密模式图标
  IconData _encryptionIcon(EncryptionMode mode) {
    switch (mode) {
      case EncryptionMode.plaintext:
        return Icons.lock_open_outlined;
      case EncryptionMode.complianceE2ee:
        return Icons.admin_panel_settings_outlined;
      case EncryptionMode.strictE2ee:
        return Icons.lock_outlined;
    }
  }

  /// 构建设置列表
  List<Widget> _buildSettingsList(BuildContext context) {
    final mode = _currentEncryptionMode;
    return [
      _buildSettingTile(
        title: mode.displayName,
        icon: _encryptionIcon(mode),
        iconColor: mode.requiresEncryption
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        subtitle: mode == EncryptionMode.complianceE2ee
            ? t.main.msgProtectedByComplianceKey
            : mode == EncryptionMode.strictE2ee
            ? t.common.msgOnlyVisibleToParties
            : t.common.msgNotEncrypted,
        isFirst: true,
      ),
      // C7-α-2: 本地消息免打扰开关
      _buildSwitchTile(
        t.common.muteNotifications,
        _muteEnabled,
        (v) async {
          setState(() => _muteEnabled = v);
          await _persistMuteSetting(v);
          AppLoading.showToast(v ? t.common.enabled : t.common.disabled);
        },
        icon: Icons.notifications_off_outlined,
        iconColor: Theme.of(context).colorScheme.primary,
        subtitle: t.common.muteNotificationsHint,
      ),
      _buildSwitchTile(
        t.chat.burnAfterReading,
        _burnEnabled,
        (v) async {
          setState(() => _burnEnabled = v);
          await _persistBurnSetting();
          AppLoading.showToast(v ? t.common.enabled : t.common.disabled);
        },
        icon: Icons.local_fire_department_outlined,
        iconColor: AppColors.getIosRed(Theme.of(context).brightness),
        subtitle: _burnEnabled
            ? t.common.burnEnabledMessage(
                duration: _formatBurnAfterMs(_burnAfterMs),
              )
            : t.common.burnDisabledMessage,
      ),
      if (_burnEnabled)
        _buildSettingTile(
          title: t.main.destroyTime,
          icon: Icons.timer_outlined,
          subtitle: _formatBurnAfterMs(_burnAfterMs),
          onTap: _selectBurnDuration,
          trailing: Text(
            _formatBurnAfterMs(_burnAfterMs),
            style: context.textStyle(
              FontSizeType.normal,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      _buildSettingTile(
        title: t.common.searchChatRecord,
        icon: Icons.search,
        isFirst: true,
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute<dynamic>(
              builder: (_) => SearchChatPage(
                type: widget.type,
                peerId: widget.options?['peer_id'] as String,
                peerTitle: widget.options?['peerTitle'] as String,
                peerAvatar: widget.options?['peerAvatar'] as String,
                peerSign: widget.options?['peerSign'] as String? ?? '',
                conversationUk3: widget.options?['conversationUk3'] as String,
              ),
            ),
          );
        },
      ),
      _buildSettingTile(
        title: t.common.clearChatRecord,
        icon: Icons.delete_sweep_outlined,
        isDestructive: true,
        isFirst: true,
        onTap: () {
          String tips = t.common.confirmDeleteChatRecord;
          showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: Theme.of(dialogContext).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              title: Text(
                t.common.warning,
                style: TextStyle(
                  color: AppColors.getIosRed(
                    Theme.of(dialogContext).brightness,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Text(
                tips,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                  ),
                  child: Text(t.common.buttonCancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    final logic = ref.read(chatSettingProvider);
                    int cid = await logic.cleanMessageByPeerId(
                      widget.type,
                      widget.peerId,
                    );
                    if (cid > 0) {
                      backDoRefresh = true;
                      AppLoading.showSuccess(t.common.tipSuccess);
                    } else {
                      AppLoading.showError(t.common.tipFailed);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getIosRed(
                      Theme.of(dialogContext).brightness,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                  ),
                  child: Text(t.common.buttonConfirm),
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context, backDoRefresh);
          },
        ),
        titleWidget: Text(
          t.common.chatSettings,
          style: context.textStyle(
            FontSizeType.large,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const BouncingScrollPhysics(),
        children: _buildSettingsList(context),
      ),
    );
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }
}
