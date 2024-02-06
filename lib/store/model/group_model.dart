import 'package:flutter/services.dart';
import 'package:imboy/config/init.dart';

class GroupModel {
  // int get updatedAtLocal =>
  //     updatedAt + DateTime.now().timeZoneOffset.inMilliseconds;
  //
  // int get createdAtLocal =>
  //     createdAt + DateTime.now().timeZoneOffset.inMilliseconds;
  //
  static Future<dynamic> inviteGroupMember(List list, String groupId,
      {Callback? callback}) async {
    try {
      // var result = await im.group.inviteGroupMember(list, groupId);
      // callback(result);
    } on PlatformException {
      // print('邀请好友进群  失败');
    }
  }

  static Future<dynamic> quitGroupModel(String groupId,
      {Callback? callback}) async {
    try {
      // var result = await im.group.quitGroup(groupId);
      // callback(result);
    } on PlatformException {
      // print('退出群聊  失败');
      callback!('退出群聊  失败');
    }
  }

  static Future<dynamic> deleteGroupMemberModel(String groupId, List deleteList,
      {Callback? callback}) async {
    try {
      // var result = await im.group.deleteGroupMember(groupId, deleteList);
      // callback(result);
    } on PlatformException {
      // print('删除群成员  失败');
    }
  }

  static Future<dynamic> getGroupMembersListModel(String groupId,
      {Callback? callback}) async {
    try {
      // var result = await im.group.getGroupMembersList(groupId);
      // callback(result);
    } on PlatformException {
      // print('获取群成员  失败');
    }
  }

  static Future<dynamic> getGroupMembersListModelLIST(String groupId,
      {Callback? callback}) async {
    try {
      // var result = await im.group.getGroupMembersList(groupId);
      // print('获取群成员 getGroupMembersListModel >>>> $result');
      // List memberList = json.decode(result.toString().replaceAll("'", '"'));
      // if (listNoEmpty(memberList)) {
      //   for (int i = 0; i < memberList.length; i++) {
      //     List<String> ls = new List();
      //
      //     ls.add(memberList[i]['user']);
      //   }
      // }
      // callback(result);
    } on PlatformException {
      // print('获取群成员  失败');
    }
  }

  static Future<dynamic> getGroupListModel(Callback? callback) async {
    try {
      // var result = await im.group.getGroupList();
      // callback(result);
    } on PlatformException {
      // print('获取群列表  失败');
    }
  }

  static Future<dynamic> getGroupInfoListModel(List<String> groupID,
      {Callback? callback}) async {
    try {
      // var result = await im.group.getGroupInfoList(groupID);
      // callback(result);
      // return result;
    } on PlatformException {
      // print('获取群资料  失败');
    }
  }

  static Future<dynamic> deleteGroupModel(String groupId,
      {Callback? callback}) async {
    try {
      // var result = await im.group.deleteGroup(groupId);
      // callback(result);
    } on PlatformException {
      // print('解散群  失败');
    }
  }

  static Future<dynamic> modifyGroupNameModel(
      String groupId, String setGroupName,
      {Callback? callback}) async {
    try {
      // var result = await im.group.modifyGroupName(groupId, setGroupName);
      // callback(result);
    } on PlatformException {
      // print('修改群名称  失败');
    }
  }

  static Future<dynamic> modifyGroupIntroductionModel(
      String groupId, String setIntroduction,
      {Callback? callback}) async {
    try {
      // var result =
      //     await im.group.modifyGroupIntroduction(groupId, setIntroduction);
      // callback(result);
    } on PlatformException {
      // print('修改群简介  失败');
    }
  }

  static Future<dynamic> modifyGroupNotificationModel(
      String groupId, String notification, String time,
      {Callback? callback}) async {
    try {
      // var result =
      //     await im.group.modifyGroupNotification(groupId, notification, time);
      // if (callback != null) callback(result);
    } on PlatformException {
      // print('修改群公告  失败');
    }
  }

  static Future<dynamic> setReceiveMessageOptionModel(
      String groupId, String identifier, int type,
      {Callback? callback}) async {
    try {
      // var result =
      //     await im.group.setReceiveMessageOption(groupId, identifier, type);
      // callback(result);
    } on PlatformException {
      // print('修改群消息提醒选项  失败');
    }
  }

  static getUsersProfile(item, Null Function(Cb) param1) {}
}

class Cb {}
