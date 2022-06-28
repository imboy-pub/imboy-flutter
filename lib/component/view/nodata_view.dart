import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NoDataView extends StatelessWidget {
  final String str;

  NoDataView({this.str = '暂无数据'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
