import 'package:flutter/material.dart';
import 'package:imboy/store/model/person_model.dart';

class MessageModel {
  int id;
  String type;
  String fromId; // 等价于数据库的 from
  String toId; // 等价于数据库的 to
  MsgPayloadModel payload;
  int serverTs; // 服务器组装消息的时间戳

  MessageModel(this.id,
      {@required this.type,
      @required this.fromId,
      @required this.toId,
      @required this.payload,
      this.serverTs});

//  Future<MessageModel> findByUid(String uid) async {
//    return await MessageRepo().findByUid(uid);
//  }

  MessageModel.fromMap(Map<String, dynamic> data) {
    id = data['id'];
    type = data['type'];
    fromId = data['from'] ?? '';
    toId = data['to'];
    payload = MsgPayloadModel.fromMap(data['payload']);
    serverTs = data['server_ts'];
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['type'] = this.type;
    data['from'] = this.fromId;
    data['to'] = this.toId;
    data['payload'] = this.payload.toMap();
    if (this.serverTs != null) {
      data['server_ts'] = this.serverTs;
    }
    debugPrint(">>>>>>>>>>>>>>>>>>> on MessageModel toMap {data}");
    return data;
  }

//
//  Future<PersonModel> get from async {
//    return PersonModel.find(this.fromId);
//  }

  PersonModel get from {
    PersonModel p = new PersonModel();
    PersonModel.find(this.fromId)
        .then((value) => debugPrint(">>>>>>>>>>>>>>>>>>> on get from $value"));
    return p;
  }

  PersonModel get to {
    PersonModel p = new PersonModel();
    PersonModel.find(this.toId).then((value) => p = value);
    return p;
  }
}

//  "type":"C2C",
//  "from":"18aw3p",
//  "to":"kybqdp",
//  "payload":{"msg_type":10,"content":"b1","send_ts":1596502941380},
//  "server_ts":1596502941499

/**
 * {msg_type:int, content:fix, send_ts:int}
 * @param payload.msgType
 * 消息类型:
 *    10 文本(默认)
 *    20 图片
 *    30 表情
 *    40 语音对讲
 *    50 摇一摇打招呼
 *    60 附近的人打招呼
 *    200 活动|公告
 *    [500 -- 1000) 系统消息
 *    501 用户上线
 * @param payload.content 消息实体，根据 msg_type 类型不同而不同，后端只做转发，多前端根据业务自行约定
 * @param payload.sendTs 发送时间，毫秒时间戳
 */
class MsgPayloadModel {
  int msgType; // 参考 @param payload.msgType 说明
  dynamic content; // 消息的正文，根据 msg_type 不同格式不一样
  int sendTs; // 消息发送的毫秒数

  MsgPayloadModel.fromMap(Map<String, dynamic> json) {
    msgType = json['msg_type'];
    content = json['content'];
    sendTs = json['send_ts'];
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['msg_type'] = this.msgType;
    data['content'] = this.content;
    data['send_ts'] = this.sendTs;
    return data;
  }
}

/*
* 实体类 - 消息内容（文本）
* @param text 文字消息内容
* @param type 消息类型
*
* */
class MessageText {
  String text;
  String type;

  MessageText({this.text, this.type});

  MessageText.fromMap(Map<String, dynamic> data) {
    text = data['text'];
    type = data['type'];
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['text'] = this.text;
    data['type'] = this.type;
    return data;
  }
}

class MessageTimconversationMconversation {
  MessageTimconversationMconversation.fromMap(Map<String, dynamic> json);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    return data;
  }
}
