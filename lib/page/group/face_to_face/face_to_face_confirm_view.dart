import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_logic.dart';
import 'package:imboy/store/model/chat_extend_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/config/theme.dart';

class FaceToFaceConfirmPage extends StatefulWidget {
  final String gid;
  final String code;
  final List<PeopleModel> memberList;

  const FaceToFaceConfirmPage({
    super.key,
    required this.gid,
    required this.code,
    required this.memberList,
  });

  @override
  FaceToFaceConfirmPageState createState() => FaceToFaceConfirmPageState();
}

class FaceToFaceConfirmPageState extends State<FaceToFaceConfirmPage> {
  // 面对面建群确认页面用到
  // [{"nickname": "", "avatar":"", "user_id":""}]
  List<PeopleModel> memberList = [];

  StreamSubscription? ssMsg;

  @override
  void initState() {
    //监听Widget是否绘制完毕
    super.initState();

    initData();
    // 异步检查是否有离线数据 TODO leeyi 2023-01-29 16:43:47
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    memberList = [];
    ssMsg?.cancel();
    super.dispose();
  }

  /// 初始化一些数据
  Future<void> initData() async {
    memberList = widget.memberList;
    memberList.add(PeopleModel(id: 'last', account: ''));

    // 接收到新的消息订阅
    ssMsg ??=
        eventBus.on<ChatExtendModel>().listen((ChatExtendModel obj) async {
      // 监听新成员加入
      if (obj.type == 'join_group') {
        final i = memberList.indexWhere((e) =>
            e.id == obj.payload['userId'] &&
            widget.gid == obj.payload['groupId']);
        iPrint(
            "face_to_face_confirm widget.gid ${obj.payload['groupId']} = ${widget.gid} - uid ${obj.payload['userId']}; i $i;} $mounted");
        if (i == -1) {
          memberList.insert(0, obj.payload['people']);
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBgColor,
      appBar: NavAppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 24, color: Colors.white),
          onPressed: () {
            NavigatorState nav = Navigator.of(context);
            nav.pop();
          },
        ),
        backgroundColor: darkBgColor,
      ),
      // backgroundColor: Get.isDarkMode ? darkBgColor : lightBgColor,
      body: Container(
        padding: const EdgeInsets.all(10.0),
        child: n.Column([
          n.Row([_buildNumberWidget(widget.code.length)])
            // 内容居中
            ..mainAxisAlignment = MainAxisAlignment.center,
          SizedBox(height: 16, width: Get.width),
          n.Row([
            Expanded(
                child: Text(
              // '这些朋友也将进入群聊'.tr,
              'create_group_f2f_confirm_tips'.tr,
              textAlign: TextAlign.center, // 文本在Text组件内部居中
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            )),
          ])
            // 内容居中
            ..mainAxisAlignment = MainAxisAlignment.center,
          const HorizontalLine(height: 1),
          SizedBox(height: 10, width: Get.width),
          SizedBox(
            height: Get.height - 240,
            child: SingleChildScrollView(
              child: AvatarList(
                memberList: memberList,
                titleStyle: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const Spacer(),
          RoundedElevatedButton(
            text: 'enter_the_group'.tr,
            highlighted: true,
            size: Size(Get.width, 48),
            borderRadius: BorderRadius.circular(4.0),
            onPressed: () async {
              EasyLoading.show(status: '');
              Map<String, dynamic> res = await Get.find<FaceToFaceLogic>()
                  .faceToFaceSave(widget.gid, widget.code);
              List<PeopleModel> memberList = res['memberList'] ?? [];
              Map<String, dynamic> group = res['group'];
              // await Future.delayed(const Duration(seconds: 1));
              EasyLoading.dismiss();

              GroupRepo().save('', group);
              Get.to(
                () => ChatPage(
                  peerId: widget.gid,
                  type: 'C2G',
                  peerTitle: '',
                  peerAvatar: '',
                  peerSign: '',
                  options: {
                    'popTime': 2,
                    'showConversation': true,
                    'memberCount': memberList.length
                  },
                ),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页
                // binding: ChatBinding(),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildNumberWidget(int length) {
    return SizedBox(
      height: 47,
      width: 188,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemExtent: 47,
        itemBuilder: (BuildContext context, int index) {
          Widget showVal = Text(
            widget.code[index],
            style: const TextStyle(color: Colors.green, fontSize: 40),
          );
          return _buildNumberItemWidget(
            length,
            index,
            true,
            showVal,
          );
        },
      ),
    );
  }

  Widget _buildNumberItemWidget(
    int length,
    int index,
    bool showPoint,
    Widget showVal,
  ) {
    iPrint("_buildNumberItemWidget length $length");
    return Container(
      height: 47,
      width: 47,
      alignment: Alignment.center,
      child: showPoint
          ? showVal
          : Container(
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
    );
  }
}
