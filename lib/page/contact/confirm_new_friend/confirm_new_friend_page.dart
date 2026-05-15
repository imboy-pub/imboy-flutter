import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'confirm_new_friend_provider.dart';

/// 确认新好友页面 - 像素级对齐 iOS 17 Premium 风格
class ConfirmNewFriendPage extends ConsumerStatefulWidget {
  final String from;
  final String to;
  final String msg;
  final String nickname;
  final String payload;

  const ConfirmNewFriendPage({
    super.key,
    required this.from,
    required this.to,
    required this.msg,
    required this.nickname,
    required this.payload,
  });

  @override
  ConsumerState<ConfirmNewFriendPage> createState() => _ConfirmNewFriendPageState();
}

class _ConfirmNewFriendPageState extends ConsumerState<ConfirmNewFriendPage> {
  final TextEditingController _remarkC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _remarkC.text = widget.nickname;
  }

  @override
  void dispose() {
    _remarkC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(confirmNewFriendProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return IosPageTemplate(
      title: t.common.acceptFriendRequest,
      useLargeTitle: false,
      bottomWidget: _buildBottomButton(context, providerState),
      child: Column(
        children: [
          // 验证消息 Section
          ImBoySettingsSection(
            header: Text(t.common.verificationMessage.toUpperCase()),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Text(
                  '"${widget.msg}"',
                  style: const TextStyle(fontSize: 16, height: 1.4, fontStyle: FontStyle.italic, color: AppColors.iosGray),
                ),
              ),
            ],
          ),

          // 备注 Section
          ImBoySettingsSection(
            header: Text(t.main.setParam(param: t.contact.remark).toUpperCase()),
            children: [
              CupertinoListTile.notched(
                title: Row(
                  children: [
                    const SizedBox(width: 80, child: Text('备注', style: TextStyle(fontSize: 17))),
                    Expanded(
                      child: CupertinoTextField(
                        controller: _remarkC,
                        placeholder: t.contact.enterRemark,
                        maxLength: 80,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 标签 Section
          ImBoySettingsSection(
            header: Text(t.contact.tags.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.contact.tags),
                subtitle: Text(providerState.peerTag.isEmpty ? t.common.addTag : providerState.peerTag),
                leading: const Icon(CupertinoIcons.tag_fill, color: AppColors.iosBlue, size: 20),
                onTap: () async {
                  final result = await Navigator.push(context, CupertinoPageRoute<dynamic>(builder: (_) => UserTagRelationPage(peerId: widget.from, peerTag: providerState.peerTag, scene: 'friend')));
                  if (result != null && result is String) ref.read(confirmNewFriendProvider.notifier).updateTag(result);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, dynamic providerState) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () async {
            Map<String, dynamic> p2 = json.decode(widget.payload) as Map<String, dynamic>;
            p2['to'] = {
              "remark": _remarkC.text, "account": UserRepoLocal.to.current.account, "nickname": UserRepoLocal.to.current.nickname,
              "avatar": UserRepoLocal.to.current.avatar, "sign": UserRepoLocal.to.current.sign, "gender": UserRepoLocal.to.current.gender,
              "role": providerState.role, "donotlookhim": providerState.donotlookhim, "donotlethimlook": providerState.donotlethimlook,
              "tag": providerState.peerTag.isEmpty ? '' : "${providerState.peerTag},",
            };
            if (await ref.read(confirmNewFriendProvider.notifier).confirm(from: widget.from, to: widget.to, payload: p2) && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Text(t.common.buttonAccomplish, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
