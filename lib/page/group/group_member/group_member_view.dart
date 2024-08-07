import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'group_member_logic.dart';
import 'group_member_state.dart';

class GroupMemberPage extends StatefulWidget {
  final String groupId;

  const GroupMemberPage({super.key, required this.groupId});

  @override
  // ignore: library_private_types_in_public_api
  _GroupMemberPageState createState() => _GroupMemberPageState();
}

class _GroupMemberPageState extends State<GroupMemberPage> {
  final logic = Get.find<GroupMemberLogic>();
  final GroupMemberState state = Get.find<GroupMemberLogic>().state;

  // late Future _futureBuilderFuture;
  List memberList = [
    {'user': '+'},
//    {'user': '-'}
  ];

  @override
  void initState() {
    super.initState();
    // _futureBuilderFuture = _gerData();
  }

  /*
  Widget memberItem(item) {
    List? userInfo;
    String? uId;
    String? uFace;
    String? nickname;

    if (item['user'] == "+" || item['user'] == '-') {
      return InkWell(
        child: SizedBox(
          width: (Get.width - 60) / 5,
          child: Image(
            image: AssetImage('assets/images/group/${item['user']}.png'),
            height: 48.0,
            width: 48.0,
          ),
        ),
        onTap: () => handle(""),
      );
    }

    return FutureBuilder(
      future: GroupModel.getUsersProfile(item['user'], (cb) {
        userInfo = json.decode(cb.toString());
        uId = userInfo![0]['identifier'];
        uFace = userInfo![0]['faceUrl'];
        nickname = userInfo![0]['nickname'];
      }),
      builder: (context, snap) {
        return SizedBox(
          width: (Get.width - 60) / 5,
          child: TextButton(
            onPressed: () => handle(uId!),
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  child: Avatar(imgUri: uFace ?? '', width: 48),
                ),
                const SizedBox(height: 2),
                Container(
                  alignment: Alignment.center,
                  height: 20.0,
                  width: 50,
                  child: Text(
                    strEmpty(nickname)
                        ? '默认昵称'
                        : nickname!.length > 5
                            ? '${nickname!.substring(0, 3)}...'
                            : nickname!,
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  */
  // Future _getData() async {
  // return GroupModel.getGroupMembersListModel(widget.groupId,
  //     callback: (result) {
  //   setState(() {
  //     memberList.insertAll(
  //         0, json.decode(result.toString().replaceAll("'", '"')));
  //   });
  // });
  // }

  /*
  Widget titleWidget() {
    return FutureBuilder(
      future: _futureBuilderFuture,
      builder: (context, snap) {
        return Text(
          '聊天成员(${memberList.length > 1 ? memberList.length - 1 : 0})',
          style: AppStyle.navAppBarTitleStyle,
        );
      },
    );
  }
  */

  @override
  Widget build(BuildContext context) {
    // if (!listNoEmpty(memberList)) {
    //   return Container();
    // }

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        // titleWidget: titleWidget(),
      ),
      body: ListView(
        padding:  EdgeInsets.all(10),
        children: [
          // Wrap(
          //   alignment: WrapAlignment.start,
          //   // ignore: sort_child_properties_last
          //   children: memberList.map(memberItem).toList(),
          //   runSpacing: 20.0,
          //   spacing: 10,
          // ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<GroupMemberLogic>();
    super.dispose();
    // super.dispose();
  }
}
