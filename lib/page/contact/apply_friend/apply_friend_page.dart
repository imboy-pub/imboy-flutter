import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'apply_friend_provider.dart';

/// 申请添加好友页面 - 像素级对齐 iOS 17 Premium 风格
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
  final TextEditingController _msgC = TextEditingController();
  final TextEditingController _remarkC = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _msgC.text = "${t.main.iAm} ${UserRepoLocal.to.current.nickname}";
    _remarkC.text = widget.remark;
  }

  @override
  void dispose() {
    _msgC.dispose();
    _remarkC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(applyFriendProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.applyAddFriend,
      useLargeTitle: false,
      bottomWidget: _buildSubmitButton(context, providerState),
      child: Column(
        children: [
          // 验证消息 Section
          ImBoySettingsSection(
            header: Text(t.chat.sendFriendRequest.toUpperCase()),
            children: [
              CupertinoListTile.notched(
                title: Expanded(
                  child: CupertinoTextField(
                    controller: _msgC,
                    placeholder: t.common.pleaseEnterVerificationMessage,
                    minLines: 3, maxLines: 5, maxLength: 100,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: null,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),

          // 备注 Section
          ImBoySettingsSection(
            header: Text(t.main.setParam(param: t.contact.remark).toUpperCase()),
            children: [
              CupertinoListTile.notched(
                title: const SizedBox(width: 80, child: Text('备注', style: TextStyle(fontSize: 17))),
                additionalInfo: Expanded(
                  child: CupertinoTextField(
                    controller: _remarkC,
                    placeholder: t.contact.pleaseEnterRemark,
                    maxLength: 80,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: null,
                    style: const TextStyle(fontSize: 17),
                  ),
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
                onTap: () async {
                  final result = await Navigator.push(context, CupertinoPageRoute<dynamic>(builder: (_) => UserTagRelationPage(peerId: widget.uid, peerTag: providerState.peerTag, scene: 'friend')));
                  if (result != null && result is String) ref.read(applyFriendProvider.notifier).updateTag(result);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, dynamic providerState) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isSubmitting ? null : () async {
            setState(() => _isSubmitting = true);
            try {
              final nav = Navigator.of(context);
              Map<String, dynamic> payload = {
                "from": {
                  "source": widget.source, "msg": _msgC.text, "remark": _remarkC.text,
                  "account": UserRepoLocal.to.current.account, "nickname": UserRepoLocal.to.current.nickname,
                  "avatar": UserRepoLocal.to.current.avatar, "sign": UserRepoLocal.to.current.sign,
                  "gender": UserRepoLocal.to.current.gender, "region": UserRepoLocal.to.current.region,
                  "role": providerState.role, "donotlookhim": providerState.donotlookhim, "donotlethimlook": providerState.donotlethimlook,
                  "tag": providerState.peerTag.isEmpty ? '' : "${providerState.peerTag},",
                },
                "to": <String, dynamic>{},
              };
              if (await ref.read(applyFriendProvider.notifier).apply(to: widget.uid, peerNickname: widget.remark, peerAvatar: widget.avatar, payload: payload)) {
                nav.pop(); nav.pop();
              }
            } finally { if (mounted) setState(() => _isSubmitting = false); }
          },
          child: _isSubmitting ? const CupertinoActivityIndicator(color: Colors.white) : Text(t.common.buttonSend, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
