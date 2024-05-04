import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/page/chat/send_to/send_to_view.dart';
import 'package:imboy/page/personal_info/update/update_view.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_view.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:niku/namespace.dart' as n;
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
            style: TextStyle(
              color: Theme.of(txt).colorScheme.onPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
            ),
          ),
          onPressed: () async {
            Get.closeAllBottomSheets();
            obj.info['id'] = Xid().toString();
            var msg = await MessageModel.fromJson(obj.info).toTypeMessage();
            // 转发消息
            Get.to(
              () => SendToPage(
                  msg: msg,
                  callback: () {
                    logic.change(obj.kindId);
                  }),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
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
      n.Padding(
        left: 16,
        right: 16,
        child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
      ),
      Center(
        child: TextButton(
          onPressed: () {
            Get.closeAllBottomSheets();
            Get.to(
              () => UserTagRelationPage(
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
      n.Padding(
        left: 16,
        right: 16,
        child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
      ),
      Center(
        child: TextButton(
          onPressed: () {
            Get.closeAllBottomSheets();
            Get.to(
              () => UpdatePage(
                  title: 'set_remark'.tr,
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
            'set_remark'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(txt).colorScheme.onPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
      n.Padding(
        left: 16,
        right: 16,
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
      n.Padding(
        left: 16,
        right: 16,
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
        n.Padding(
          left: 16,
          right: 16,
          child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
        ),
      ]);
    }
    return n.Wrap(rightItems);
  }

  @override
  Widget build(BuildContext context) {
    remark.value = obj.remark;

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'details'.tr,
        rightDMActions: [
          InkWell(
            onTap: () {
              Get.bottomSheet(
                SizedBox(
                  width: Get.width,
                  height: 304 + (obj.kind == 1 ? 64 : 0),
                  child: buildRightItems(context),
                ),
                backgroundColor: Get.isDarkMode
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                //改变shape这里即可
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
              );
            },
            // 三点更多 more icon
            child: n.Padding(
              left: 10,
              right: 10,
              child: const Icon(
                Icons.more_horiz,
                // size: 40,
              ),
            ),
          )
        ],
      ),
      body: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        width: Get.width,
        child: n.Column([
          n.Row([
            const Expanded(
                flex: 1,
                child: HorizontalLine(
                  height: 1,
                  color: Colors.black26,
                )),
            Expanded(
                flex: 2,
                child: Text(
                  "${'from'.tr} ${obj.source} ${DateTimeHelper.lastTimeFmt(obj.createdAtLocal)}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                )),
            const Expanded(
                flex: 1,
                child: HorizontalLine(
                  height: 1,
                  color: Colors.black26,
                )),
          ])
            // 内容居中
            ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
          Obx(() => Visibility(
              visible: remark.value.isNotEmpty,
              child: n.Column([
                n.Row([
                  Text(
                    "${'remark'.tr}: ",
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 16),
                  )
                ]),
                n.Padding(
                    top: 10,
                    bottom: 10,
                    child: n.Row([
                      Expanded(
                          flex: 2,
                          child: Text(
                            remark.value,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 13),
                          )),
                    ])
                      // 内容文本左对齐
                      ..crossAxisAlignment = CrossAxisAlignment.start),
                n.Row(const [
                  Expanded(
                      flex: 4,
                      child: HorizontalLine(
                        height: 1,
                        color: Colors.black26,
                      ))
                ]),
              ]))),
          Expanded(
              child: n.Padding(
                  top: 10,
                  bottom: 10,
                  child: logic.buildItemBody(obj, 'detail'))),
          n.Row([
            const Expanded(
                child: HorizontalLine(
              height: 1,
              color: Colors.black26,
            )),
            n.Padding(
              left: 4,
              right: 4,
              child: const Icon(Icons.circle, size: 4),
            ),
            const Expanded(
                child: HorizontalLine(
              height: 1,
              color: Colors.black26,
            )),
          ])
        ], mainAxisSize: MainAxisSize.min),
      ),
    );
  }
}
