import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/attachments/workspace_attachment_filters.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/channel_model.dart';

class _Api extends WorkspaceApi {
  @override
  Future<List<GroupModel>> memberGroups(String workspaceId) async => [
    GroupModel.fromJson({'id': 100, 'title': 'Alpha group'}),
  ];
  @override
  Future<List<ChannelModel>> channels(
    String workspaceId, {
    String? status,
  }) async => [
    ChannelModel.fromJson({'id': 200, 'name': 'Alpha channel'}),
  ];
}

void main() {
  testWidgets(
    'narrow screen supports source selection and uploader search together',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
      await StorageService.init();
      LocaleSettings.setLocaleSync(AppLocale.zhCn);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic> selection = {};
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [workspaceApiProvider.overrideWithValue(_Api())],
            child: MaterialApp(
              home: Scaffold(
                body: WorkspaceAttachmentFilters(
                  workspaceId: '100',
                  onChanged: (value) => selection = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 群组/频道选择走底部弹层（Material 下拉覆盖层已废弃）。
      await tester.tap(find.text('全部群组'));
      await tester.pumpAndSettle();
      expect(find.text('选择群组'), findsOneWidget);
      await tester.tap(find.text('Alpha group'));
      await tester.pumpAndSettle();
      expect(selection['group_id'], '100');
      await tester.tap(find.text('全部频道'));
      await tester.pumpAndSettle();
      expect(find.text('选择频道'), findsOneWidget);
      await tester.tap(find.text('Alpha channel'));
      await tester.pumpAndSettle();
      expect(selection['channel_id'], '200');
      expect(selection.containsKey('group_id'), isFalse);
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump(const Duration(milliseconds: 400));
      expect(selection['user_keyword'], 'Alice');
      expect(selection['channel_id'], '200');
      expect(tester.takeException(), isNull);
    },
  );
}
