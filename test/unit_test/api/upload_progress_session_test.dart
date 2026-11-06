import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

void main() {
  testWidgets('会话退出时即使上传停住也立即关闭其进度', (tester) async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService.init();
    await tester.pumpWidget(
      MaterialApp(builder: AppLoading.init(), home: const Scaffold()),
    );
    final actor = UserRepoLocal.to;
    final progress = UploadProgressSession(
      actor,
      actor.sessionGeneration,
      currentEnv,
      null,
    );
    progress.update(1, 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(t.common.uploading), findsOneWidget);

    final logout = actor.quitLogin();
    unawaited(logout.then<void>((_) {}, onError: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text(t.common.uploading), findsNothing);
    progress.update(2, 2);
    await tester.pump();
    expect(find.text(t.common.uploading), findsNothing);
    await progress.dispose();
  });
}
