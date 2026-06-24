import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_relation_page.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'contact_setting_tag_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 联系人标签设置页面 - 像素级对齐 iOS 17 Premium 风格
class ContactSettingTagPage extends ConsumerStatefulWidget {
  final String peerId;
  final String peerAccount;
  final String peerAvatar;
  final String peerTitle;
  final String peerNickname;
  final int peerGender;
  final String peerSign;
  final String peerRegion;
  final String peerSource;
  final String peerRemark;
  final String peerTag;
  final void Function(String)? onRemarkChanged;

  const ContactSettingTagPage({
    super.key,
    required this.peerId,
    required this.peerAccount,
    required this.peerAvatar,
    required this.peerNickname,
    required this.peerGender,
    required this.peerTitle,
    required this.peerSign,
    required this.peerRegion,
    required this.peerSource,
    required this.peerRemark,
    required this.peerTag,
    this.onRemarkChanged,
  });

  @override
  ConsumerState<ContactSettingTagPage> createState() =>
      _ContactSettingTagPageState();
}

class _ContactSettingTagPageState extends ConsumerState<ContactSettingTagPage> {
  late String _currentTag;

  @override
  void initState() {
    super.initState();
    _currentTag = widget.peerTag;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactSettingTagProvider.notifier).valueOnChange(false);
    });
    ref.read(contactSettingTagProvider.notifier).remarkTextController.text =
        parseModelString(widget.peerRemark);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(contactSettingTagProvider);
    final controller = ref.read(contactSettingTagProvider.notifier);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.main.setParam(param: t.contact.remarksTags),
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: notifier.valueChanged
              ? () async {
                  final trimmedText = controller.remarkTextController.text
                      .trim();
                  if (trimmedText.isNotEmpty &&
                      await controller.changeRemark(
                        widget.peerId,
                        trimmedText,
                      )) {
                    AppLoading.showSuccess(t.common.tipSuccess);
                    widget.onRemarkChanged?.call(trimmedText);
                    if (context.mounted) Navigator.of(context).pop(trimmedText);
                  }
                }
              : null,
          child: Text(
            t.common.buttonAccomplish,
            style: TextStyle(
              fontWeight: notifier.valueChanged
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: notifier.valueChanged
                  ? AppColors.getIosBlue(brightness)
                  : AppColors.iosGray,
            ),
          ),
        ),
      ],
      child: Column(
        children: [
          // 备注 Section
          ImBoySettingsSection(
            header: Text(t.contact.remark.toUpperCase()),
            children: [
              CupertinoListTile.notched(
                title: CupertinoTextField(
                  controller: controller.remarkTextController,
                  focusNode: controller.remarkFocusNode,
                  autofocus: true,
                  maxLength: 40,
                  placeholder: t.contact.remark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: null,
                  style: context.textStyle(FontSizeType.medium),
                  onChanged: (v) => controller.valueOnChange(
                    v.trim().isNotEmpty && widget.peerRemark != v,
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
                subtitle: _currentTag.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _currentTag
                              .split(',')
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tag,
                                    style: context.textStyle(
                                      FontSizeType.small,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentTag.isEmpty)
                      Text(
                        t.common.addTag,
                        style: context.textStyle(
                          FontSizeType.normal,
                          color: AppColors.iosGray,
                        ),
                      ),
                    AppSpacing.horizontalTiny,
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: AppColors.iosGray3,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute<dynamic>(
                      builder: (_) => TagRelationPage(
                        peerId: widget.peerId,
                        peerTag: _currentTag,
                        scene: 'friend',
                      ),
                    ),
                  ).then((value) {
                    if (value != null && value is String) {
                      setState(() => _currentTag = value);
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
