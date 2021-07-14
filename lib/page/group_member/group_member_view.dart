import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/win_media.dart';
import 'package:imboy/page/select_member/select_member_view.dart';
import 'package:imboy/store/model/group_model.dart';

import 'group_member_logic.dart';
import 'group_member_state.dart';

class GroupMemberPage extends StatefulWidget {
  final String groupId;

  GroupMemberPage(this.groupId);

  @override
  _GroupMemberPageState createState() => _GroupMemberPageState();
}

class _GroupMemberPageState extends State<GroupMemberPage> {
  final logic = Get.find<GroupMemberLogic>();
  final GroupMemberState state = Get.find<GroupMemberLogic>().state;

  Future _futureBuilderFuture;
  List memberList = [
    {'user': '+'},
//    {'user': '-'}
  ];

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = _gerData();
  }

  handle(String uId) {
    if (!strNoEmpty(uId)) {
      Get.to(new SelectMemberPage());
//      routePush(CreateGroupChat(
//        'invite',
//        groupId: widget.groupId,
//        callBack: (data) {
//          if (data.toString().contains('suc')) {
//            setState(() {});
//          }
//          print('邀请好友进群callback >>>> $data');
//        },
//      ));
//    } else {
//      routePush(ConversationDetailPage(
//        title: uId,
//        type: 1,
//      ));
    } else {
      Get.snackbar('', '敬请期待');
    }
  }

  Widget memberItem(item) {
    List userInfo;
    String uId;
    String uFace;
    String nickname;

    if (item['user'] == "+" || item['user'] == '-') {
      return new InkWell(
        child: new SizedBox(
          width: (winWidth(context) - 60) / 5,
          child: Image(
            image: AssetImage('assets/images/group/${item['user']}.png'),
            height: 48.0,
            width: 48.0,
          ),
        ),
        onTap: () => handle(null),
      );
    }

    return new FutureBuilder(
      future: GroupModel.getUsersProfile(item['user'], (cb) {
        userInfo = json.decode(cb.toString());
        uId = userInfo[0]['identifier'];
        uFace = userInfo[0]['faceUrl'];
        nickname = userInfo[0]['nickname'];
      }),
      builder: (context, snap) {
        return new SizedBox(
          width: (winWidth(context) - 60) / 5,
          child: FlatButton(
            onPressed: () => handle(uId),
            padding: EdgeInsets.all(0),
            highlightColor: Colors.transparent,
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  child: !strNoEmpty(uFace)
                      ? new Image(
                          image: AssetImage(defIcon),
                          height: 48.0,
                          width: 48.0,
                          fit: BoxFit.cover,
                        )
                      : CachedNetworkImage(
                          imageUrl: uFace,
                          height: 48.0,
                          width: 48.0,
                          cacheManager: cacheManager,
                          fit: BoxFit.cover,
                        ),
                ),
                SizedBox(height: 2),
                Container(
                  alignment: Alignment.center,
                  height: 20.0,
                  width: 50,
                  child: Text(
                    nickname == null || nickname == ''
                        ? '默认昵称'
                        : nickname.length > 5
                            ? '${nickname.substring(0, 3)}...'
                            : nickname,
                    style: TextStyle(fontSize: 12.0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future _gerData() async {
    return GroupModel.getGroupMembersListModel(widget.groupId,
        callback: (result) {
      setState(() {
        memberList.insertAll(
            0, json.decode(result.toString().replaceAll("'", '"')));
      });
    });
  }

  Widget titleWidget() {
    return FutureBuilder(
      future: _futureBuilderFuture,
      builder: (context, snap) {
        return new Text(
          '聊天成员(${memberList?.length != null ? memberList.length - 1 : 0})',
          style: new TextStyle(
              color: Colors.black, fontSize: 17.0, fontWeight: FontWeight.w600),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!listNoEmpty(memberList)) {
      return Container();
    }

    return new Scaffold(
      appBar: new ComMomBar(titleW: titleWidget()),
      body: new ListView(
        padding: EdgeInsets.all(10),
        children: <Widget>[
          new Wrap(
            alignment: WrapAlignment.start,
            children: memberList.map(memberItem).toList(),
            runSpacing: 20.0,
            spacing: 10,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<GroupMemberLogic>();
    super.dispose();
  }
}
