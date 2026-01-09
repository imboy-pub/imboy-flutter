import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_view.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'contact_setting_tag_logic.dart';

// ignore: must_be_immutable
class ContactSettingTagPage extends StatelessWidget {
  final String peerId; // 用户ID
  final String peerAccount;
  final String peerAvatar;
  final String peerTitle;
  final String peerNickname;
  final int peerGender;
  final String peerSign;
  final String peerRegion;
  final String peerSource;
  String peerRemark;
  Rx<String> peerTag;

  ContactSettingTagPage({
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
  });

  final logic = Get.put(ContactSettingTagPageLogic());

  @override
  Widget build(BuildContext context) {
    // 初始化时设置按钮状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logic.valueOnChange(false);
    });

    logic.remarkTextController.text = (peerRemark == 'null') ? '' : peerRemark;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(
      () => Scaffold(
        backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
        appBar: GlassAppBar(
          title: 'setParam'.trArgs(['remarksTags'.tr]),
          automaticallyImplyLeading: true,
          rightDMActions: [
            TextButton(
              onPressed: logic.valueChanged.isTrue
                  ? () async {
                      String trimmedText = logic.remarkTextController.text.trim();
                      if (trimmedText.isNotEmpty) {
                        bool res = await logic.changeRemark(peerId, trimmedText);
                        if (res) {
                          EasyLoading.showSuccess('tipSuccess'.tr);
                          peerRemark = trimmedText;
                          Get.back(result: trimmedText);
                        }
                      }
                    }
                  : null, // 如果 valueChanged 为 false，则禁用按钮
              child: Text(
                'buttonAccomplish'.tr,
                style: TextStyle(
                  color: logic.valueChanged.isTrue
                      ? AppColors.primaryGreen
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
                borderRadius: BorderRadius.circular(12),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'remark'.tr,
                  border: InputBorder.none,
                  labelStyle: TextStyle(
                    color: colorScheme.primary,
                  ),
                ),
                autofocus: true,
                focusNode: logic.remarkFocusNode,
                controller: logic.remarkTextController,
                keyboardType: TextInputType.text,
                maxLength: 40,
                onChanged: (value) {
                  logic.valueOnChange(value.trim().isNotEmpty && peerRemark != value);
                },
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ListTile(
                title: Text(
                  'tags'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: peerTag.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: peerTag.value.split(',').map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (peerTag.isEmpty)
                      Text(
                        'addTag'.tr,
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
                  Get.to(
                    () => UserTagRelationPage(
                      peerId: peerId,
                      peerTag: peerTag.value,
                      scene: 'friend',
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  )?.then((value) {
                    if (value != null && value is String) {
                      peerTag.value = value;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
