import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NoDataView extends StatelessWidget {
  final String str;

  NoDataView({this.str = '暂无数据'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用Obx(()=>每当改变计数时，就更新Text()。
      //   appBar: AppBar(title: Obx(() => Text(str ?? ''))),

      // 用一个简单的Get.to()即可代替Navigator.push那8行，无需上下文！
      body: Center(
        child: ElevatedButton(
          onPressed: () {},
          child: Text(
            str,
          ),
        ),
      ),
    );
  }
}
