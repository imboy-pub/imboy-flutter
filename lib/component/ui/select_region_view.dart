import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

class SelectRegionLogic extends GetxController {
  // 用户名控制器

  RxBool valueChanged = false.obs;

  List regionList = [];

  RxString selectedVal = "".obs;

  RxMap regionSelected = {}.obs;

  void valueOnChange(bool ischange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = ischange;
    update([valueChanged]);
  }

  /// 选中title
  void regionSelectedTitle(String title) {
    regionSelected.clear();
    // this.regionSelected.forEach((key, value) {
    //   this.regionSelected.value[key] = {
    //     "selected": false,
    //     "trailing": SizedBox.shrink(),
    //   };
    // });

    regionSelected[title.trim()] = {
      "selected": true,
      "trailing": const Text(
        "√",
        style: TextStyle(fontSize: 20),
      ),
    };
    regionSelected.refresh();
  }

  /// context 上下文
  /// parent 地区父节点数据
  /// model 当前地区节点数据，如果是叶子节点，类型为String；如果非叶子节点类型为Map
  /// callback 有里面有业务逻辑处理
  /// outCallback 递归调用的时候传递最外层的callback
  Widget getListItem(
    BuildContext context,
    String parent,
    dynamic model,
    Future<bool> Function(String, String) callback,
    Future<bool> Function(String) outCallback,
  ) {
    String title = "";
    List children = [];
    if (model is String) {
      title = model;
    } else if (model is Map) {
      title = model["title"] ?? "";
      children = model["children"] ?? [];
    }
    bool isRight = children.isNotEmpty;
    title = title.trim();

    return Obx(
      () => Container(
        height: 52,
        // ignore: sort_child_properties_last
        child: ListTile(
          title: Text(
            title,
          ),
          selected: regionSelected[title] != null &&
              regionSelected[title]["selected"] == true,
          selectedColor: AppColors.primaryElement,
          trailing: isRight
              ? Icon(
                  CupertinoIcons.right_chevron,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                )
              : (regionSelected[title] != null &&
                      regionSelected[title]["selected"] == true
                  ? regionSelected[title]["trailing"]
                  : null),
          onTap: () {
            selectedVal.value = strEmpty(parent) ? title : "$parent $title";
            if (isRight) {
              Get.to(
                () => SelectRegionPage(
                  parent: selectedVal.value,
                  children: children,
                  callback: callback,
                  outCallback: outCallback,
                ),
                preventDuplicates: false,
              );
            } else {
              // getListItem/4 第4个参数，有里面有业务逻辑处理
              callback(parent, title);
              regionSelectedTitle(title);
              valueOnChange(true);
            }
          },
        ),
        // 下边框
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 1,
              color: Color(0xffe5e5e5),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class SelectRegionPage extends StatelessWidget {
  String parent;
  List children;

  final Future<bool> Function(String, String) callback;
  final Future<bool> Function(String) outCallback;

  SelectRegionPage({
    Key? key,
    required this.parent,
    required this.children,
    required this.callback,
    required this.outCallback,
  }) : super(key: key);

  final logic = Get.put(SelectRegionLogic(), tag: "SelectRegionPage");

  // SelectRegionLogic logic = Get.find();

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      logic.valueOnChange(false);
    });
    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(
        titleWidget: n.Row([
          Expanded(
            child: Text(
              '设置地区'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                // color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 中间用Expanded控件
          ),
          Obx(
            () => ElevatedButton(
              onPressed: () async {
                bool res = await outCallback(logic.selectedVal.value);
                if (res) {
                  int t = logic.selectedVal.value.split(" ").length;
                  Get.close(t);
                }
              },
              // ignore: sort_child_properties_last
              child: Text(
                'button_accomplish'.tr,
                textAlign: TextAlign.center,
              ),
              style: logic.valueChanged.isTrue
                  ? ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        AppColors.primaryElement,
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        Colors.white,
                      ),
                      minimumSize:
                          MaterialStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    )
                  : ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        AppColors.AppBarColor,
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        AppColors.LineColor,
                      ),
                      minimumSize:
                          MaterialStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    ),
            ),
          ),
        ]),
      ),
      body: n.Column(
        [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 15.0),
            width: Get.width,
            height: 40.0,
            child: Text("全部".tr),
          ),
          Expanded(
            child: ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                return logic.getListItem(
                  context,
                  parent,
                  children[index],
                  (a, b) async {
                    return true;
                  },
                  outCallback,
                );
              },
              itemCount: children.length,
            ),
          ),
        ],
        mainAxisSize: MainAxisSize.min,
      )..useParent((v) => v..bg = Colors.white),
    );
  }
}
