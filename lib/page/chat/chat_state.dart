// ignore: depend_on_referenced_packages
import 'package:scroll_to_index/scroll_to_index.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class ChatState {
  // List<types.Message> messages = [];

  AutoScrollController scrollController = AutoScrollController();

  // 当前会话新增消息
  List<types.Message> messages = [];

  ChatState() {
    ///Initialize variables
  }
}
