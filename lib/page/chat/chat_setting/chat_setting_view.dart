import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/model/user_model.dart';

import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/search/search_chat_view.dart';

import 'chat_setting_logic.dart';
import 'chat_setting_state.dart';

// ignore: must_be_immutable
class ChatSettingPage extends StatefulWidget {
  final String type;
  final String peerId;
  Map<String, dynamic>? options;

  ChatSettingPage(this.peerId, {super.key, required this.type, this.options});

  @override
  // ignore: library_private_types_in_public_api
  _ChatSettingPageState createState() => _ChatSettingPageState();
}

class _ChatSettingPageState extends State<ChatSettingPage> {
  final logic = Get.put(ChatSettingLogic());
  final ChatSettingState state = Get.find<ChatSettingLogic>().state;

  bool backDoRefresh = false;
  bool isRemind = false;
  bool isTop = false;
  bool isDoNotDisturb = true;

  // 可视阈值已读设置
  bool _enableVisibilityRead = true;
  double _visibilityReadFraction = 0.6; // 0~1
  int _visibilityReadDelayMs = 400;     // 毫秒

  bool _burnEnabled = false;
  int _burnAfterMs = 30000;

  @override
  void initState() {
    super.initState();
    // 读取用户设置
    final s = UserRepoLocal.to.setting;
    _enableVisibilityRead = s.enableVisibilityRead;
    _visibilityReadFraction = s.visibilityReadFraction;
    _visibilityReadDelayMs = s.visibilityReadDelayMs;
    // 读取其他需要的初始化信息
    getInfo();
    _loadBurnSetting();
  }

  Future<void> _persistVisibilityReadSetting() async {
    final s = UserRepoLocal.to.setting;
    final newSetting = UserSettingModel(
      allowSearch: s.allowSearch,
      peopleNearbyVisible: s.peopleNearbyVisible,
      chatState: s.chatState,
      fontSize: s.fontSize,
      enableVisibilityRead: _enableVisibilityRead,
      visibilityReadFraction: _visibilityReadFraction,
      visibilityReadDelayMs: _visibilityReadDelayMs,
    );
    await UserRepoLocal.to.changeSetting(newSetting);
  }

  Future<void> _loadBurnSetting() async {
    try {
      final conversation = await ConversationRepo().findByPeerId(widget.type, widget.peerId);
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
    final conversationLogic = Get.find<ConversationLogic>();
    final uk3 = conversation.uk3;
    if (conversationLogic.conversationMap.containsKey(uk3)) {
      conversationLogic.conversationMap[uk3] =
          conversationLogic.conversationMap[uk3]!.copyWith(payload: newPayload);
    }
    backDoRefresh = true;
  }

  String _formatBurnAfterMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    if (ms % 60000 == 0) return '${ms ~/ 60000}分钟';
    if (ms % 1000 == 0) return '${ms ~/ 1000}秒';
    return '${(ms / 1000).toStringAsFixed(1)}秒';
  }

  Future<void> _selectBurnDuration() async {
    final options = <int>[
      5000,
      10000,
      30000,
      60000,
      300000,
      600000,
    ];
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('buttonCancel'.tr),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            setState(() => _burnAfterMs = options[tempIndex]);
                            await _persistBurnSetting();
                            EasyLoading.showToast('tipSuccess'.tr);
                          },
                          child: Text('buttonConfirm'.tr),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => tempIndex = i,
                      children: options
                          .map((ms) => Center(child: Text(_formatBurnAfterMs(ms))))
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
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (iconColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
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
                        subtitle!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建现代化开关列表项
  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged, {
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
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      onTap: () => onChanged(!value),
    );
  }

