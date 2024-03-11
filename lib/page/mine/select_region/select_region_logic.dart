import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';

import 'select_region_view.dart';

class SelectRegionLogic extends GetxController {
  // 用户名控制器

  RxBool valueChanged = false.obs;

  List regionList = [];

  RxString selectedVal = ''.obs;

  RxMap regionSelected = {}.obs;

  void valueOnChange(bool isChange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = isChange;
  }

  /// 选中title
  void regionSelectedTitle(String title) {
    regionSelected.clear();
    regionSelected[title.trim()] = {
      'selected': true,
      'trailing': const Text(
        '√',
        style: TextStyle(
          fontSize: 20,
          color: Colors.green,
        ),
      ),
    };
  }

  /// context 上下文
  /// parent 地区父节点数据
  /// model 当前地区节点数据，如果是叶子节点，类型为String；如果非叶子节点类型为Map
  /// callback 有里面有业务逻辑处理
  /// outCallback 递归调用的时候传递最外层的callback
  Widget getListItem({
    required BuildContext context,
    required String parent,
    required dynamic model,
    required Future<bool> Function(String, String) callback,
    required Future<bool> Function(String) outCallback,
    required EdgeInsetsGeometry margin,
  }) {
    String title = "";
    List children = [];
    iPrint(
        "region_item getListItem ${model.runtimeType}, $parent : ${model.toString()}");
    if (model is String) {
      title = model;
    } else if (model is Map) {
      title = model["title"] ?? "";
      children = model["children"] ?? [];
    }
    bool haveChildren = children.isNotEmpty;
    title = title.trim();

    return Obx(
      () => Container(
        height: 52,
        // ignore: sort_child_properties_last
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
              fontSize: regionSelected[title] != null &&
                      regionSelected[title]["selected"] == true
                  ? 20
                  : 16,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          selected: regionSelected[title] != null &&
              regionSelected[title]["selected"] == true,
          // selectedColor: AppColors.primaryElement,
          trailing: haveChildren
              ? navigateNextIcon
              : (regionSelected[title] != null &&
                      regionSelected[title]["selected"] == true
                  ? regionSelected[title]["trailing"]
                  : null),
          onTap: () {
            iPrint("region_item_onTap 1s $selectedVal, p $parent");
            List<String> items = parent.split(' ');
            // String lastTitle = items.last;
            items.add(title);
            items = items.toSet().toList();
            selectedVal.value = items.join(' ');
            iPrint(
                "region_item_onTap 2s $selectedVal, p $parent, $haveChildren: ${children.toString()}");
            if (haveChildren) {
              parent = selectedVal.value;
              Navigator.push(
                context,
                CupertinoPageRoute(
                  // “右滑返回上一页”功能
                  builder: (_) => SelectRegionPage(
                    parent: parent,
                    children: children,
                    callback: callback,
                    outCallback: outCallback,
                  ),
                ),
              );
            } else {
              if (parent == selectedVal.value) {
                valueOnChange(false);
              } else {
                // getListItem/4 第4个参数，有里面有业务逻辑处理
                callback(parent, title);
                regionSelectedTitle(title);
                valueOnChange(true);
              }
            }
          },
        ),
        // padding: const EdgeInsets.all(0),
        margin: margin,
        // 下边框
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 1,
              color: Get.isDarkMode
                  ? const Color.fromRGBO(68, 68, 68, 1.0)
                  : const Color.fromRGBO(200, 200, 200, 1.0),
            ),
          ),
        ),
      ),
    );
  }
}
