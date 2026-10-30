import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:mocktail/mocktail.dart';

class _UserRepo extends Mock implements UserRepoLocal {}

void main() {
  testWidgets('切环境时登出使用原环境直到清理结束', (tester) async {
    final previousEnv = currentEnv;
    currentEnv = 'dev';
    final repo = _UserRepo();
    final logout = Completer<bool>();
    String? logoutEnv;
    when(() => repo.quitLogin()).thenAnswer((_) {
      logoutEnv = currentEnv;
      return logout.future;
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 3000);
    addTearDown(() {
      currentEnv = previousEnv;
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [userRepoProvider.overrideWithValue(repo)],
        child: TranslationProvider(
          child: const MaterialApp(home: SettingPage()),
        ),
      ),
    );
    await tester.pump();
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    dropdown.onChanged!('local');
    await tester.pump();
    expect(logoutEnv, 'dev');
    expect(currentEnv, 'dev');
    expect(StorageService.to.getString('env'), 'local');
    verify(() => repo.quitLogin()).called(1);
    logout.complete(true);
    await tester.pump();
  });
}
