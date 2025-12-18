import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/search/search_chat_view.dart';
import 'package:imboy/page/contact/people_info/people_info_view.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';
import 'package:imboy/store/model/chat_extend_model.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/group/group_member/group_member_view.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/ui/easy_dialog.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:synchronized/synchronized.dart';

import 'change_info_view.dart';
import 'group_detail_logic.dart';
import 'remove_member_view.dart';
import 'add_member_view.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  final String title;
  final int memberCount;
  final Function? callBack;
  final Map<String, dynamic>? options;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.title,
    required this.memberCount,
    this.callBack,
    this.options,
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

  // bool _top = false;

  // bool _showName = false;

  // bool _contact = false;
  // bool _dnd = false;

  String? time;

  // String cardName = '默认';

  // List memberList = [
  //   {'user': '+'},
  //   {'user': '-'}
  // ];
  List? dataGroup;

  StreamSubscription? ssMsgExt;

  @override
  void initState() {
    super.initState();
    initData();
    // getCardName();
  }

  void initData() async {
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
    logic.detail(gid: widget.groupId, sync: connected).then((
      GroupModel? g,
    ) async {
      iPrint(
        "logic.detail then connected $connected, ${g?.toJson().toString()}",
      );
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
    ssMsgExt ??= eventBus.on<ChatExtendModel>().listen((
      ChatExtendModel obj,
    ) async {
      iPrint("face_to_face_confirm widget.gid ${obj.toString()}");
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
      } else if (obj.type == 'leave_group' &&
          obj.payload['groupId'] == widget.groupId) {
        // 监听成员退出

        // 使用锁来保护消息处理逻辑
        await _lock.synchronized(() async {
          // GroupModel? g = await (GroupRepo()).findById(widget.groupId);
          final i = memberList.indexWhere(
            (PeopleModel p) => p.id == obj.payload['userId'],
          );
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

  void getCardName() async {
    // await InfoModel.getSelfGroupNameCardModel(widget.peer, callback: (str) {
    //   cardName = str.toString();
    //   setState(() {});
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.1),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          onPressed: () {
            Get.back(result: {'memberCount': memberCount});
          },
        ),
        title: Text(
          "${title.isEmpty ? 'chat_message'.tr : title} ($memberCount)",
          style: ThemeManager.instance.getTextStyle(
            FontSizeType.large,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 群成员头像区域 - 优化卡片设计
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'group_members'.tr,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AvatarList(
                    memberList: memberList,
                    titleMaxLines: 1,
                    titleStyle: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    width: 56,
                    height: 56,
                    column: (Get.width - 72) ~/ 56,
                    onTapAvatar: (PeopleModel p) {
                      Get.to(
                        () => PeopleInfoPage(id: p.id, scene: 'group_member'),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                    onTapAdd: () {
                      Get.to(() => AddMemberPage(groupId: widget.groupId));
                    },
                    onTapRemove: () {
                      Get.to(() => RemoveMemberPage(groupId: widget.groupId))?.then(
                        (value) {
                          if (value != null && value is List<GroupMemberModel>) {
                            iPrint("RemoveMemberPage then ${value.toList().toString()}");
                            for (var gm in value) {
                              final i = memberList.indexWhere((e) => e.id == gm.userId);
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
                        },
                      );
                    },
                  ),
                  // 查看全部成员按钮
                  if (memberCount > 20) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => Get.to(() => GroupMemberPage(groupId: widget.groupId)),
                        icon: Icon(
                          Icons.people_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(
                          'view_all_group_member'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 群组信息区域 - 优化卡片设计
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 群名称
                  _buildModernListTile(
                    context: context,
                    title: 'group_name'.tr,
                    value: title.isEmpty ? 'unnamed'.tr : title,
                    icon: Icons.group_outlined,
                    onTap: () async {
                      GroupModel group = (await logic.find(widget.groupId))!;
                      Get.to(
                        () => ChangeInfoPage(
                          group: group,
                          title: 'change_param'.trArgs(['group_name'.tr]),
                          subtitle: 'change_group_chat_name'.tr,
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      )?.then((value) {
                        iPrint("ChangeInfoPage back ${value.toString()}");
                        if (value != null && value is GroupModel) {
                          title = value.title;
                          setState(() {});
                        }
                      });
                    },
                  ),
                  ModernDivider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  // 群二维码
                  _buildModernListTile(
                    context: context,
                    title: 'group_qrcode'.tr,
                    icon: Icons.qr_code_2_outlined,
                    onTap: () async {
                      GroupModel group = (await logic.find(widget.groupId))!;
                      Get.to(
                        () => GroupQrCodePage(group: group),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                ],
              ),
            ),
            /* TODO 2024-08-15 15:22:59 群公告、备注、
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
              contentPadding: n.EdgeInsets.only(
                left: 16,
                right: 8.0,
              ),
              onTap: () {
                // Get.to(
                //       () => DenylistPage(),
                //   transition: Transition.rightToLeft,
                //   popGesture: true, // 右滑，返回上一页
                // );
              },
            ),
            Padding(
                padding: const EdgeInsets.only(left: 20),
                child: HorizontalLine(
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                )),
            Visibility(
              visible: isAdmin,
              child: Card(
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child:Text('group_management'.tr)),
                    ],
                  ),
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
            ),

            Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('remark'.tr), Text(strEmpty(groupRemark) ? ''.tr : '')],
                ),
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
            */
                    // 搜索功能区域 - 优化卡片设计
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildModernListTile(
                context: context,
                title: 'search_chat_content'.tr,
                icon: Icons.search_outlined,
                onTap: () {
                  Get.to(
                    () => SearchChatPage(
                      type: 'C2G',
                      peerId: widget.groupId,
                      peerTitle: widget.title,
                      peerAvatar: widget.options?['peerAvatar'],
                      peerSign: widget.options?['peerSign'],
                      conversationUk3: widget.options?['conversationUk3'],
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
              ),
            ),
            /* TODO 2024-08-15 15:21:42  消息免打扰 置顶
            HorizontalLine(
              height: 10,
              color: Theme.of(Get.context!).colorScheme.onPrimary,
            ),
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('message_mute'.tr),
                ],
              ),
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
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: HorizontalLine(
                height: 1.0,
              ),
            ),
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('pin_chat'.tr),
                ],
              ),
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
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: HorizontalLine(
                height: 1.0,
              ),
            ),
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('group_add_local'.tr),
                ],
              ),
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
            */
                  // 群组设置区域 - 优化卡片设计
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildModernListTile(
                context: context,
                title: 'group_alias'.tr,
                value: strEmpty(myGroupAlias) ? UserRepoLocal.to.current.nickname.tr : '',
                icon: Icons.edit_note_outlined,
                onTap: () {
                  // TODO: 实现群组别名修改功能
                },
              ),
            ),
            HorizontalLine(
              height: 10,

              color: Theme.of(Get.context!).colorScheme.onPrimary,
            ),

            // GroupItem(title: 'set_chat_background'.tr),

            // HorizontalLine(
            //   height: 10,
            // ),
            // 危险操作区域 - 优化卡片设计
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 清空聊天记录
                  _buildModernListTile(
                    context: context,
                    title: 'clear_chat_record'.tr,
                    icon: Icons.delete_sweep_outlined,
                    onTap: () {
                      String tips = 'confirm_delete_chat_record'.tr;
                      EasyDialog.showWarning(
                        context: context,
                        title: 'warning'.tr,
                        content: Text(tips),
                        confirmText: 'button_confirm'.tr,
                        cancelText: 'button_cancel'.tr,
                        onConfirm: () async {
                          int cid = await logic.cleanMessageByPeerId('C2G', widget.groupId);
                          if (cid > 0) {
                            backDoRefresh = true;
                            await Get.find<ConversationLogic>().hideConversation(cid);
                            await Get.find<ConversationLogic>().conversationsList();
                            EasyLoading.showSuccess('tip_success'.tr);
                          } else {
                            EasyLoading.showError('tip_failed'.tr);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
                    // 投诉功能 - 整合到危险操作区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildModernListTile(
                context: context,
                title: 'complaint'.tr,
                icon: Icons.flag_outlined,
                onTap: () {
                  // TODO: 实现投诉功能
                },
              ),
            ),

            // 底部操作按钮 - 优化设计
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                      Theme.of(context).colorScheme.error.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    String tips = "${role == 4 ? 'sure_to_dissolve_group'.tr : 'sure_to_leave_group'.tr}\n${'sure_delete_group_chat_record'.tr}";

                    EasyDialog.showWarning(
                      context: context,
                      title: 'tip_tips'.tr,
                      content: Text(tips),
                      confirmText: 'button_confirm'.tr,
                      cancelText: 'button_cancel'.tr,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    role == 4 ? 'group_dissolve'.tr : 'group_leave'.tr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 现代化的ListTile构建方法
  Widget _buildModernListTile({
    required BuildContext context,
    required String title,
    String? value,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.medium,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.medium,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  
  @override
  void dispose() {
    ssMsgExt?.cancel();
    Get.delete<GroupDetailLogic>();
    super.dispose();
  }
}
