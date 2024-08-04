import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';
import 'package:imboy/store/model/chat_extend_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/group/group_member/group_member_view.dart';
import 'package:synchronized/synchronized.dart';

import 'change_info_view.dart';
import 'group_detail_logic.dart';
import 'remove_member_view.dart';
import 'add_member_view.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  final String title;
  final int memberCount;
  final Callback? callBack;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.title,
    required this.memberCount,
    this.callBack,
  });

  @override
  // ignore: library_private_types_in_public_api
  _GroupDetailPageState createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final logic = Get.put(GroupDetailLogic());

  bool backDoRefresh = false;
  final Lock _lock = Lock();
  List<PeopleModel> memberList = [];
  String title = ''; // 群聊名称
  int memberCount = 0;

  bool isAdmin = false;
  int role = 0;

  String? groupNotification;
  String? groupRemark;
  String? myGroupAlias;

  bool _top = false;

  // bool _showName = false;

  // bool _contact = false;
  // bool _dnd = false;

  String? time;
  String cardName = '默认';

  // List memberList = [
  //   {'user': '+'},
  //   {'user': '-'}
  // ];
  List? dataGroup;

  @override
  void initState() {
    super.initState();
    initData();
    // getCardName();
  }

  initData() async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    bool connected =
        connectivityResult.contains(ConnectivityResult.none) == false;
    // connected = true;
    memberCount = widget.memberCount;
    title = widget.title;

    // 获取群成员信息
    memberList = await logic.listGroupMember(
      gid: widget.groupId,
      sync: false,
      limit: 18,
    );

    memberList.add(PeopleModel(id: 'add', account: ''));
    role = await logic.role(
      gid: widget.groupId,
      userId: UserRepoLocal.to.currentUid,
    );
    isAdmin = role == 3 || role == 4;
    if (isAdmin) {
      memberList.add(PeopleModel(id: 'remove', account: ''));
    }
    // 在有网络的情况下，异步更新群信息详情
    logic
        .detail(gid: widget.groupId, sync: connected)
        .then((GroupModel? g) async {
      iPrint(
          "logic.detail then connected $connected, ${g?.toJson().toString()}");
      if (g != null) {
        memberCount = g.memberCount;
        title = g.title;

        if (connected && widget.memberCount != memberCount) {
          memberList = await logic.listGroupMember(
            gid: widget.groupId,
            sync: true,
            limit: 1000,
          );
          if (memberList.length > 18) memberList = memberList.sublist(0, 18);
        }
        setState(() {});
      }
    });

    // 获取群组信息
    // GroupModel? g = await logic.detail(gid: widget.groupId, sync: false);
    // memberCount = g!.memberCount;
    // title = g!.title;

    setState(() {});
    eventBus.on<ChatExtendModel>().listen((ChatExtendModel obj) async {
      iPrint(
          "face_to_face_confirm widget.gid ${obj.toString()}");
      // if (obj.groupId == widget.groupId && obj.isFirst) {
      // 监听新成员加入
      if (obj.type == 'join_group' &&
          obj.payload['groupId'] == widget.groupId &&
          (obj.payload['isFirst'] ?? false)) {
        // 使用锁来保护消息处理逻辑
        await _lock.synchronized(() async {
          // GroupModel? g = await (GroupRepo()).findById(widget.groupId);
          // final i = memberList.indexWhere((e) => e.id == obj.people.id);
          // if (i == -1) {
          memberCount += 1;
          memberList.insert(0, obj.payload['people']);
          backDoRefresh = true;
          if (mounted) {
            setState(() {});
          }
          // }
        });
      } else if (obj.type == 'leave_group' && obj.payload['groupId'] == widget.groupId) {
        // 监听成员退出

        // 使用锁来保护消息处理逻辑
        await _lock.synchronized(() async {
          // GroupModel? g = await (GroupRepo()).findById(widget.groupId);
          final i = memberList.indexWhere((PeopleModel p) => p.id == obj.payload['userId']);
          if (i > -1) {
            memberCount -= 1;
            memberList.removeAt(i);
            if (mounted) {
              setState(() {});
            }
          }
          backDoRefresh = true;
        });
      }
    });
  }

  getCardName() async {
    // await InfoModel.getSelfGroupNameCardModel(widget.peer, callback: (str) {
    //   cardName = str.toString();
    //   setState(() {});
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // backgroundColor: const Color(0xffEDEDED),
        appBar: NavAppBar(
          automaticallyImplyLeading: true,
          leading: BackButton(
            onPressed: () {
              Get.back(result: {'memberCount': memberCount});
            },
          ),
          title: "${title.isEmpty ? 'chat_message'.tr : title} ($memberCount)",
        ),
        body: SingleChildScrollView(
          child: n.Column([
            Container(
              padding: const EdgeInsets.only(left: 16, top: 10.0, bottom: 10),
              width: Get.width,
              child: AvatarList(
                memberList: memberList,
                titleMaxLines: 1,
                titleStyle: const TextStyle(fontSize: 12),
                width: 61,
                height: 61,
                column: (Get.width - 20) ~/ 61,
                onTapAvatar: (PeopleModel p) {
                  Get.to(
                    () => PeopleInfoPage(
                      id: p.id,
                      scene: 'group_member',
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
                onTapAdd: () {
                  Get.to(() => AddMemberPage(groupId: widget.groupId));
                },
                onTapRemove: () {
                  Get.to(() => RemoveMemberPage(groupId: widget.groupId))
                      ?.then((value) {
                    if (value != null && value is List<GroupMemberModel>) {
                      iPrint(
                          "RemoveMemberPage then ${value.toList().toString()}");
                      for (var gm in value) {
                        final i =
                            memberList.indexWhere((e) => e.id == gm.userId);
                        if (i > -1) {
                          memberList.removeAt(i);
                        }
                      }
                      backDoRefresh = true;
                      memberCount -= value.length;
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  });
                },
              ),
            ),
            Visibility(
              visible: memberCount > 20,
              child: TextButton(
                child: Text(
                  // 查看全部群成员
                  'view_all_group_member'.tr,
                  style: TextStyle(
                      fontSize: 14.0,
                      color: Theme.of(Get.context!).colorScheme.onPrimary),
                ),
                onPressed: () =>
                    Get.to(() => GroupMemberPage(groupId: widget.groupId)),
              ),
            ),
            HorizontalLine(
              height: 10.0,
              color: Theme.of(context).colorScheme.primary,
              // color: Colors.red,
            ),
            n.ListTile(
              title: n.Row([
                Text('group_name'.tr),
                Flexible(
                  child: Text(
                    title.isEmpty ? 'unnamed'.tr : title,
                  ),
                ),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () async {
                GroupModel group = (await logic.find(widget.groupId))!;
                Get.to(
                  () => ChangeInfoPage(
                    group: group,
                    title: 'change_param'.trArgs(['group_name'.tr]), // 修改群聊名称,
                    subtitle: 'change_group_chat_name'.tr,
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                )?.then((value) {
                  iPrint("ChangeInfoPage back ${value.toString()}");
                  if (value != null && value is GroupModel) {
                    // memberCount = value.memberCount;
                    title = value.title;
                    setState(() {});
                  }
                });
              },
            ),
            n.Padding(
                left: 20,
                child: HorizontalLine(
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                  // color: Colors.red,
                )),
            n.ListTile(
              title: n.Row([Text('group_qrcode'.tr), const Icon(Icons.qr_code)])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () async {
                GroupModel group = (await logic.find(widget.groupId))!;
                Get.to(
                  () => GroupQrCodePage(group: group),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            n.Padding(
                left: 20,
                child: HorizontalLine(
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: n.Row([
                Text('群公告'.tr),
                Text(strEmpty(groupNotification) ? 'not_set'.tr : '')
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              subtitle: strEmpty(groupNotification)
                  ? null
                  : n.Row([Text(groupNotification!)]),
              trailing: navigateNextIcon,
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            n.Padding(
                left: 20,
                child: HorizontalLine(
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            Visibility(
              visible: isAdmin,
              child: n.ListTile(
                title: n.Row([
                  Text('group_management'.tr),
                ])
                  // 两端对齐
                  ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
                trailing: navigateNextIcon,
                onTap: () {
                  // Get.to(
                  //       () => DenylistPage(),
                  //   transition: Transition.rightToLeft,
                  //   popGesture: true, // 右滑，返回上一页
                  // );
                },
              ),
            ),

            n.ListTile(
              title: n.Row(
                  [Text('remark'.tr), Text(strEmpty(groupRemark) ? ''.tr : '')])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            n.ListTile(
              title: n.Row([
                Text('search_chat_content'.tr),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            n.ListTile(
              title: n.Row([
                Text('message_mute'.tr),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: CupertinoSwitch(
                value: _top,
                onChanged: (bool value) {
                  _top = value;
                  setState(() {});
                  // value ? _setTop(1) : _setTop(2);
                },
              ),
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            n.Padding(
                left: 20,
                child: HorizontalLine(
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: n.Row([
                Text('pin_chat'.tr),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: CupertinoSwitch(
                value: _top,
                onChanged: (bool value) {
                  _top = value;
                  setState(() {});
                  // value ? _setTop(1) : _setTop(2);
                },
              ),
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            n.Padding(
                left: 20,
                child: HorizontalLine(
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            n.ListTile(
              title: n.Row([
                Text('group_add_local'.tr),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: CupertinoSwitch(
                value: _top,
                onChanged: (bool value) {
                  _top = value;
                  setState(() {});
                  // value ? _setTop(1) : _setTop(2);
                },
              ),
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            n.ListTile(
              title: n.Row([
                Text('group_alias'.tr),
                const Space(),
                Expanded(
                    child: Text(strEmpty(myGroupAlias)
                        ? UserRepoLocal.to.current.nickname.tr
                        : ''))
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              subtitle: strEmpty(groupNotification)
                  ? null
                  : n.Row([Text(groupNotification!)]),
              trailing: navigateNextIcon,
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),

            // GroupItem(title: 'set_chat_background'.tr),

            // HorizontalLine(
            //   height: 10,
            //   color: Theme.of(context).colorScheme.primary,
            // ),

            n.ListTile(
              title: n.Row([
                Text('clear_chat_record'.tr),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            n.ListTile(
              title: n.Row([
                Text('complaint'.tr),
              ])
                // 两端对齐
                ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
              trailing: navigateNextIcon,
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            TextButton(
              // padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
              // color: Colors.white,
              onPressed: () {
                String tips =
                    "${role == 4 ? 'sure_to_dissolve_group'.tr : 'sure_to_leave_group'.tr}\n${'sure_delete_group_chat_record'.tr}";

                Get.defaultDialog(
                  title: 'tip_tips'.tr,
                  backgroundColor: Get.isDarkMode
                      ? const Color.fromRGBO(80, 80, 80, 1)
                      : const Color.fromRGBO(240, 240, 240, 1),
                  content: Text(tips),
                  textCancel: "  ${'button_cancel'.tr}  ",
                  textConfirm: "  ${'button_confirm'.tr}  ",
                  // confirmTextColor: AppColors.primaryElementText,
                  onConfirm: () async {
                    var nav = Navigator.of(context);
                    bool res = false;
                    if (role == 4) {
                      res = await logic.dissolve(widget.groupId);
                    } else {
                      res = await logic.leave(widget.groupId);
                    }
                    if (res) {
                      EasyLoading.showSuccess('tip_success'.tr);
                      Get.close();
                      nav.pop();
                      nav.pop();
                    }
                  },
                );
              },
              child: Text(
                role == 4 ? 'group_dissolve'.tr : 'group_leave'.tr,
                style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 18.0),
              ),
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
          ]),
        ));
  }

  @override
  void dispose() {
    Get.delete<GroupDetailLogic>();
    super.dispose();
  }
}
