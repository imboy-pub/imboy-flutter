import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_relation_view.dart' show TagRelationPage;

import 'package:imboy/page/chat/send_to/send_to_view.dart';
import 'package:imboy/page/personal_info/update/update_view.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';

import 'package:xid/xid.dart';

import 'user_collect_logic.dart';

// ignore: must_be_immutable
class UserCollectDetailPage extends StatelessWidget {
  int pageIndex;
  UserCollectModel obj;

  UserCollectDetailPage({
    super.key,
    required this.obj,
    required this.pageIndex,
  });

  // final logic = Get.put(UserCollectLogic());
  final logic = Get.find<UserCollectLogic>();
  RxString remark = "".obs;

  Widget buildRightItems(BuildContext txt) {
    List<Widget> rightItems = [
      Center(
        child: TextButton(
          child: Text(
            'forward_to_friend'.tr,
            textAlign: TextAlign.center,
            // style: TextStyle(
            //   fontSize: AppTextSize.medium,
            //   fontWeight: FontWeight.normal,
            // ),
          ),
          onPressed: () async {
            Get.closeAllBottomSheets();
            obj.info['id'] = Xid().toString();
            var msg = await MessageModel.fromJson(obj.info).toTypeMessage();
            // 转发消息
            Get.to(
              () => SendToPage(msg: msg),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            )?.then((value) {
              logic.change(obj.kindId);
            });
            // Get.bottomSheet(
            //   n.Padding(
            //     top: 24,
            //     child: SendToPage(
            //         msg: await MessageModel.fromJson(obj.info).toTypeMessage(),
            //         callback: () {
            //           logic.change(obj.kindId);
            //         }),
            //   ),
            //   // 是否支持全屏弹出，默认false
            //   isScrollControlled: true,
            //   // enableDrag: false,
            // );
          },
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: 16, right: 16),
        child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
      ),
      Center(
        child: TextButton(
          onPressed: () {
            Get.closeAllBottomSheets();
            Get.to(
              () => TagRelationPage(
                peerId: obj.kindId,
                peerTag: obj.tag,
                scene: 'collect',
                title: 'edit_tag'.tr,
              ),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            )?.then((value) {
              // iPrint(
              //     "UserCollectDetailPage_TagAddPage_back then $value");
              if (value != null && value is String) {
                obj.tag = value.toString();
                logic.updateItem(obj);
                Get.back();
              }
            });
          },
          child: Text(
            'edit_tag'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(txt).colorScheme.onPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: 16, right: 16),
        child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
      ),
      Center(
        child: TextButton(
          onPressed: () {
            Get.closeAllBottomSheets();
            Get.to(
              () => UpdatePage(
                  title: 'set_param'.trArgs(['remark'.tr]),
                  value: obj.remark,
                  field: 'text',
                  maxLength: 100,
                  callback: (remarkNew) async {
                    bool ok = await logic.remark(obj.kindId, remarkNew);
                    if (ok) {
                      remark.value = remarkNew;
                      obj.remark = remarkNew;
                    }
                    return ok;
                  }),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            )?.then((value) {
              // iPrint(
              //     "UserCollectDetailPage_TagAddPage_back then $value");
              if (value != null && value is String) {
                obj.tag = value.toString();
                logic.updateItem(obj);
                Get.back();
              }
            });
          },
          child: Text(
            'set_param'.trArgs(['remark'.tr]),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(txt).colorScheme.onPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: 16, right: 16),
        child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
      ),
      Center(
        child: TextButton(
          onPressed: () async {
            Get.closeAllBottomSheets();
            bool res = await logic.remove(obj);
            if (res) {
              logic.state.items.removeAt(pageIndex);
              Get.back();
            }
          },
          child: Text(
            'button_delete'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
      const HorizontalLine(height: 6),
      Center(
        child: TextButton(
          onPressed: () => Get.close(),
          child: Text(
            'button_cancel'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(txt).colorScheme.onPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: 16, right: 16),
        child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
      )
    ];
    if (obj.kind == 1) {
      rightItems.insertAll(0, [
        Center(
          child: TextButton(
            child: Text(
              'button_copy'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(txt).colorScheme.onPrimary,
                fontSize: 16.0,
                fontWeight: FontWeight.normal,
              ),
            ),
            onPressed: () async {
              Get.closeAllBottomSheets();
              // 复制消息
              final String txt = obj.info['payload']['text'] ?? '';
              if (txt.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: txt));
                EasyLoading.showToast('copied'.tr);
              }
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16),
          child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
        ),
      ]);
    }
    return Wrap(children: rightItems);
  }

  /// 构建操作菜单
  Widget _buildActionMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部指示器
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 16, bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 标题
            Text(
              '操作选项',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            
            // 复制按钮（仅文本类型）
            if (obj.kind == 1)
              _buildActionButton(
                context: context,
                icon: Icons.copy,
                title: 'button_copy'.tr,
                subtitle: '复制文本内容',
                onTap: () async {
                  Get.closeAllBottomSheets();
                  final String txt = obj.info['payload']['text'] ?? '';
                  if (txt.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: txt));
                    EasyLoading.showToast('copied'.tr);
                  }
                },
                iconColor: Theme.of(context).colorScheme.primary,
              ),
            
            // 转发给朋友
            _buildActionButton(
              context: context,
              icon: Icons.share,
              title: 'forward_to_friend'.tr,
              subtitle: '分享给其他好友',
              onTap: () async {
                Get.closeAllBottomSheets();
                obj.info['id'] = Xid().toString();
                var msg = await MessageModel.fromJson(obj.info).toTypeMessage();
                Get.to(
                  () => SendToPage(msg: msg),
                  transition: Transition.rightToLeft,
                  popGesture: true,
                )?.then((value) {
                  logic.change(obj.kindId);
                });
              },
              iconColor: Theme.of(context).colorScheme.secondary,
            ),
            
            // 编辑标签
            _buildActionButton(
              context: context,
              icon: Icons.local_offer,
              title: 'edit_tag'.tr,
              subtitle: '为收藏添加标签',
              onTap: () {
                Get.closeAllBottomSheets();
                Get.to(
                  () => TagRelationPage(
                    peerId: obj.kindId,
                    peerTag: obj.tag,
                    scene: 'collect',
                    title: 'edit_tag'.tr,
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true,
                )?.then((value) {
                  if (value != null && value is String) {
                    obj.tag = value.toString();
                    logic.updateItem(obj);
                    Get.back();
                  }
                });
              },
              iconColor: Theme.of(context).colorScheme.tertiary,
            ),
            
            // 设置备注
            _buildActionButton(
              context: context,
              icon: Icons.edit_note,
              title: 'set_param'.trArgs(['remark'.tr]),
              subtitle: '为收藏添加备注',
              onTap: () {
                Get.closeAllBottomSheets();
                Get.to(
                  () => UpdatePage(
                    title: 'set_param'.trArgs(['remark'.tr]),
                    value: obj.remark,
                    field: 'text',
                    maxLength: 100,
                    callback: (remarkNew) async {
                      bool ok = await logic.remark(obj.kindId, remarkNew);
                      if (ok) {
                        remark.value = remarkNew;
                        obj.remark = remarkNew;
                      }
                      return ok;
                    },
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true,
                );
              },
              iconColor: Theme.of(context).colorScheme.primary,
            ),
            
            // 删除
            _buildActionButton(
              context: context,
              icon: Icons.delete_outline,
              title: 'button_delete'.tr,
              subtitle: '删除此收藏',
              onTap: () async {
                Get.closeAllBottomSheets();
                bool res = await logic.remove(obj);
                if (res) {
                  logic.state.items.removeAt(pageIndex);
                  Get.back();
                }
              },
              iconColor: Theme.of(context).colorScheme.error,
              isDestructive: true,
            ),
            
            const SizedBox(height: 16),
            
            // 取消按钮
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Get.close(),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'button_cancel'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
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
                          color: isDestructive 
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    remark.value = obj.remark;

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'details'.tr,
        rightDMActions: [
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Get.bottomSheet(
                    _buildActionMenu(context),
                    isScrollControlled: true,
                  );
                },
                child: Icon(
                  Icons.more_horiz,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 来源信息卡片
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "${'from'.tr} ${obj.source} ${DateTimeHelper.lastTimeFmt(obj.createdAt)}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 备注信息卡片
            Obx(() => remark.value.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.edit_note,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${'remark'.tr}:",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          remark.value,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink()),
            
            // 内容卡片
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: logic.buildItemBody(obj, 'detail'),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
