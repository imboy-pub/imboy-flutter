import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/commom_button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/main_input.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/win_media.dart';

import 'group_remark_logic.dart';
import 'group_remark_state.dart';

class GroupRemarkPage extends StatefulWidget {
  final GroupInfoType? groupInfoType;
  final String text;
  final String? groupId;

  GroupRemarkPage({
    this.groupInfoType = GroupInfoType.remark,
    this.text = '',
    this.groupId,
  });

  @override
  _GroupRemarkPageState createState() => _GroupRemarkPageState();
}

class _GroupRemarkPageState extends State<GroupRemarkPage> {
  final logic = Get.find<GroupRemarkLogic>();
  final GroupRemarkState state = Get.find<GroupRemarkLogic>().state;

  TextEditingController _textController = TextEditingController();

  handle() {
    if (!strNoEmpty(_textController.text)) {
      Get.snackbar('Error', "请输入内容");
      return;
    }
    if (widget.groupInfoType == GroupInfoType.name) {
      // DimGroup.modifyGroupNameModel(widget.groupId, _textController.text,
      //     callback: (_) {});
      Navigator.pop(context, _textController.text);
    } else {
      Get.snackbar('Error', "敬请期待");
    }
  }

  @override
  void initState() {
    super.initState();
    _textController.text = widget.text;
  }

  String get label {
    if (widget.groupInfoType == GroupInfoType.name) {
      return '修改群聊名称';
    } else if (widget.groupInfoType == GroupInfoType.cardName) {
      return '我在本群的昵称';
    } else {
      return '备注';
    }
  }

  String get des {
    if (widget.groupInfoType == GroupInfoType.name) {
      return '修改群聊名称后，将在群内通知其他成员';
    } else if (widget.groupInfoType == GroupInfoType.cardName) {
      return '昵称修改后，只会在此群内显示，群内成员都可以看见。';
    } else {
      return '群聊的备注仅自己可见';
    }
  }

  @override
  Widget build(BuildContext context) {
    return new MainInputBody(
      child: new Scaffold(
        appBar: new PageAppBar(backgroundColor: Colors.white),
        body: new Container(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: new Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              new Space(height: 30),
              new Text(
                '$label',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w600),
              ),
              new Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: new Text('$des', textAlign: TextAlign.center),
              ),
              new Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey, width: 0.2),
                    bottom: BorderSide(color: Colors.grey, width: 0.2),
                  ),
                ),
                child: new Row(
                  children: <Widget>[
                    new Image.network(
                      defGroupAvatar,
                      width: 48,
                    ),
                    new Space(),
                    new Expanded(
                      child: new TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText:
                              '${widget.groupInfoType == GroupInfoType.name ? '群聊名称' : '备注'}',
                          border: InputBorder.none,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              new Space(),
              new Visibility(
                visible: widget.groupInfoType == GroupInfoType.remark,
                child: new Row(
                  children: <Widget>[
                    new Text(
                      '群聊名称：wechat_flutter 106号群',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    new Space(),
                    new InkWell(
                      child: new Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: new Text(
                          '填入',
                          style: TextStyle(color: AppColors.MainTextColor, fontSize: 14),
                        ),
                      ),
                      onTap: () {
                        _textController.text = 'wechat_flutter 106号群';
                      },
                    )
                  ],
                ),
              ),
              new Spacer(),
              new ComMomButton(
                text: '完成',
                onTap: () => handle(),
                width: winWidth(context) / 2,
              ),
              new Space(height: winKeyHeight(context) > 1 ? 15 : 50),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<GroupRemarkLogic>();
    super.dispose();
  }
}
