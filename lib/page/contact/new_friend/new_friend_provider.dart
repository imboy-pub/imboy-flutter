import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 新好友状态类
class NewFriendState {
  final List<dynamic> items;
  final bool isLoading;
  final String searchKwd;

  const NewFriendState({
    this.items = const [],
    this.isLoading = true,
    this.searchKwd = '',
  });

  NewFriendState copyWith({
    List<dynamic>? items,
    bool? isLoading,
    String? searchKwd,
  }) {
    return NewFriendState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      searchKwd: searchKwd ?? this.searchKwd,
    );
  }
}

/// 新好友状态通知器
class NewFriendNotifier extends Notifier<NewFriendState> {
  @override
  NewFriendState build() {
    return const NewFriendState();
  }

  /// 初始化数据
  Future<void> initData() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await listNewFriend(UserRepoLocal.to.currentUid);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 获取新好友列表
  Future<List<NewFriendModel>> listNewFriend(String uid) async {
    return await (NewFriendRepo()).listNewFriend(uid, 10000);
  }

  /// 收到添加朋友
  Future<void> receivedAddFriend(Map<String, dynamic> data) async {
    iPrint("CLIENT_ACK,S2C,${data['id']}");

    String uid = UserRepoLocal.to.currentUid;
    // 防御性转换：后端 from/to 可能是 int 或 String
    String from = (data["from"] ?? "").toString();
    String to = (data["to"] ?? "").toString();
    var payload = data["payload"] ?? <String, dynamic>{};
    if (payload is String) {
      payload = json.decode(payload);
    }
    Map<String, dynamic> saveData = {
      "uid": uid,
      NewFriendRepo.from: from,
      NewFriendRepo.to: to,
      NewFriendRepo.nickname: payload["from"]["nickname"] ?? "",
      NewFriendRepo.avatar: payload["from"]["avatar"] ?? "",
      NewFriendRepo.msg: payload["from"]["msg"] ?? "",
      NewFriendRepo.payload: json.encode(payload),
      NewFriendRepo.status: NewFriendStatus.waitingForValidation.index,
      // ⚠️ 必须是毫秒整数（num），不能传 DateTime 对象：save() 对已存在
      // 的 from/to 走 update 分支，update() 里 `(json[createdAt] as num)` 强转
      // DateTime 抛 TypeError → 事务回滚 → 同 from/to 的重复申请落库失败
      //（首次申请走 insert 分支不读本字段，故只在第二条申请时暴露）。
      NewFriendRepo.createdAt: DateTimeHelper.millisecond(),
    };
    iPrint("> on receivedAddFriend from=$from to=$to");
    // 不 await 的 Future 抛异常会变成未处理的异步错误被吞掉：申请没落库，
    // UI 却毫无反馈，表现为「退出再进申请就丢了」。必须 await 并让失败可见。
    try {
      await (NewFriendRepo()).save(saveData);
    } catch (e) {
      iPrint("❌ [NEW_FRIEND] 好友申请落库失败 from=$from to=$to error=$e");
      AppLoading.showError(t.common.saveFailedRetry);
    }
    replaceItems(NewFriendModel.fromJson(saveData));

    // 使用事件总线发送 ACK
    final msgId = data['id'];
    if (msgId == null || msgId.isEmpty == true) {
      iPrint("❌ [NEW_FRIEND] 消息ID为空，无法发送ACK");
      return;
    }
    // 直接发送 ACK 确认
    AckManager.to.sendAckDirect('S2C', msgId as String);
  }

  /// 确认添加朋友
  Future<void> receivedConfirmFriend(
    bool ack,
    Map<String, dynamic> data,
  ) async {
    iPrint("CLIENT_ACK,S2C,${data['id']}");
    String from = (data["from"] ?? "").toString();
    String to = (data["to"] ?? "").toString();
    NewFriendRepo repo = NewFriendRepo();
    NewFriendModel? obj = await repo.findByFromTo(to, from);
    iPrint(
      "> on receivedConfirmFriend(s2c) data=${json.encode(data)} obj=${obj?.from}/${obj?.to}/${obj?.status}",
    );
    if (obj != null) {
      obj.status = NewFriendStatus.added.index;
      try {
        await repo.update({"from": to, "to": from, "status": obj.status});
      } catch (e) {
        iPrint("❌ [NEW_FRIEND] 好友申请状态更新失败 from=$to to=$from error=$e");
        AppLoading.showError(t.common.saveFailedRetry);
      }
      replaceItems(obj);
      // 跨设备确认场景：S2C accept 更新成功后同步刷新角标
      ref.read(newFriendRemindProvider.notifier).countReminders();
    }
    if (ack) {
      final msgId = data['id'];
      if (msgId == null || msgId.isEmpty == true) {
        iPrint("❌ [NEW_FRIEND] 消息ID为空，无法发送ACK");
        return;
      }
      // 直接发送 ACK 确认
      AckManager.to.sendAckDirect('S2C', msgId as String);
    }
  }

  /// 删除好友申请记录
  Future<int> delete(String from, String to) async {
    int res = await (NewFriendRepo()).delete(from, to);
    final uk = from + to;
    final index = state.items.indexWhere((e) {
      if (e is NewFriendModel) {
        return e.uk == uk;
      }
      return false;
    });
    final newItems = List<dynamic>.from(state.items);
    newItems.removeAt(index);
    state = state.copyWith(items: newItems);
    return res;
  }

  /// 替换好友申请记录
  void replaceItems(NewFriendModel obj) {
    final newItems = List<dynamic>.from(state.items);
    final index = newItems.indexWhere((e) {
      if (e is NewFriendModel) {
        return e.uk == obj.uk;
      }
      return false;
    });
    iPrint("CLIENT_ACK replaceItems $index");
    if (index > -1) {
      newItems[index] = obj;
    } else {
      newItems.insert(0, obj);
    }
    state = state.copyWith(items: newItems);
  }

  /// 用户搜索
  Future<List<dynamic>> userSearch({
    int page = 1,
    int size = 10,
    String? kwd,
  }) async {
    // 使用 userApiProvider 调用 API
    final userApi = ref.read(userApiProvider);
    Map<String, dynamic>? payload = await userApi.userSearch(
      page: page,
      size: size,
      keyword: kwd ?? '',
    );
    if (payload?['list'] == null) {
      return [];
    }
    List<PeopleModel> list = [];
    for (var vo in (payload?['list'] as List)) {
      list.add(PeopleModel.fromJson(vo as Map<String, dynamic>));
    }
    return list;
  }
}

/// 新好友 Provider
final newFriendProvider = NotifierProvider<NewFriendNotifier, NewFriendState>(
  NewFriendNotifier.new,
);
