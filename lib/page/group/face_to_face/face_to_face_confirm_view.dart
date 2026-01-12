import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_logic.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';

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
        AppEventBus.on<ChatExtendEvent>().listen((ChatExtendEvent obj) async {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: GlassAppBar(
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            _buildNumberWidget(context, widget.code),
            const SizedBox(height: 8),
            Text(
              t.createGroupF2fConfirmTips,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: AvatarList(
                  memberList: memberList,
                  titleStyle: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(t.enterTheGroup, style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary)),
                onPressed: () async {
                   EasyLoading.show(status: t.loading);
                   try {
                     Map<String, dynamic> res = await Get.find<FaceToFaceLogic>()
                         .faceToFaceSave(widget.gid, widget.code);
                     List<PeopleModel> memberList = res['memberList'] ?? [];
                     Map<String, dynamic> group = res['group'];
                     await GroupRepo().save('', group);
                     Get.off(
                       () => ChatPage(
                         peerId: widget.gid,
                         type: 'C2G',
                         peerTitle: group['title'] ?? '',
                         peerAvatar: group['avatar'] ?? '',
                         peerSign: group['introduction'] ?? '',
                         options: {'memberCount': memberList.length},
                       ),
                       preventDuplicates: false,
                     );
                   } catch (e) {
                     debugPrint("faceToFaceSave error: $e");
                     EasyLoading.showError('操作失败: $e');
                   } finally {
                     EasyLoading.dismiss();
                   }
                 },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberWidget(BuildContext context, String code) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: code.split('').map((char) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            char,
            style: theme.textTheme.displayMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }
}
