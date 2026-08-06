import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/personal_info/set_gender/set_gender_provider.dart';
import 'package:imboy/page/personal_info/set_nickname/set_nickname_provider.dart';
import 'package:imboy/page/personal_info/set_region/set_region_provider.dart';
import 'package:imboy/page/personal_info/update/update_provider.dart';

void main() {
  group('SetGenderState', () {
    test('SG-1 默认值', () {
      const s = SetGenderState();
      expect(s.selectedGender, '');
      expect(s.pendingGender, '');
      expect(s.isSaving, false);
    });

    test('SG-2 copyWith 选择性覆盖', () {
      const s = SetGenderState(selectedGender: 'male');
      final n = s.copyWith(pendingGender: 'female', isSaving: true);
      expect(n.selectedGender, 'male');
      expect(n.pendingGender, 'female');
      expect(n.isSaving, true);
    });

    test('SG-3 copyWith 不传保留原值且不可变', () {
      const s = SetGenderState(selectedGender: 'male', isSaving: true);
      final n = s.copyWith();
      expect(n.selectedGender, 'male');
      expect(n.isSaving, true);
      expect(s.pendingGender, '');
    });
  });

  group('SetNicknameState', () {
    test('SN-1 默认值', () {
      const s = SetNicknameState();
      expect(s.nickname, '');
      expect(s.canSave, false);
      expect(s.isSaving, false);
      expect(s.validationError, '');
      expect(s.remainingChars, 24);
    });

    test('SN-2 copyWith 覆盖部分字段', () {
      const s = SetNicknameState();
      final n = s.copyWith(nickname: 'abc', canSave: true, remainingChars: 21);
      expect(n.nickname, 'abc');
      expect(n.canSave, true);
      expect(n.remainingChars, 21);
      expect(n.validationError, '');
    });

    test('SN-3 copyWith 保留 validationError', () {
      const s = SetNicknameState(validationError: 'too long');
      final n = s.copyWith(isSaving: true);
      expect(n.validationError, 'too long');
      expect(n.isSaving, true);
    });
  });

  group('SetRegionState', () {
    test('SR-1 默认值', () {
      const s = SetRegionState();
      expect(s.regionList, isEmpty);
      expect(s.selectedRegion, '');
      expect(s.hasChanged, false);
      expect(s.regionPath, isEmpty);
    });

    test('SR-2 copyWith 覆盖列表与路径', () {
      const s = SetRegionState();
      final n = s.copyWith(
        regionList: [1, 2],
        regionPath: ['北京', '海淀'],
        hasChanged: true,
      );
      expect(n.regionList, [1, 2]);
      expect(n.regionPath, ['北京', '海淀']);
      expect(n.hasChanged, true);
      expect(n.selectedRegion, '');
    });

    test('SR-3 copyWith 不传保留原值', () {
      const s = SetRegionState(selectedRegion: '广东', hasChanged: true);
      final n = s.copyWith();
      expect(n.selectedRegion, '广东');
      expect(n.hasChanged, true);
    });
  });

  group('UpdatePageState', () {
    test('UP-1 默认值', () {
      const s = UpdatePageState();
      expect(s.value, '');
      expect(s.valueChanged, false);
    });

    test('UP-2 copyWith 覆盖', () {
      const s = UpdatePageState();
      final n = s.copyWith(value: 'hi', valueChanged: true);
      expect(n.value, 'hi');
      expect(n.valueChanged, true);
    });

    test('UP-3 copyWith 不传保留原值', () {
      const s = UpdatePageState(value: 'hi', valueChanged: true);
      final n = s.copyWith(value: 'bye');
      expect(n.value, 'bye');
      expect(n.valueChanged, true);
    });
  });
}
