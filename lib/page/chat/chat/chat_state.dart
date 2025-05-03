// ignore: depend_on_referenced_packages
import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';

// ignore: depend_on_referenced_packages
import 'package:scroll_to_index/scroll_to_index.dart';

class ChatState {
  AutoScrollController scrollController = AutoScrollController(
    keepScrollOffset: false,
    suggestedRowHeight: 56,
  );

  // 网络状态描述
  RxBool connected = true.obs;

  // 当前会话新增消息
  final RxList<types.Message> messages = <types.Message>[].obs;
  final RxInt nextAutoId = 0.obs;
  final RxInt memberCount = 0.obs;

  StreamSubscription? ssMsgExt;
  StreamSubscription? ssMsg;
  StreamSubscription? ssMsgState;

  ChatState() {
    ///Initialize variables
  }

  // 添加消息时使用批量更新
  void addMessages(List<types.Message> newMessages) {
    messages.insertAll(0, newMessages);
  }

  // 清除状态
  void clear() {
    messages.clear();
    nextAutoId.value = 0;
    memberCount.value = 0;
    scrollController.dispose();
  }
}
