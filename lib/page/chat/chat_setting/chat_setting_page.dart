import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/page/search/search_chat_page.dart';
import 'package:imboy/theme/default/app_radius.dart';

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

  StreamSubscription? _localeSubscription;

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
      });
    } catch (_) {}
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
    if (ms % 60000 == 0) return '${ms ~/ 60000}分钟';
    if (ms % 1000 == 0) return '${ms ~/ 1000}秒';
    return '${(ms / 1000).toStringAsFixed(1)}秒';
  }

  Future<void> _selectBurnDuration() async {
    final options = <int>[5000, 10000, 30000, 60000, 300000, 600000];
    int selectedIndex = options.indexWhere((e) => e == _burnAfterMs);
    if (selectedIndex < 0) selectedIndex = 2;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                          child: Text(t.buttonCancel),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            setState(() => _burnAfterMs = options[tempIndex]);
                            await _persistBurnSetting();
                            EasyLoading.showToast(t.tipSuccess);
                          },
                          child: Text(t.buttonConfirm),
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
        border: Border.all(
          color: isDestructive
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusRegular,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (iconColor ?? Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
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

  /// 构建设置列表
  List<Widget> _buildSettingsList(BuildContext context) {
    return [
      _buildSwitchTile(
        t.burnAfterReading,
        _burnEnabled,
        (v) async {
          setState(() => _burnEnabled = v);
          await _persistBurnSetting();
          EasyLoading.showToast(v ? t.enabled : t.disabled);
        },
        icon: Icons.local_fire_department_outlined,
        iconColor: Theme.of(context).colorScheme.error,
        subtitle: _burnEnabled
            ? t.burnEnabledMessage(duration: _formatBurnAfterMs(_burnAfterMs))
            : t.burnDisabledMessage,
        isFirst: true,
      ),
      if (_burnEnabled)
        _buildSettingTile(
          title: t.destroyTime,
          icon: Icons.timer_outlined,
          subtitle: _formatBurnAfterMs(_burnAfterMs),
          onTap: _selectBurnDuration,
          trailing: Text(
            _formatBurnAfterMs(_burnAfterMs),
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),
      _buildSettingTile(
        title: t.searchChatRecord,
        icon: Icons.search,
        isFirst: true,
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => SearchChatPage(
                type: widget.type,
                peerId: widget.options?['peer_id'],
                peerTitle: widget.options?['peerTitle'],
                peerAvatar: widget.options?['peerAvatar'],
                peerSign: widget.options?['peerSign'] ?? '',
                conversationUk3: widget.options?['conversationUk3'],
              ),
            ),
          );
        },
      ),
      _buildSettingTile(
        title: t.clearChatRecord,
        icon: Icons.delete_sweep_outlined,
        isDestructive: true,
        isFirst: true,
        onTap: () {
          String tips = t.confirmDeleteChatRecord;
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: Theme.of(dialogContext).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              title: Text(
                t.warning,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
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
                  child: Text(t.buttonCancel),
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
                      EasyLoading.showSuccess(t.tipSuccess);
                    } else {
                      EasyLoading.showError(t.tipFailed);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                  ),
                  child: Text(t.buttonConfirm),
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
          t.chatSettings,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