  /// 构建设置列表
  List<Widget> _buildSettingsList(BuildContext context) {
    return [
      _buildSwitchTile(
        '阅后即焚',
        _burnEnabled,
        (v) async {
          setState(() => _burnEnabled = v);
          await _persistBurnSetting();
          EasyLoading.showToast(v ? '已开启' : '已关闭');
        },
        icon: Icons.local_fire_department_outlined,
        iconColor: Theme.of(context).colorScheme.error,
        subtitle: _burnEnabled
            ? '开启后：消息在被阅读后 ${_formatBurnAfterMs(_burnAfterMs)} 自动销毁'
            : '关闭后：消息不会自动销毁',
        isFirst: true,
      ),
      if (_burnEnabled)
        _buildSettingTile(
          title: '销毁时间',
          icon: Icons.timer_outlined,
          subtitle: _formatBurnAfterMs(_burnAfterMs),
          onTap: _selectBurnDuration,
          trailing: Text(
            _formatBurnAfterMs(_burnAfterMs),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),
      _buildSwitchTile(
        '可视阈值已读',
        _enableVisibilityRead,
        (v) async {
          setState(() => _enableVisibilityRead = v);
          await _persistVisibilityReadSetting();
          EasyLoading.showToast(v ? '已开启' : '已关闭');
        },
        icon: Icons.visibility,
        iconColor: Theme.of(context).colorScheme.primary,
        subtitle: _enableVisibilityRead
            ? '开启后：可见比例≥${(_visibilityReadFraction * 100).toStringAsFixed(0)}%，持续≥${_visibilityReadDelayMs}ms'
            : '关闭后：不会基于可视自动已读',
        isFirst: true,
      ),
      if (_enableVisibilityRead)
        _buildSettingTile(
          title: '已读阈值与延时',
          icon: Icons.tune,
          subtitle: '可见比例: ${(_visibilityReadFraction * 100).toStringAsFixed(0)}% | 延时: ${_visibilityReadDelayMs}ms',
          onTap: () async {
            final fracCtl = TextEditingController(text: _visibilityReadFraction.toStringAsFixed(2));
            final delayCtl = TextEditingController(text: _visibilityReadDelayMs.toString());
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  '配置可视阈值',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fracCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '可见比例 (0.1~1.0)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: delayCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '延时毫秒 (>=100)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'buttonCancel'.tr,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      double f = double.tryParse(fracCtl.text.trim()) ?? _visibilityReadFraction;
                      int d = int.tryParse(delayCtl.text.trim()) ?? _visibilityReadDelayMs;
                      // 约束到合理范围
                      if (f.isNaN) f = 0.6;
                      if (f < 0.1) f = 0.1;
                      if (f > 1.0) f = 1.0;
                      if (d < 100) d = 100;
                      setState(() {
                        _visibilityReadFraction = f;
                        _visibilityReadDelayMs = d;
                      });
                      await _persistVisibilityReadSetting();
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      EasyLoading.showSuccess('tipSuccess'.tr);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('buttonConfirm'.tr),
                  ),
                ],
              ),
            );
          },
        ),
      _buildSettingTile(
        title: 'searchChatRecord'.tr,
        icon: Icons.search,
        isFirst: true,
        onTap: () {
          Get.to(
            () => SearchChatPage(
              type: widget.type,
              peerId: widget.options?['peer_id'],
              peerTitle: widget.options?['peerTitle'],
              peerAvatar: widget.options?['peerAvatar'],
              peerSign: widget.options?['peerSign'] ?? '',
              conversationUk3: widget.options?['conversationUk3'],
            ),
            transition: Transition.rightToLeft,
            popGesture: true,
          );
        },
      ),
      _buildSettingTile(
        title: 'clearChatRecord'.tr,
        icon: Icons.delete_sweep_outlined,
        isDestructive: true,
        isFirst: true,
        onTap: () {
          String tips = 'confirmDeleteChatRecord'.tr;
          showDialog(
            context: Get.context!,
            barrierDismissible: true,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: Theme.of(dialogContext).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'warning'.tr,
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
                  child: Text('buttonCancel'.tr),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton(
                  child: Text('buttonConfirm'.tr),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    int cid = await logic.cleanMessageByPeerId(
                      widget.type,
                      widget.peerId,
                    );
                    if (cid > 0) {
                      backDoRefresh = true;
                      await Get.find<ConversationLogic>().hideConversation(cid);
                      await Get.find<ConversationLogic>().conversationsList();
                      EasyLoading.showSuccess('tipSuccess'.tr);
                    } else {
                      EasyLoading.showError('tipFailed'.tr);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  void getInfo() async {
    // final info = await getUsersProfile([widget.id]);
    // List infoList = json.decode(info);
    // setState(() {
    //   model = PersonEntity.fromJson(infoList[0]);
    // });
  }

  @override
  Widget build(BuildContext context) {
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
            Get.back(result: backDoRefresh);
          },
        ),
        titleWidget: Text(
          'chatSettings'.tr,
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
    Get.delete<ChatSettingLogic>();
    super.dispose();
  }
}
