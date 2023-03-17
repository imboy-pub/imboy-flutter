import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/confirm_alert.dart';
import 'package:imboy/component/ui/indicator_page_view.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/group_bill_board/group_bill_board_view.dart';
import 'package:imboy/page/group_member/group_member_view.dart';
import 'package:imboy/page/group_member_detail/group_member_detail_view.dart';
import 'package:imboy/page/group_remark/group_remark_view.dart';
import 'package:imboy/page/select_member/select_member_view.dart';
import 'package:imboy/store/model/group_model.dart';

import 'group_detail_logic.dart';
import 'group_detail_state.dart';

class GroupDetailPage extends StatefulWidget {
  final String? peer;
  final Callback? callBack;

  const GroupDetailPage(this.peer, {Key? key, this.callBack}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _GroupDetailPageState createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final logic = Get.find<GroupDetailLogic>();
  final GroupDetailState state = Get.find<GroupDetailLogic>().state;

  bool _top = false;
  bool _showName = false;
  bool _contact = false;
  bool _dnd = false;
  String? groupName;
  String? groupNotification;
  String? time;
  String cardName = '默认';
  bool isGroupOwner = false;

  List memberList = [
    {'user': '+'},
//    {'user': '-'}
  ];
  List? dataGroup;

  @override
  void initState() {
    super.initState();
    _getGroupMembers();
    _getGroupInfo();
    getCardName();
  }

  getCardName() async {
    // await InfoModel.getSelfGroupNameCardModel(widget.peer, callback: (str) {
    //   cardName = str.toString();
    //   setState(() {});
    // });
  }

  // 获取群组信息
  _getGroupInfo() {
    GroupModel.getGroupInfoListModel([widget.peer!], callback: (result) async {
      dataGroup = json.decode(result.toString().replaceAll("'", '"'));
      // final user = await SharedUtil.instance.getString(Keys.account);
      isGroupOwner = dataGroup![0]['groupOwner'] == '';
      groupName = dataGroup![0]['groupName'].toString();
      String notice = strNoEmpty(dataGroup![0]['groupNotification'].toString())
          ? dataGroup![0]['groupNotification'].toString()
          : '暂无公告';
      groupNotification = notice;
      time = dataGroup![0]['groupIntroduction'].toString();
      setState(() {});
    });
  }

  // 获取群成员列表
  _getGroupMembers() async {
    await GroupModel.getGroupMembersListModelLIST(widget.peer!,
        callback: (result) {
      memberList.insertAll(
          0, json.decode(result.toString().replaceAll("'", '"')));
      setState(() {});
    });
  }

  Widget memberItem(item) {
    List<dynamic>? userInfo;
    String? uId;
    String uFace = '';
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
        onTap: () => Get.to(
          const SelectMemberPage(),
          transition: Transition.rightToLeft,
          popGesture: true, // 右滑，返回上一页
        ),
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
            onPressed: () => Get.to(() => GroupMemberDetailPage(uId!)),
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  child: !strNoEmpty(uFace)
                      ? defAvatarIcon
                      : CachedNetworkImage(
                          imageUrl: uFace,
                          height: 48.0,
                          width: 48.0,
                          cacheManager: cacheManager,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 2),
                Container(
                  alignment: Alignment.center,
                  height: 20.0,
                  width: 50,
                  child: Text(
                    '${strEmpty(nickname) ? uId : nickname!.length > 4 ? '${nickname!.substring(0, 3)}...' : nickname}',
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

  // 设置消息免打扰
  _setDND(int type) {
    // GroupModel.setReceiveMessageOptionModel(widget.peer, Data.user(), type, callback: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (!listNoEmpty(dataGroup!)) {
      return Container(color: Colors.white);
    }

    return Scaffold(
      backgroundColor: const Color(0xffEDEDED),
      appBar: PageAppBar(
        title: '聊天信息 (${dataGroup![0]['memberNum']})',
      ),
      body: ScrollConfiguration(
        behavior: MyBehavior(),
        child: ListView(
          children: <Widget>[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(top: 10.0, bottom: 10),
              width: Get.width,
              child: Wrap(
                runSpacing: 20.0,
                spacing: 10,
                children: memberList.map(memberItem).toList(),
              ),
            ),
            Visibility(
              visible: memberList.length > 20,
              child: TextButton(
                child: Text(
                  '查看全部群成员'.tr,
                  style: const TextStyle(fontSize: 14.0, color: Colors.black54),
                ),
                onPressed: () => Get.to(() => GroupMemberPage(widget.peer!)),
              ),
            ),
            const SizedBox(height: 10.0),
            functionBtn(
              '群聊名称',
              detail: groupName.toString().length > 7
                  ? '${groupName.toString().substring(0, 6)}...'
                  : groupName.toString(),
            ),
            functionBtn(
              '群二维码',
              right: const Image(
                image: AssetImage('assets/images/group/group_code.png'),
                width: 20,
              ),
            ),
            functionBtn(
              '群公告',
              detail: groupNotification.toString(),
            ),
            Visibility(
              visible: isGroupOwner,
              child: functionBtn('群管理'),
            ),
            functionBtn('备注'),
            const Space(height: 10.0),
            functionBtn('查找聊天记录'),
            const Space(height: 10.0),
            functionBtn('消息免打扰',
                right: CupertinoSwitch(
                  value: _dnd,
                  onChanged: (bool value) {
                    _dnd = value;
                    setState(() {});
                    value ? _setDND(1) : _setDND(2);
                  },
                )),
            functionBtn('聊天置顶',
                right: CupertinoSwitch(
                  value: _top,
                  onChanged: (bool value) {
                    _top = value;
                    setState(() {});
                    value ? _setTop(1) : _setTop(2);
                  },
                )),
            functionBtn('保存到通讯录',
                right: CupertinoSwitch(
                  value: _contact,
                  onChanged: (bool value) {
                    _contact = value;
                    setState(() {});
                    value ? _setTop(1) : _setTop(2);
                  },
                )),
            const Space(height: 10.0),
            functionBtn('我在群里的昵称', detail: cardName),
            functionBtn('显示群成员昵称',
                right: CupertinoSwitch(
                  value: _showName,
                  onChanged: (bool value) {
                    _showName = value;
                    setState(() {});
                    value ? _setTop(1) : _setTop(2);
                  },
                )),
            const Space(),
            functionBtn('设置当前聊天背景'.tr),
            functionBtn('投诉'.tr),
            const Space(),
            functionBtn('清空聊天记录'.tr),
            const Space(),
            TextButton(
              // padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
              // color: Colors.white,
              onPressed: () {
                if (widget.peer == '') return;

                confirmAlert(context, (isOK) {
                  if (isOK) {
                    GroupModel.quitGroupModel(widget.peer!, callback: (str) {
                      if (str.toString().contains('失败')) {
                        // print('失败了，开始执行解散');
                        GroupModel.deleteGroupModel(widget.peer!,
                            callback: (data) {
                          if (str.toString().contains('成功')) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                            if (Navigator.canPop(context)) {
                              Navigator.of(context).pop();
                            }
                            Get.snackbar('', '解散群聊成功');
                          }
                        });
                      } else if (str.toString().contains('succ')) {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                        Get.snackbar('', '退出成功');
                      }
                    });
                  }
                }, tips: '确定要退出本群吗？');
              },
              child: const Text(
                '删除并退出',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 18.0),
              ),
            ),
            const SizedBox(height: 30.0),
          ],
        ),
      ),
    );
  }

