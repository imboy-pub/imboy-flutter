import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';

void confirmAlert<T>(
  BuildContext context,
  VoidCallbackConfirm callBack, {
  int? type,
  String? tips,
  String? okBtn,
  String? cancelBtn,
  TextStyle? okBtnStyle,
  TextStyle? style,
  bool isWarm = false,
  String? warmStr,
}) {
  showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      if (!strNoEmpty(okBtn!)) okBtn = '确定';
      if (!strNoEmpty(cancelBtn!)) cancelBtn = '取消';
      if (!strNoEmpty(warmStr!)) warmStr = '温馨提示：';
      return CupertinoAlertDialog(
        title: isWarm
            ? Padding(
                padding: const EdgeInsets.only(bottom: 20.0, top: 0),
                child: Text(
                  '$warmStr',
                  style: const TextStyle(
                      color: Color(0xff343243),
                      fontSize: 19.0,
                      fontWeight: FontWeight.normal),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  '$tips',
                  style: const TextStyle(
                      color: Color(0xff343243),
                      fontSize: 19.0,
                      fontWeight: FontWeight.normal),
                ),
              ),
        content: isWarm
            ? Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  '$tips',
                  style: const TextStyle(color: Color(0xff888697)),
                ),
              )
            : Container(),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text(
              '$cancelBtn',
              style:
                  const TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
            ),
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              callBack(false);
            },
          ),
          CupertinoDialogAction(
            child: Text('$okBtn', style: okBtnStyle),
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              callBack(true);
            },
          ),
        ],
      );
    },
  ).then<void>((T? value) {});
}
