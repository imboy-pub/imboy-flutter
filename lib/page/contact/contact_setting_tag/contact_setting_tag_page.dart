import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_page.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'contact_setting_tag_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 联系人标签设置页面
class ContactSettingTagPage extends ConsumerStatefulWidget {
  final String peerId; // 用户ID
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

    // 初始化时设置按钮状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactSettingTagProvider.notifier).valueOnChange(false);
    });

    // 设置备注文本
    final remark = parseModelString(widget.peerRemark);
    ref.read(contactSettingTagProvider.notifier).remarkTextController.text =
        remark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.watch(contactSettingTagProvider);
    final controller = ref.read(contactSettingTagProvider.notifier);

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        title: t.setParam(param: t.remarksTags),
        automaticallyImplyLeading: true,
        rightDMActions: [
          TextButton(
            onPressed: notifier.valueChanged
                ? () async {
                    String trimmedText = controller.remarkTextController.text
                        .trim();
                    if (trimmedText.isNotEmpty) {
                      bool res = await controller.changeRemark(
                        widget.peerId,
                        trimmedText,
                      );
                      if (res) {
                        EasyLoading.showSuccess(t.tipSuccess);
                        widget.onRemarkChanged?.call(trimmedText);
                        if (mounted) {
                          Navigator.of(context).pop(trimmedText);
                        }
                      }
                    }
                  }
                : null, // 如果 valueChanged 为 false，则禁用按钮
            child: Text(
              t.buttonAccomplish,
              style: TextStyle(
                color: notifier.valueChanged
                    ? AppColors.primary
                    : colorScheme.outline.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: AppRadius.borderRadiusMedium,
              // DESIGN.md §5.2 + §8.3：表单容器靠 surface 对比，不用投影
            ),
            child: TextFormField(
              decoration: InputDecoration(
                labelText: t.remark,
                border: InputBorder.none,
                labelStyle: TextStyle(color: colorScheme.primary),
              ),
              autofocus: true,
              focusNode: controller.remarkFocusNode,
              controller: controller.remarkTextController,
              keyboardType: TextInputType.text,
              maxLength: 40,
              onChanged: (value) {
                controller.valueOnChange(
                  value.trim().isNotEmpty && widget.peerRemark != value,
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: AppRadius.borderRadiusMedium,
              // DESIGN.md §5.2 + §8.3：表单容器靠 surface 对比，不用投影
            ),
            child: ListTile(
              title: Text(
                t.tags,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: _currentTag.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _currentTag.split(',').map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderRadiusTiny,
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentTag.isEmpty)
                    Text(
                      t.addTag,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.outline,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => UserTagRelationPage(
                      peerId: widget.peerId,
                      peerTag: _currentTag,
                      scene: 'friend',
                    ),
                  ),
                ).then((value) {
                  if (value != null && value is String) {
                    setState(() {
                      _currentTag = value;
                    });
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
