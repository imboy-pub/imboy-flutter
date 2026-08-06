import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

part 'people_info_more_provider.g.dart';

/// 更多个人信息状态类
class PeopleInfoMoreState {
  final String sign;
  final String sourcePrefix;
  final String source;
  final int groupCount;
  final List<GroupModel> sameGroupList;

  /// 共同群组请求是否失败。用于把「成功但为 0 个」和「请求超时/失败」区分开——
  /// 两者此前都渲染成「暂无共同群组」，用户分不清。
  final bool sameGroupFailed;

  const PeopleInfoMoreState({
    this.sign = '',
    this.sourcePrefix = '',
    this.source = '',
    this.groupCount = 0,
    this.sameGroupList = const [],
    this.sameGroupFailed = false,
  });

  PeopleInfoMoreState copyWith({
    String? sign,
    String? sourcePrefix,
    String? source,
    int? groupCount,
    List<GroupModel>? sameGroupList,
    bool? sameGroupFailed,
  }) {
    return PeopleInfoMoreState(
      sign: sign ?? this.sign,
      sourcePrefix: sourcePrefix ?? this.sourcePrefix,
      source: source ?? this.source,
      groupCount: groupCount ?? this.groupCount,
      sameGroupList: sameGroupList ?? this.sameGroupList,
      sameGroupFailed: sameGroupFailed ?? this.sameGroupFailed,
    );
  }
}

/// 更多个人信息状态通知器
@riverpod
class PeopleInfoMoreNotifier extends _$PeopleInfoMoreNotifier {
  @override
  PeopleInfoMoreState build() {
    return const PeopleInfoMoreState();
  }

  /// 初始化数据
  Future<void> initData(String id) async {
    ContactModel? model = await ContactRepo().findByUid(id);
    if (model == null) {
      return;
    }

    state = state.copyWith(
      sign: model.sign,
      source: model.sourceTr,
      sourcePrefix: model.isFrom == 1 ? '' : t.main.otherParty,
    );

    // 获取共同群组
    await sameGroup(id);
  }

  /// 获取共同群组
  Future<void> sameGroup(String id) async {
    Map<String, dynamic>? p = await GroupMemberApi().sameGroup(
      UserRepoLocal.to.currentUid,
      id,
    );

    // GroupMemberApi.sameGroup 在 !resp.ok（含超时）时返回 null —— 典型
    // fail-open：此前直接 return，groupCount 保持 0，页面渲染成「暂无共同群组」。
    if (p == null) {
      state = state.copyWith(sameGroupFailed: true);
      return;
    }

    final count = (p['count'] ?? 0) as int;
    state = state.copyWith(groupCount: count, sameGroupFailed: false);

    if (count > 0) {
      List<GroupModel> list = [];
      var repo = GroupRepo();

      for (var json in (p['list'] as List)) {
        GroupModel m = await repo.save('', json as Map<String, dynamic>);
        list.add(m);
      }

      state = state.copyWith(sameGroupList: list);
    }
  }
}
