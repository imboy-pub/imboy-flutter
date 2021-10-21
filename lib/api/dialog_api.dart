import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/http/http_client.dart';
import 'package:imboy/store/model/message_model.dart';

///**
/// 获取会话
/// @param type 会话类型
/// @param peer 参与会话的对方, C2C 会话为对方帐号 identifier, 群组会话为群组 ID
/// @return 会话实例
///

Future<dynamic> deleteConversationAndLocalMsgModel(String type, String id,
    {Callback? callback}) async {
  try {
    // var result = await im.deleteConversationAndLocalMsg(type, id);
    // callback(result);
  } on PlatformException {
    print("删除会话和聊天记录失败");
  }
}

Future<dynamic> delConversationModel(String identifier, String type,
    {Callback? callback}) async {
  try {
    // var result = await im.delConversation(identifier, type);
    // callback(result);
  } on PlatformException {
    print("删除会话失败");
  }
}

Future<dynamic> getUnreadMessageNumModel(String type, String id,
    {Callback? callback}) async {
  try {
    // var result = await im.getUnreadMessageNum(type, id);
    // callback(result);
  } on PlatformException {
    print("获取未读消息数量失败");
  }
}

Future<dynamic> setReadMessageModel(String type, String id,
    {Callback? callback}) async {
  try {
    // var result = await im.setReadMessage(type, id);
    // callback(result);
  } on PlatformException {
    print("设置消息为已读失败");
  }
}
