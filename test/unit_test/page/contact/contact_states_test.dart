import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/contact/apply_friend/apply_friend_provider.dart';
import 'package:imboy/page/contact/confirm_new_friend/confirm_new_friend_provider.dart';
import 'package:imboy/page/contact/contact_setting/contact_setting_provider.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_provider.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/page/contact/new_friend/new_friend_provider.dart';
import 'package:imboy/page/contact/people_info/people_info_provider.dart';
import 'package:imboy/page/contact/people_info_more/people_info_more_provider.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_provider.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_provider.dart';

/// contact/ 段各 provider 内纯不可变 State 类的 copyWith 逻辑测试。
/// 这些 State 类不依赖 IO/单例，可独立构造验证。
void main() {
  group('ApplyFriendState', () {
    test('默认值', () {
      const s = ApplyFriendState();
      expect(s.role, 'all');
      expect(s.visibilityLook, true);
      expect(s.donotlethimlook, false);
      expect(s.donotlookhim, false);
      expect(s.peerTag, '');
    });
    test('copyWith 仅更新指定字段', () {
      const s = ApplyFriendState();
      final s2 = s.copyWith(role: 'just_chat', peerTag: 'work');
      expect(s2.role, 'just_chat');
      expect(s2.peerTag, 'work');
      expect(s2.visibilityLook, true); // 未变
    });
    test('copyWith 无参返回等值副本', () {
      const s = ApplyFriendState(donotlookhim: true);
      final s2 = s.copyWith();
      expect(s2.donotlookhim, true);
      expect(identical(s, s2), false);
    });
  });

  group('ConfirmNewFriendState', () {
    test('默认值', () {
      const s = ConfirmNewFriendState();
      expect(s.role, 'all');
      expect(s.visibilityLook, true);
      expect(s.peerTag, '');
    });
    test('copyWith 更新布尔字段', () {
      const s = ConfirmNewFriendState();
      final s2 = s.copyWith(donotlethimlook: true, donotlookhim: true);
      expect(s2.donotlethimlook, true);
      expect(s2.donotlookhim, true);
      expect(s2.role, 'all');
    });
    test('copyWith 更新 role 不影响其它', () {
      const s = ConfirmNewFriendState(peerTag: 't1');
      final s2 = s.copyWith(role: 'just_chat');
      expect(s2.role, 'just_chat');
      expect(s2.peerTag, 't1');
    });
  });

  group('ContactSettingState', () {
    test('默认值', () {
      const s = ContactSettingState();
      expect(s.isInDenylist, false);
      expect(s.peerRemark, '');
    });
    test('copyWith isInDenylist', () {
      const s = ContactSettingState();
      expect(s.copyWith(isInDenylist: true).isInDenylist, true);
    });
    test('copyWith peerRemark 不影响 denylist', () {
      const s = ContactSettingState(isInDenylist: true);
      final s2 = s.copyWith(peerRemark: 'r');
      expect(s2.peerRemark, 'r');
      expect(s2.isInDenylist, true);
    });
  });

  group('ContactSettingTagState', () {
    test('默认值', () {
      const s = ContactSettingTagState();
      expect(s.valueChanged, false);
      expect(s.val, '');
    });
    test('copyWith valueChanged', () {
      expect(
        const ContactSettingTagState()
            .copyWith(valueChanged: true)
            .valueChanged,
        true,
      );
    });
    test('copyWith val', () {
      expect(const ContactSettingTagState().copyWith(val: 'abc').val, 'abc');
    });
  });

  group('ContactState', () {
    test('默认值 isLoading=true', () {
      const s = ContactState();
      expect(s.contactList, isEmpty);
      expect(s.isLoading, true);
      expect(s.indexBarData, isEmpty);
    });
    test('copyWith isLoading=false', () {
      expect(const ContactState().copyWith(isLoading: false).isLoading, false);
    });
    test('copyWith indexBarData', () {
      final s = const ContactState().copyWith(indexBarData: {'A', 'B'});
      expect(s.indexBarData, {'A', 'B'});
      expect(s.isLoading, true);
    });
  });

  group('NewFriendState', () {
    test('默认值 isLoading=true', () {
      const s = NewFriendState();
      expect(s.items, isEmpty);
      expect(s.isLoading, true);
      expect(s.searchKwd, '');
    });
    test('copyWith searchKwd', () {
      expect(const NewFriendState().copyWith(searchKwd: 'kw').searchKwd, 'kw');
    });
    test('copyWith items', () {
      final s = const NewFriendState().copyWith(items: [1, 2, 3]);
      expect(s.items.length, 3);
    });
  });

  group('PeopleInfoState', () {
    test('默认值', () {
      const s = PeopleInfoState();
      expect(s.gender, 0);
      expect(s.isFriend, 0);
      expect(s.nickname, '');
      expect(s.lastSeenAt, 0);
    });
    test('copyWith 多字段', () {
      final s = const PeopleInfoState().copyWith(
        nickname: 'n',
        remark: 'r',
        isFriend: 1,
      );
      expect(s.nickname, 'n');
      expect(s.remark, 'r');
      expect(s.isFriend, 1);
      expect(s.gender, 0);
    });
    test('copyWith tag/source', () {
      final s = const PeopleInfoState(
        account: 'acc',
      ).copyWith(tag: 'vip', source: 'qr');
      expect(s.tag, 'vip');
      expect(s.source, 'qr');
      expect(s.account, 'acc');
    });
  });

  group('PeopleInfoMoreState', () {
    test('默认值', () {
      const s = PeopleInfoMoreState();
      expect(s.sign, '');
      expect(s.groupCount, 0);
      expect(s.sameGroupList, isEmpty);
    });
    test('copyWith groupCount', () {
      expect(const PeopleInfoMoreState().copyWith(groupCount: 3).groupCount, 3);
    });
    test('copyWith sourcePrefix 不影响 sign', () {
      final s = const PeopleInfoMoreState(
        sign: 's',
      ).copyWith(sourcePrefix: 'p');
      expect(s.sourcePrefix, 'p');
      expect(s.sign, 's');
    });
  });

  group('PeopleNearbyState', () {
    test('默认值', () {
      const s = PeopleNearbyState();
      expect(s.page, 1);
      expect(s.size, 20);
      expect(s.limit, 90);
      expect(s.peopleNearbyVisible, false);
    });
    test('copyWith 经纬度', () {
      final s = const PeopleNearbyState().copyWith(
        longitude: '1.1',
        latitude: '2.2',
      );
      expect(s.longitude, '1.1');
      expect(s.latitude, '2.2');
    });
    test('copyWith visible/page', () {
      final s = const PeopleNearbyState().copyWith(
        peopleNearbyVisible: true,
        page: 2,
      );
      expect(s.peopleNearbyVisible, true);
      expect(s.page, 2);
      expect(s.size, 20);
    });
  });

  group('RecentlyRegisteredUserState', () {
    test('默认值', () {
      const s = RecentlyRegisteredUserState();
      expect(s.page, 1);
      expect(s.size, 50);
      expect(s.isLoading, false);
      expect(s.kwd, '');
    });
    test('copyWith kwd', () {
      expect(const RecentlyRegisteredUserState().copyWith(kwd: 'q').kwd, 'q');
    });
    test('copyWith page/isLoading', () {
      final s = const RecentlyRegisteredUserState().copyWith(
        page: 2,
        isLoading: true,
      );
      expect(s.page, 2);
      expect(s.isLoading, true);
      expect(s.size, 50);
    });
  });
}
