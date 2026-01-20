import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/api/contact_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';

part 'contact_setting_provider.g.dart';

/// 联系人设置状态类
class ContactSettingState {
  final bool isInDenylist;
  final String peerRemark;

  const ContactSettingState({this.isInDenylist = false, this.peerRemark = ''});

  ContactSettingState copyWith({bool? isInDenylist, String? peerRemark}) {
    return ContactSettingState(
      isInDenylist: isInDenylist ?? this.isInDenylist,
      peerRemark: peerRemark ?? this.peerRemark,
    );
  }
}

/// 联系人设置 Notifier
@riverpod
class ContactSettingNotifier extends _$ContactSettingNotifier {
  final denylistRepo = UserDenylistRepo();

  @override
  ContactSettingState build() {
    return const ContactSettingState();
  }

  /// 初始化数据
  Future<void> initData(String peerId) async {
    final count = await denylistRepo.inDenylist(peerId);
    state = state.copyWith(isInDenylist: count > 0);
  }

  /// 切换黑名单状态
  Future<bool> toggleDenylist({
    required String peerId,
    required bool addToDenylist,
    required Map<String, dynamic> peerData,
  }) async {
    bool res;
    if (addToDenylist) {
      // 加入黑名单的逻辑由调用方处理
      res = true;
    } else {
      // 移出黑名单
      final count = await denylistRepo.delete(peerId);
      res = count > 0;
    }

    if (res) {
      state = state.copyWith(isInDenylist: addToDenylist);
    }

    return res;
  }

  /// 将联系人删除，同时删除与该联系人的聊天记录
  Future<bool> deleteContact(String uid) async {
    bool res = await (ContactApi()).deleteContact(uid);
    if (res) {
      await MessageRepo(tableName: MessageRepo.c2cTable).deleteByUid(uid);
      await ConversationRepo().delete('C2C', uid);
      await NewFriendRepo().deleteByUid(uid);
      await ContactRepo().deleteByUid(uid);
    }
    return res;
  }

  /// 更新备注
  void updateRemark(String newRemark) {
    state = state.copyWith(peerRemark: newRemark);
  }
}
