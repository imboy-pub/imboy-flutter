import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/store/model/contact_model.dart';

/// `ContactState.contactList` 混着 6 个功能入口的伪 ContactModel（负数 peerId）。
/// 任何"选人"场景消费整份列表都会把它们渲染出来 —— 真机实测：
/// 群详情 `+` 加成员，列表里出现「朋友圈」「找附近的人」等菜单项。
ContactModel _c(int peerId) => ContactModel(peerId: peerId, nickname: 'n');

void main() {
  group('isRealContact', () {
    test('6 个功能入口占位全部被判为非真实联系人', () {
      const sentinels = [
        kPeerIdMomentFeed,
        kPeerIdPeopleNearby,
        kPeerIdNewFriend,
        kPeerIdGroup,
        kPeerIdTag,
        kPeerIdAssistantPlaza,
      ];
      for (final id in sentinels) {
        expect(isRealContact(_c(id)), isFalse, reason: 'peerId=$id 是功能入口');
      }
    });

    test('正数 TSID 是真实好友', () {
      expect(isRealContact(_c(104603643803863040)), isTrue);
      expect(isRealContact(_c(1)), isTrue);
    });

    test('过滤后只剩真实好友', () {
      final list = [
        _c(kPeerIdMomentFeed),
        _c(51698),
        _c(kPeerIdGroup),
        _c(104603643803863040),
      ];
      final real = list.where(isRealContact).map((c) => c.peerId).toList();
      expect(real, [51698, 104603643803863040]);
    });
  });
}
