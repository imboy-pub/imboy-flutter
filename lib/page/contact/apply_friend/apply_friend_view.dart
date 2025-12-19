import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'apply_friend_logic.dart';

// ignore: must_be_immutable
class ApplyFriendPage extends StatelessWidget {
  String uid;
  String remark;
  String avatar;
  String region;
  String source;

  ApplyFriendPage(
      this.uid,
      this.remark,
      this.avatar,
      this.region, {
        required this.source,
        super.key,
      });

  final ApplyFriendLogic logic = Get.put(ApplyFriendLogic());

  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

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
        borderRadius: BorderRadius.circular(16),
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
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(16),
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
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
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

  /// 构建单选项
  Widget _buildRadioOption(BuildContext context, String title, String value, bool isLast) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: RadioListTile<String>(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          value: value,
          groupValue: logic.role.value,
          onChanged: (val) {
            if (val == null) return;
            logic.setRole(val);
            if (val == 'all') {
              logic.visibilityLook.value = true;
            } else {
              logic.visibilityLook.value = false;
              logic.donotlethimlook.value = false;
              logic.donotlookhim.value = false;
            }
          },
          activeColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// 构建开关项
  Widget _buildSwitchOption(BuildContext context, String title, RxBool switchValue, bool isLast) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
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
          value: switchValue.value,
          onChanged: (val) {
            switchValue.value = val;
          },
          activeColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _msgController.text = "${'iAm'.tr} ${UserRepoLocal.to.current.nickname}";
    _remarkController.text = remark;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          'applyAddFriend'.tr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(
        () => SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              
              // 验证消息输入
              _buildInputCard(
                context: context,
                title: 'sendFriendRequest'.tr,
                hint: '请输入验证消息',
                controller: _msgController,
                icon: Icons.message_outlined,
                minLines: 3,
                maxLines: 4,
                maxLength: 100,
              ),
              
              // 备注设置
              _buildInputCard(
                context: context,
                title: 'setParam'.trArgs(['remark'.tr]),
                hint: '请输入备注名',
                controller: _remarkController,
                icon: Icons.edit_outlined,
                maxLength: 80,
              ),
              
              // 标签设置
              _buildSettingCard(
                context: context,
                title: 'tags'.tr,
                subtitle: logic.peerTag.isEmpty ? 'addTag'.tr : logic.peerTag.value,
                icon: Icons.local_offer_outlined,
                onTap: () {
                  Get.to(
                    () => UserTagRelationPage(
                      peerId: uid,
                      peerTag: logic.peerTag.isEmpty ? '' : logic.peerTag.value,
                      scene: 'friend',
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  )?.then((value) {
                    if (value != null && value is String) {
                      logic.peerTag.value = value;
                    }
                  });
                },
              ),
              
              const SizedBox(height: 8),
              
              // 朋友圈权限设置
              _buildOptionCard(
                context: context,
                title: 'setParam'.trArgs(['moment'.tr]),
                icon: Icons.photo_library_outlined,
                children: [
                  _buildRadioOption(context, 'chatMomentSportDataEtc'.tr, 'all', false),
                  _buildRadioOption(context, 'justChat'.tr, 'just_chat', true),
                ],
              ),
              
              // 朋友圈可见性设置
              if (logic.visibilityLook.isTrue)
                _buildOptionCard(
                  context: context,
                  title: 'momentStatus'.tr,
                  icon: Icons.visibility_outlined,
                  children: [
                    _buildSwitchOption(context, 'notLetHimSee'.tr, logic.donotlethimlook, false),
                    _buildSwitchOption(context, 'notSeeHim'.tr, logic.donotlookhim, true),
                  ],
                ),
              
              const SizedBox(height: 100), // 为底部按钮留出空间
            ],
          ),
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
                    "source": source,
                    "msg": _msgController.text,
                    "remark": _remarkController.text,
                    "account": UserRepoLocal.to.current.account,
                    "nickname": UserRepoLocal.to.current.nickname,
                    "avatar": UserRepoLocal.to.current.avatar,
                    "sign": UserRepoLocal.to.current.sign,
                    "gender": UserRepoLocal.to.current.gender,
                    "region": UserRepoLocal.to.current.region,
                    "role": logic.role.value,
                    "donotlookhim": logic.donotlookhim.isTrue,
                    "donotlethimlook": logic.donotlethimlook.isTrue,
                    "tag": logic.peerTag.isEmpty ? '' : "${logic.peerTag.value},",
                  },
                  "to": {}
                };
                await logic.apply(
                  to: uid,
                  peerNickname: remark,
                  peerAvatar: avatar,
                  payload: payload,
                );
                nav.pop();
                nav.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'buttonSend'.tr,
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