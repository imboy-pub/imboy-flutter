import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/api/contact_api.dart';
import 'package:imboy/store/api/denylist_api.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/store/model/people_model.dart';

class _Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final payload = options.path.contains('denylist')
        ? '{"list":[{"id":9007199254740992},{"id":9007199254740993}]}'
        : options.path.contains('face2face')
        ? '{"gid":9007199254740993,"group":{"id":9007199254740993},"member_list":[{"id":9007199254740997,"group_id":9007199254740993,"user_id":9007199254740995}]}'
        : options.path.contains('friend')
        ? '{"friend":[{"id":9007199254740993},{"id":9007199254740995}]}'
        : options.path.contains('member')
        ? '{"list":[{"id":9007199254740997,"group_id":9007199254740993,"user_id":9007199254740995}]}'
        : '{"list":[{"id":9007199254740993,"owner_uid":9007199254740995,"creator_uid":9007199254740997}]}';
    return ResponseBody.fromString(
      '{"code":0,"msg":"success","payload":$payload}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    HttpClient.adapterForTest = _Adapter();
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  test('actual group, member and contact APIs decode raw 64-bit IDs', () async {
    final groups = (await GroupApi().page())!['list'] as List;
    final group = GroupModel.fromJson(
      Map<String, dynamic>.from(groups.single as Map),
    );
    expect(group.groupId, '9007199254740993');
    expect(group.ownerUid, '9007199254740995');
    final members =
        (await GroupMemberApi().page(gid: group.groupId))!['list'] as List;
    final member = GroupMemberModel.fromJson(
      Map<String, dynamic>.from(members.single as Map),
    );
    expect(member.groupId, '9007199254740993');
    expect(member.userId, '9007199254740995');
    final friends = await ContactApi().listFriend();
    final contacts = friends
        .map((e) => ContactModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    expect(contacts.map((e) => e.peerId), [
      '9007199254740993',
      '9007199254740995',
    ]);
  });

  test('face-to-face save exposes exact group and member IDs', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final output = await container
        .read(faceToFaceProvider.notifier)
        .faceToFaceSave('9007199254740993', '1234');
    expect((output['group'] as Map)['id'], '9007199254740993');
    expect(
      (output['memberList'] as List<PeopleModel>).single.id,
      '9007199254740995',
    );
  });

  test('denylist API retains adjacent blocked identities', () async {
    final rows = (await DenylistApi().page())!['list'] as List;
    final ids = rows.map(
      (row) =>
          DenylistModel.fromJson(Map<String, dynamic>.from(row as Map))
              .deniedUid,
    );
    expect(ids, ['9007199254740992', '9007199254740993']);
  });
}
