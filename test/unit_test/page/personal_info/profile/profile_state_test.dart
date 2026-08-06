import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/personal_info/profile/profile_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// ProfileState 纯不可变状态类单测（直接 new，无需 ProviderScope）。
/// Notifier 的 build()/网络方法依赖 UserRepoLocal.to GetX 单例，不可测，故仅覆盖 State。
void main() {
  group('ProfileState 默认值', () {
    test('PS-1 默认构造各字段为期望初值', () {
      final s = ProfileState();
      expect(s.avatar, '');
      expect(s.nickname, '');
      expect(s.gender, 0);
      expect(s.completeness, 0);
      // completenessColor 默认走 token iosRed（原 Colors.red 已映射）
      expect(s.completenessColor, AppColors.iosRed);
      expect(s.allowSearch, true);
      expect(s.allowNearbyVisible, false);
      expect(s.isLoading, false);
      expect(s.isUploading, false);
      // userModel 兜底非空
      expect(s.userModel.uid, '');
    });
  });

  group('ProfileState copyWith', () {
    test('PS-2 仅覆盖传入字段，其余保留原值', () {
      final base = ProfileState(nickname: 'old', completeness: 10);
      final next = base.copyWith(nickname: 'new');
      expect(next.nickname, 'new');
      // 未传入的 completeness 保留
      expect(next.completeness, 10);
      // 原对象不被修改（不可变）
      expect(base.nickname, 'old');
    });

    test('PS-3 copyWith 不传参返回等价副本（字段全保留）', () {
      final base = ProfileState(
        avatar: 'a.png',
        gender: 2,
        completeness: 75,
        completenessColor: AppColors.iosGreen,
        isUploading: true,
      );
      final copy = base.copyWith();
      expect(copy.avatar, 'a.png');
      expect(copy.gender, 2);
      expect(copy.completeness, 75);
      expect(copy.completenessColor, AppColors.iosGreen);
      expect(copy.isUploading, true);
    });

    test('PS-4 隐私设置布尔字段可独立覆盖', () {
      final base = ProfileState();
      final next = base.copyWith(
        allowSearch: false,
        showOnlineStatus: false,
        allowAddByQR: false,
      );
      expect(next.allowSearch, false);
      expect(next.showOnlineStatus, false);
      expect(next.allowAddByQR, false);
      // 未改的保持默认
      expect(next.allowAddByPhone, true);
    });

    test('PS-5 completenessColor 可被任意 token 色覆盖', () {
      final s = ProfileState().copyWith(completenessColor: AppColors.iosOrange);
      expect(s.completenessColor, AppColors.iosOrange);
      expect(s.completenessColor, isA<Color>());
    });
  });
}
