import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/user_model.dart';

void main() {
  group('UserSettingModel.fromJson', () {
    test('parses mixed primitive representations safely', () {
      final model = UserSettingModel.fromJson({
        'allow_search': '1',
        'people_nearby_visible': 0,
        'chat_state': 123,
        'font_size': null,
        'enable_visibility_read': '0',
        'visibility_read_fraction': '0.75',
        'visibility_read_delay_ms': '800',
        'show_online_status': true,
        'allow_add_by_phone': 'off',
        'allow_add_by_qr': 1,
      });

      expect(model.allowSearch, isTrue);
      expect(model.peopleNearbyVisible, isFalse);
      expect(model.chatState, '123');
      expect(model.fontSize, 'normal');
      expect(model.enableVisibilityRead, isFalse);
      expect(model.visibilityReadFraction, 0.75);
      expect(model.visibilityReadDelayMs, 800);
      expect(model.showOnlineStatus, isTrue);
      expect(model.allowAddByPhone, isFalse);
      expect(model.allowAddByQR, isTrue);
    });
  });

  group('UserModel.fromJson', () {
    test('parses mixed field types without runtime cast errors', () {
      final model = UserModel.fromJson({
        'id': 42,
        'account': 10086,
        'nickname': null,
        'email': 123,
        'mobile': 18888888888,
        'avatar': '',
        'role': '3',
        'gender': '2',
        'region': false,
        'sign': 567,
        'setting': '{"lang":"zh-CN","notify":1}',
        'birthday': 20260101,
        'profession': 9,
        'school': null,
        'interests': ['music'],
      });

      expect(model.uid, '42');
      expect(model.account, '10086');
      expect(model.nickname, '');
      expect(model.email, '123');
      expect(model.mobile, '18888888888');
      expect(model.role, 3);
      expect(model.gender, 2);
      expect(model.region, 'false');
      expect(model.sign, '567');
      expect(model.setting, {'lang': 'zh-CN', 'notify': 1});
      expect(model.birthday, '20260101');
      expect(model.profession, '9');
      expect(model.school, '');
      expect(model.interests, '[music]');
    });
  });
}