  handle(String title) {
    switch (title) {
      case '备注':
        Get.to(() => GroupDetailPage(widget.peer));
        break;
      case '群聊名称':
        Get.to(
          () => GroupRemarkPage(
            groupInfoType: GroupInfoType.name,
            text: groupName!,
            groupId: widget.peer,
          ),
        )!
            .then((data) {
          groupName = data ?? groupName;
          // Notice.send(ChatActions.groupName(), groupName);
        });
        break;
      case '群二维码':
        // Get.to(() => QrCodePage());
        break;
      case '群公告':
        Get.to(
          () => GroupBillBoardPage(
            dataGroup![0]['groupOwner'],
            groupNotification!,
            groupId: widget.peer!,
            time: time!,
            callback: (timeData) => time = timeData,
          ),
        )!
            .then((data) {
          groupNotification = data ?? groupNotification;
        });
        break;
      // case '查找聊天记录':
      //   Get.to((() => SearchPage());
      //   break;
      case '消息免打扰':
        _dnd = !_dnd;
        _dnd ? _setDND(1) : _setDND(2);
        break;
      case '聊天置顶':
        _top = !_top;
        setState(() {});
        _top ? _setTop(1) : _setTop(2);
        break;
      case '设置当前聊天背景':
        break;
      case '我在群里的昵称':
        Get.to(
          () => GroupRemarkPage(
            groupInfoType: GroupInfoType.cardName,
            text: cardName,
            groupId: widget.peer,
          ),
        )!
            .then((data) {
          cardName = data ?? cardName;
        });
        break;
      case '投诉':
        Get.to(
          WebViewPage(CONST_HELP_URL, '投诉'),
          transition: Transition.rightToLeft,
          popGesture: true, // 右滑，返回上一页
        );
        break;
      case '清空聊天记录':
        confirmAlert(
          context,
          (isOK) {
            if (isOK) {
              Get.snackbar('Tips', "敬请期待");
            }
          },
          tips: '确定删除群的聊天记录吗？',
          okBtn: '清空',
        );
        break;
    }
  }

