import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel.fromJson({'uid': 'first'});
  void select(String uid) =>
      state = uid.isEmpty ? null : UserModel.fromJson({'uid': uid});
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _Api extends WorkspaceApi {
  final pending = [
    Completer<List<GroupModel>>(),
    Completer<List<GroupModel>>(),
  ];
  int calls = 0;
  @override
  Future<List<GroupModel>> memberGroups(EntityId workspaceId) =>
      pending[calls++].future;
}

GroupModel _group(int id) =>
    GroupModel.fromJson({'id': id, 'title': 'Group $id'});

void main() {
  test('切账号后同工作区的迟到响应不能覆盖新账号，退出停止请求', () async {
    final api = _Api();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
        workspaceApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final provider = workspaceGroupsProvider('100');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    expect(api.calls, 1);
    container.read(_account.notifier).select('second');
    await container.pump();
    expect(api.calls, 2);
    api.pending[1].complete([_group(2)]);
    // GroupModel.groupId 经 channelDecimalId 归一为十进制字符串
    expect((await container.read(provider.future)).single.groupId, '2');
    api.pending[0].complete([_group(1)]);
    await container.pump();
    expect(container.read(provider).requireValue.single.groupId, '2');
    container.read(_account.notifier).select('');
    await container.pump();
    expect(await container.read(provider.future), isEmpty);
    expect(api.calls, 2);
  });
}
