import 'dart:async';
import 'package:get/get.dart';

/// 聊天页面状态管理
/// 管理消息列表、滚动控制器、网络状态等
class ChatState {
  final int pageSize = 16; // 每页加载消息数量

  /// 网络连接状态
  final RxBool connected = true.obs;

  /// 是否还有更多消息可以加载
  final RxBool hasMoreMessage = true.obs;

  /// 是否正在加载消息
  final RxBool isLoading = false.obs;

  /// 下一条消息的自动ID（分页用）
  final RxInt nextAutoId = 0.obs;

  /// 群组成员数量（仅群聊有效）
  final RxInt memberCount = 0.obs;

  RxDouble composerHeight = 52.0.obs;

  /// 消息相关的事件订阅
  StreamSubscription? ssMsgExt;    // 扩展消息订阅
  StreamSubscription? ssMsg;       // 普通消息订阅
  StreamSubscription? ssMsgState;  // 消息状态订阅

  ChatState();

  /// 清除所有状态
  void clear() {
    nextAutoId.value = 0;
    memberCount.value = 0;
    // 不要立即 dispose scrollController，否则页面复用时报错
    // scrollController.dispose();
  }

  /// 销毁监听器和控制器
  void dispose() {
    ssMsgExt?.cancel();
    ssMsg?.cancel();
    ssMsgState?.cancel();
  }
}