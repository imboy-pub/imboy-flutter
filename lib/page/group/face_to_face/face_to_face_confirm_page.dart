import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

class FaceToFaceConfirmPage extends ConsumerStatefulWidget {
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
  ConsumerState<FaceToFaceConfirmPage> createState() =>
      FaceToFaceConfirmPageState();
}

class FaceToFaceConfirmPageState extends ConsumerState<FaceToFaceConfirmPage> {
  // 面对面建群确认页面用到
  // [{"nickname": "", "avatar":"", "user_id":""}]
  List<PeopleModel> memberList = [];

  StreamSubscription? ssMsg;
  StreamSubscription? _localeSubscription;

  // 防抖状态
  bool _isJoiningGroup = false;

  @override
  void initState() {
    //监听Widget是否绘制完毕
    super.initState();

    initData();
    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    // 异步检查是否有离线数据 TODO leeyi 2023-01-29 16:43:47
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    memberList = [];
    ssMsg?.cancel();
    _localeSubscription?.cancel();
    super.dispose();
  }

  /// 初始化一些数据
  Future<void> initData() async {
    memberList = List.from(widget.memberList);
    memberList.add(PeopleModel(id: 'last', account: ''));

    iPrint('🔔 [面对面确认] 开始监听 ChatExtendEvent，当前群组 gid: ${widget.gid}');
    iPrint('👥 [面对面确认] 初始成员列表: ${memberList.map((e) => e.id).toList()}');

    // 接收到新的消息订阅
    ssMsg ??= AppEventBus.on<ChatExtendEvent>().listen((
      ChatExtendEvent obj,
    ) async {
      iPrint('📨 [面对面确认] 收到 ChatExtendEvent - type: ${obj.type}, payload: ${obj.payload}');

      // 监听新成员加入
      if (obj.type == 'join_group') {
        final i = memberList.indexWhere(
          (e) =>
              e.id == obj.payload['userId'] &&
              widget.gid == obj.payload['groupId'],
        );

        iPrint(
          "✨ [面对面确认] join_group 事件 - widget.gid: ${widget.gid}, event.gid: ${obj.payload['groupId']}, userId: ${obj.payload['userId']}, 找到索引: $i",
        );

        if (i == -1) {
          memberList.insert(0, obj.payload['people']);
          iPrint('➕ [面对面确认] 添加新成员到列表: ${obj.payload['people'].id}');
          if (mounted) {
            setState(() {});
          }
        } else {
          iPrint('⚠️ [面对面确认] 成员已存在，跳过添加: ${obj.payload['userId']}');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: GlassAppBar(
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
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
                  titleStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
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
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                ),
                onPressed: _isJoiningGroup
                    ? null
                    : () async {
                        // 防抖：设置加入状态
                        setState(() => _isJoiningGroup = true);

                        try {
                          EasyLoading.show(status: t.loading);
                          final notifier = ref.read(
                            faceToFaceProvider.notifier,
                          );
                          Map<String, dynamic> res = await notifier
                              .faceToFaceSave(widget.gid, widget.code);
                          List<PeopleModel> memberList =
                              res['memberList'] ?? [];
                          Map<String, dynamic> group = res['group'];
                          await GroupRepo().save('', group);

                          if (context.mounted) {
                            // 使用 pushReplacement 替换当前页面为聊天页面
                            // 避免先 pop 再 push 导致的路由冲突
                            context.pushReplacement(
                              '/chat/${widget.gid}',
                              extra: {
                                'type': 'C2G',
                                'title': group['title'] ?? '',
                                'avatar': group['avatar'] ?? '',
                                'sign': group['introduction'] ?? '',
                                'memberCount': memberList.length,
                              },
                            );
                          }
                        } catch (e) {
                          debugPrint("faceToFaceSave error: $e");
                          EasyLoading.showError('${t.error}: $e');
                        } finally {
                          EasyLoading.dismiss();
                          // 恢复加入状态
                          if (mounted) {
                            setState(() => _isJoiningGroup = false);
                          }
                        }
                      },
                child: Text(
                  t.enterTheGroup,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                  ),
                ),
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
