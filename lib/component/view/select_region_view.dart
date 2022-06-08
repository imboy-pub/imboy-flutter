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
    this.valueChanged.value = ischange;
    update([this.valueChanged]);
  }

  /// 选中title
  void regionSelectedTitle(String title) {
    this.regionSelected.value.clear();
    // this.regionSelected.value.forEach((key, value) {
    //   this.regionSelected.value[key] = {
    //     "selected": false,
    //     "trailing": SizedBox.shrink(),
    //   };
    // });

    this.regionSelected.value[title.trim()] = {
      "selected": true,
      "trailing": Text(
        "√",
        style: TextStyle(fontSize: 20),
      ),
    };
    this.regionSelected.refresh();
  }

  /// context 上下文
  /// parent 地区父节点数据
  /// model 当前地区节点数据，如果是叶子节点，类型为String；如果非叶子节点类型为Map
  /// callback 有里面有业务逻辑处理
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
        child: ListTile(
          title: Text(
            title,
          ),
          selected: regionSelected.value[title] != null &&
              regionSelected.value[title]["selected"] == true,
          selectedColor: AppColors.primaryElement,
          trailing: isRight
              ? Icon(
                  CupertinoIcons.right_chevron,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                )
              : (regionSelected.value[title] != null &&
                      regionSelected.value[title]["selected"] == true
                  ? this.regionSelected.value[title]["trailing"]
                  : null),
          onTap: () {
            this.selectedVal.value =
                strEmpty(parent) ? title : parent + " " + title;
            if (isRight) {
              Get.to(
                SelectRegionPage(
                  parent: this.selectedVal.value,
                  children: children,
                  callback: callback,
                  outCallback: outCallback,
                ),
                preventDuplicates: false,
              );
            } else {
              // getListItem/4 第4个参数，有里面有业务逻辑处理
              callback(parent, title);
              this.regionSelectedTitle(title);
              this.valueOnChange(true);
            }
            debugPrint(
                "on >>> SelectRegionLogic/onTap ${isRight} ${parent} :${title}, selected= ${this.regionSelected[title] != null && this.regionSelected[title]["selected"] == true}, ${this.regionSelected.toString()}");
          },
        ),
        // 下边框
        decoration: BoxDecoration(
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

  @override
  void onInit() {
    super.onInit();
    // print("渲染完成");
  }

  @override
  void onClose() {
    super.onClose();
    // print("close");
  }
}

class SelectRegionPage extends StatelessWidget {
  String parent;
  List children;

  final Future<bool> Function(String, String) callback;
  final Future<bool> Function(String) outCallback;

  SelectRegionPage({
    required this.parent,
    required this.children,
    required this.callback,
    required this.outCallback,
  });

  final logic = Get.put(SelectRegionLogic(), tag: "SelectRegionPage");

  // SelectRegionLogic logic = Get.find();

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(milliseconds: 100)).then((e) {
      logic.valueOnChange(false);
    });
    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(
          // title: '设置地区',
          titleWiew: Row(
        children: [
          Expanded(
            child: Text(
              '设置地区'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
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
                  debugPrint(">>> on Get.close/${t}");
                  Get.close(t);
                }
              },
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
                      minimumSize: MaterialStateProperty.all(Size(60, 40)),
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
                      minimumSize: MaterialStateProperty.all(Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    ),
            ),
          ),
        ],
      )),
      body: Container(
        height: Get.height,
        child: Expanded(
          child: n.Column(
            [
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 15.0),
                width: Get.width,
                height: 40.0,
                child: Text("全部".tr),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: Get.height - 115,
                      child: ListView.builder(
                        // 去掉Container的高度 + 下面两句，自适应高度
                        // physics: NeverScrollableScrollPhysics(),
                        // shrinkWrap: true,
                        itemBuilder: (BuildContext context, int index) {
                          return logic.getListItem(
                            context,
                            this.parent,
                            this.children[index],
                            (a, b) async {
                              return true;
                            },
                            this.outCallback,
                          );
                        },
                        itemCount: this.children.length,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            mainAxisSize: MainAxisSize.min,
          )..useParent((v) => v..bg = Colors.white),
        ),
      ),
    );
  }
}
