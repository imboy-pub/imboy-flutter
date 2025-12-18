import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
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
    String? subtitle,
  }) {
    return _buildSettingTile(
      title: title,
      icon: icon,
      subtitle: subtitle,
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
      // 阅读回执（可视阈值）说明
      _buildSettingTile(
        title: '阅读回执（可视阈值）说明',
        icon: Icons.info_outline,
        iconColor: Theme.of(context).colorScheme.primary,
        subtitle: '开启后：对方消息在屏幕内可见比例≥${(_visibilityReadFraction * 100).toStringAsFixed(0)}%，且持续≥${_visibilityReadDelayMs}ms，才视为"已读"。\n'
                '关闭后：不会基于可视自动已读，只能通过"标记已读"等操作清除。\n'
                '说明：仅在本机生效，用于计算未读数（基于已读水位），不向对端自动上报。',
        isFirst: true,
      ),
      // 可视阈值已读开关
      _buildSwitchTile(
        '可视阈值已读',
        _enableVisibilityRead,
        (v) async {
          setState(() => _enableVisibilityRead = v);
          await _persistVisibilityReadSetting();
          EasyLoading.showToast(v ? '已开启' : '已关闭');
        },
        icon: Icons.visibility,
        subtitle: '自动标记消息为已读',
      ),
      // 配置阈值与延时
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
                    'button_cancel'.tr,
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
                    EasyLoading.showSuccess('tip_success'.tr);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('button_confirm'.tr),
                ),
              ],
            ),
          );
        },
      ),
      _buildSettingTile(
        title: 'search_chat_record'.tr,
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
        title: 'clear_chat_record'.tr,
        icon: Icons.delete_sweep_outlined,
        isDestructive: true,
        isFirst: true,
        onTap: () {
          String tips = 'confirm_delete_chat_record'.tr;
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
                  child: Text('button_cancel'.tr),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton(
                  child: Text('button_confirm'.tr),
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
                      EasyLoading.showSuccess('tip_success'.tr);
                    } else {
                      EasyLoading.showError('tip_failed'.tr);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(dialogContext).colorScheme.onError,
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.1),
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
        title: Text(
          'chat_settings'.tr,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
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
