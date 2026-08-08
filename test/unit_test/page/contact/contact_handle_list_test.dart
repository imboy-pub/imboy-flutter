import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 真机实证 BUG：生产 /api/v1/friend/list 返回 remark/nickname/account 全空的
/// 好友（测试遗留垃圾数据）时，handleList 里 `''.substring(0, 1)` 抛
/// RangeError，被 _syncFriendFromServer 的 `on Object catch` 吞掉 →
/// contactList 保持空 → 联系人页空态 + 顶部 6 个虚拟行入口（朋友圈/附近的人/
/// AI 助手广场/新的朋友/群聊/标签）全部消失。
/// 本文件钉死 handleList 对空 title 的健壮性契约。
ContactModel _c(int peerId, {String nickname = '', String account = ''}) =>
    ContactModel(peerId: peerId, nickname: nickname, account: account);

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // handleList → _buildTopItems → AppFeatureRegistry.isEnabled 读
    // StorageService snapshot，测试环境必须先初始化。
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('ContactNotifier.handleList', () {
    test('remark/nickname/account 全空的好友不抛异常，虚拟行仍插入', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(contactProvider.notifier);

      // 三源全空 → title == ''
      final blank = _c(51698);
      expect(blank.title, '');

      expect(() => notifier.handleList([blank]), returnsNormally);

      final list = container.read(contactProvider).contactList;
      final peerIds = list.map((c) => c.peerId).toSet();
      // 顶部功能入口未被吞掉
      expect(peerIds, contains(kPeerIdMomentFeed));
      expect(peerIds, contains(kPeerIdGroup));
      // 空 title 好友归入 '#' 分组而不是崩掉
      final processed = list.firstWhere((c) => c.peerId == 51698);
      expect(processed.nameIndex, '#');
    });

    test('纯 emoji/符号 title 归入 # 分组不抛异常', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(contactProvider.notifier);

      // lpinyin 对非空 title 几乎恒返回非空（emoji→'�'、符号→'! .'等），
      // 但首字符非 [A-Z]，必须归入 '#' 而不是崩或进错误分组。
      for (final nickname in ['😀😀', '!!!', '...', '￥￥']) {
        expect(
          () => notifier.handleList([_c(51699, nickname: nickname)]),
          returnsNormally,
        );
        final processed = container
            .read(contactProvider)
            .contactList
            .firstWhere((c) => c.peerId == 51699);
        expect(processed.nameIndex, '#');
      }
    });

    test('正常好友 nameIndex 取拼音/首字母', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(contactProvider.notifier);

      notifier.handleList([_c(104603643803863040, nickname: 'Alice')]);

      final list = container.read(contactProvider).contactList;
      final processed = list.firstWhere((c) => c.peerId == 104603643803863040);
      expect(processed.nameIndex, 'A');
      expect(container.read(contactProvider).indexBarData, contains('A'));
    });
  });
}
