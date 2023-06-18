import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:niku/namespace.dart' as n;

import 'user_collect_logic.dart';

// ignore: must_be_immutable
class UserCollectDetailPage extends StatelessWidget {
  int pageIndex;
  UserCollectModel obj;
  UserCollectDetailPage({super.key, required this.obj, required this.pageIndex});

  final logic = Get.put(UserCollectLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: '详情'.tr,
        rightDMActions: [
          InkWell(
            onTap: () {
              Get.bottomSheet(
                SizedBox(
                  width: Get.width,
                  height: 240,
                  child: n.Wrap(
                    [
                      Center(
                        child: TextButton(
                          child: Text(
                            '转发给朋友'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              // color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onPressed: () async {},
                        ),
                      ),
                      const Divider(),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            // Get.back();
                            // Get.to(()=>
                            // const ScannerPage(),
                            //   transition: Transition.rightToLeft,
                            //   popGesture: true, // 右滑，返回上一页
                            // );
                          },
                          child: Text(
                            '编辑标签'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              // color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            bool res = await logic.remove(obj);
                            if (res) {
                              Get.close(2);
                              Get.find<UserCollectLogic>().state.items.removeAt(pageIndex);
                            }
                          },
                          child: Text(
                            '删除'.tr,
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
                          onPressed: () => Get.back(),
                          child: Text(
                            'button_cancel'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              // color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                backgroundColor: Colors.white,
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
        child: n.Column(
          [
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
                  "${'来自'.tr} ${obj.source} ${DateTimeHelper.lastTimeFmt(obj.createdAt)}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Expanded(
                  flex: 1,
                  child: HorizontalLine(
                    height: 1,
                    color: Colors.black26,
                  )),
            ])
              // 内容居中
              ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
            n.Padding(
                top: 10,
                bottom: 10,
                child:
                Get.find<UserCollectLogic>().buildItemBody(obj, 'detail')),
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
          ],
          mainAxisSize: MainAxisSize.min,
        ),
      ),
    );
  }
}
