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
  List<types.Message> messages = [];

  int nextAutoId = 0;

  int memberCount = 0;

  StreamSubscription? ssMsgExt;
  StreamSubscription? ssMsg;
  StreamSubscription? ssMsgState;

  ChatState() {
    ///Initialize variables
  }
}