  _setTop(int i) {}

  functionBtn(
    title, {
    final String? detail,
    final Widget? right,
  }) {
    return GroupItem(
      detail: detail,
      title: title,
      right: right,
      onPressed: () => handle(title),
    );
  }

  @override
  void dispose() {
    Get.delete<GroupDetailLogic>();
    super.dispose();
  }
}

class GroupItem extends StatelessWidget {
  final String? detail;
  final String? title;
  final VoidCallback? onPressed;
  final Widget? right;

  const GroupItem({
    Key? key,
    this.detail,
    this.title,
    this.onPressed,
    this.right,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (detail == null && detail == '') {
      return Container();
    }
    double? widthT() {
      if (detail != null) {
        return detail!.length > 35 ? Get.height / 100 * 60 : 0.0;
      } else {
        return 0.0;
      }
    }

    bool isSwitch = title == '消息免打扰' ||
        title == '聊天置顶' ||
        title == '保存到通讯录' ||
        title == '显示群成员昵称';
    bool noBorder = title == '备注' ||
        title == '查找聊天记录' ||
        title == '保存到通讯录' ||
        title == '显示群成员昵称' ||
        title == '投诉' ||
        title == '清空聊天记录';

    return TextButton(
      onPressed: () => onPressed!(),
      child: Container(
        padding: EdgeInsets.only(
          top: isSwitch ? 10 : 15.0,
          bottom: isSwitch ? 10 : 15.0,
        ),
        decoration: BoxDecoration(
          border: noBorder
              ? null
              : const Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(title!),
                ),
                Visibility(
                  visible: title != '群公告',
                  child: SizedBox(
                    width: widthT(),
                    child: Text(
                      detail ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                right != null ? right! : Container(),
                const Space(width: 10.0),
                isSwitch
                    ? Container()
                    : const Image(
                        image: AssetImage('assets/images/group/ic_right.png'),
                        width: 15,
                      ),
              ],
            ),
            Visibility(
              visible: title == '群公告',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  detail ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
