import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'apply_friend_provider.dart';

/// 申请添加好友页面
class ApplyFriendPage extends ConsumerStatefulWidget {
  final String uid;
  final String remark;
  final String avatar;
  final String region;
  final String source;

  const ApplyFriendPage(
    this.uid,
    this.remark,
    this.avatar,
    this.region, {
    required this.source,
    super.key,
  });

  @override
  ConsumerState<ApplyFriendPage> createState() => _ApplyFriendPageState();
}

class _ApplyFriendPageState extends ConsumerState<ApplyFriendPage> {
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _msgController.text = "${t.iAm} ${UserRepoLocal.to.current.nickname}";
    _remarkController.text = widget.remark;
  }

  @override
  void dispose() {
    _msgController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  /// 构建输入框卡片
  Widget _buildInputCard({
    required BuildContext context,
    required String title,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    int? minLines,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 输入框
            TextField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              maxLength: maxLength,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
                counterStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建设置项卡片
  Widget _buildSettingCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusRegular,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建选项卡片
  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // 选项列表
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 构建包含 RadioGroup 的选项卡片
  Widget _buildRadioOptionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final providerState = ref.watch(applyFriendProvider);

    return _buildOptionCard(
      context: context,
      title: title,
      icon: icon,
      children: children.map((child) {
        // 如果是 RadioListTile，设置初始值
        if (child is RadioListTile<String>) {
          return RadioListTile<String>(
            title: child.title,
            value: child.value,
            // ignore: deprecated_member_use
            groupValue: providerState.role,
            // ignore: deprecated_member_use
            onChanged: (val) {
              if (val != null) {
                ref.read(applyFriendProvider.notifier).setRole(val);
              }
            },
            activeColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMedium,
            ),
          );
        }
        return child;
      }).toList(),
    );
  }

  /// 构建开关项
  Widget _buildSwitchOption(
    BuildContext context,
    String title,
    bool switchValue,
    bool isLast,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      decoration: BoxDecoration(borderRadius: AppRadius.borderRadiusMedium),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          value: switchValue,
          onChanged: onChanged,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMedium,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(applyFriendProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: GlassAppBar(
        titleWidget: Text(
          t.applyAddFriend,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 验证消息输入
            _buildInputCard(
              context: context,
              title: t.sendFriendRequest,
              hint: t.pleaseEnterVerificationMessage,
              controller: _msgController,
              icon: Icons.message_outlined,
              minLines: 3,
              maxLines: 4,
              maxLength: 100,
            ),
            // 备注设置
            _buildInputCard(
              context: context,
              title: t.setParam(param: t.remark),
              hint: t.pleaseEnterRemark,
              controller: _remarkController,
              icon: Icons.edit_outlined,
              maxLength: 80,
            ),
            // 标签设置
            _buildSettingCard(
              context: context,
              title: t.tags,
              subtitle: providerState.peerTag.isEmpty
                  ? t.addTag
                  : providerState.peerTag,
              icon: Icons.local_offer_outlined,
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => UserTagRelationPage(
                      peerId: widget.uid,
                      peerTag: providerState.peerTag.isEmpty
                          ? ''
                          : providerState.peerTag,
                      scene: 'friend',
                    ),
                  ),
                );
                if (result != null && result is String) {
                  ref.read(applyFriendProvider.notifier).updateTag(result);
                }
              },
            ),
            const SizedBox(height: 8),
            // 朋友圈权限设置
            _buildRadioOptionCard(
              context: context,
              title: t.setParam(param: t.moment),
              icon: Icons.photo_library_outlined,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: RadioListTile<String>(
                      title: Text(
                        t.chatMomentSportDataEtc,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      value: 'all',
                      activeColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusMedium,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: RadioListTile<String>(
                      title: Text(
                        t.justChat,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      value: 'just_chat',
                      activeColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // 朋友圈可见性设置
            if (providerState.visibilityLook)
              _buildOptionCard(
                context: context,
                title: t.momentStatus,
                icon: Icons.visibility_outlined,
                children: [
                  _buildSwitchOption(
                    context,
                    t.notLetHimSee,
                    providerState.donotlethimlook,
                    false,
                    (val) {
                      ref
                          .read(applyFriendProvider.notifier)
                          .toggleDonotLetHimLook(val);
                    },
                  ),
                  _buildSwitchOption(
                    context,
                    t.notSeeHim,
                    providerState.donotlookhim,
                    true,
                    (val) {
                      ref
                          .read(applyFriendProvider.notifier)
                          .toggleDonotLookHim(val);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 100), // 为底部按钮留出空间
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                Map<String, dynamic> payload = {
                  "from": {
                    "source": widget.source,
                    "msg": _msgController.text,
                    "remark": _remarkController.text,
                    "account": UserRepoLocal.to.current.account,
                    "nickname": UserRepoLocal.to.current.nickname,
                    "avatar": UserRepoLocal.to.current.avatar,
                    "sign": UserRepoLocal.to.current.sign,
                    "gender": UserRepoLocal.to.current.gender,
                    "region": UserRepoLocal.to.current.region,
                    "role": providerState.role,
                    "donotlookhim": providerState.donotlookhim,
                    "donotlethimlook": providerState.donotlethimlook,
                    "tag": providerState.peerTag.isEmpty
                        ? ''
                        : "${providerState.peerTag},",
                  },
                  "to": {},
                };

                final success = await ref
                    .read(applyFriendProvider.notifier)
                    .apply(
                      to: widget.uid,
                      peerNickname: widget.remark,
                      peerAvatar: widget.avatar,
                      payload: payload,
                    );

                if (success && context.mounted) {
                  nav.pop();
                  nav.pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusXLarge,
                ),
              ),
              child: Text(
                t.buttonSend,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
