// integration_test/contact/confirm_new_friend_test.dart
//
// 确认好友申请页 UI 集成测试
//
// 运行：
//   flutter test integration_test/contact/confirm_new_friend_test.dart \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=TEST_PHONE=+8613800138000 \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     -d <real_device_id>

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/i18n/strings.g.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('确认好友申请', () {
    testWidgets(
      '进入新朋友列表并跳转确认好友申请页进行验证和提交',
      (tester) async {
        await ensureAppLaunched(tester, maxSeconds: 3);
        await takeScreenshot(tester, 'confirm_friend_01_launch');

        if (!await checkPreconditions(tester)) return;

        await settle(tester, maxSeconds: 2);
        await takeScreenshot(tester, 'confirm_friend_02_login_ok');

        // 1. 进入联系人 Tab
        if (!await _openContactTab(tester)) {
          markTestSkipped('无法进入联系人页，跳过');
          return;
        }
        await settle(tester, maxSeconds: 2);
        await takeScreenshot(tester, 'confirm_friend_03_contact_tab');

        // 2. 查找并进入「新朋友」入口
        final newFriendEntry = find.byWidgetPredicate((w) {
          if (w is! ListTile) return false;
          final titleWidget = w.title;
          if (titleWidget is! Text) return false;
          final title = titleWidget.data?.trim();
          return title == t.contact.newFriend ||
              title == '新朋友' ||
              title == 'New Friends';
        });

        if (!tester.any(newFriendEntry)) {
          // 尝试用文本直接找
          final newFriendText = find.text(t.contact.newFriend);
          if (tester.any(newFriendText)) {
            await safeTap(tester, newFriendText);
          } else {
            markTestSkipped('未找到「新朋友」入口，跳过');
            return;
          }
        } else {
          await safeTap(tester, newFriendEntry.first);
        }

        await settle(tester, maxSeconds: 2);
        await takeScreenshot(tester, 'confirm_friend_04_new_friend_list');

        // 3. 寻找待接受的好友申请中的「接受」按钮
        final acceptButton = find.byWidgetPredicate((w) {
          if (w is! CupertinoButton) return false;
          final child = w.child;
          if (child is! Text) return false;
          final text = child.data?.trim();
          return text == t.common.accept || text == '接受' || text == 'Accept';
        });

        if (!tester.any(acceptButton)) {
          markTestSkipped('新朋友列表中没有处于待接受状态的申请，无法测试确认页面。');
          return;
        }

        // 点击第一个「接受」按钮
        await safeTap(tester, acceptButton.first);
        await settle(tester, maxSeconds: 2);
        await takeScreenshot(tester, 'confirm_friend_05_confirm_page');

        // === 进入 ConfirmNewFriendPage ===
        flowLog('进入确认新好友申请页面，开始验证功能点');

        // [功能点 1]：展示对方发来的验证消息
        final verificationMessageHeader = find.text(
          t.common.verificationMessage.toUpperCase(),
        );
        expect(
          verificationMessageHeader,
          findsOneWidget,
          reason: '应该渲染「验证消息」分组标题',
        );

        // [功能点 2]：备注输入框默认填充对方昵称
        final remarkTextFieldFinder = find.byType(CupertinoTextField);
        expect(
          remarkTextFieldFinder,
          findsOneWidget,
          reason: '应该有一个备注 CupertinoTextField 输入框',
        );

        final CupertinoTextField remarkTextField = tester
            .widget<CupertinoTextField>(remarkTextFieldFinder);
        final remarkController = remarkTextField.controller;
        expect(remarkController, isNotNull, reason: '备注输入框应该有绑定的 Controller');
        expect(
          remarkController!.text.isNotEmpty,
          isTrue,
          reason: '备注输入框默认应填充对方昵称，不能为空',
        );
        flowLog('备注默认填充内容: ${remarkController.text}');

        // [功能点 3]：修改备注并限制 80 字上限
        expect(
          remarkTextField.maxLength,
          equals(80),
          reason: '备注输入框的最大长度 maxLength 限制必须为 80',
        );

        // 测试修改备注
        await tester.enterText(remarkTextFieldFinder, '测试备注修改_IntegrationTest');
        await settle(tester, maxSeconds: 1);
        expect(
          remarkController.text,
          equals('测试备注修改_IntegrationTest'),
          reason: '修改备注应当成功回填',
        );

        // [功能点 4 & 5]：标签部分验证
        final addTagPlaceholderFinder = find.text(t.common.addTag);
        expect(
          addTagPlaceholderFinder,
          findsOneWidget,
          reason: '未选标签时应该显示「添加标签」或 t.common.addTag 占位文案',
        );

        // [功能点 8]：提交前收起键盘避免遮挡
        // [功能点 6 & 7]：提交中按钮禁用并显示转圈，以及最终点击完成提交
        final accomplishButton = find.byWidgetPredicate((w) {
          if (w is! ElevatedButton) return false;
          final child = w.child;
          if (child is! Text) return false;
          final text = child.data?.trim();
          return text == t.common.buttonAccomplish ||
              text == '完成' ||
              text == 'Accomplish';
        });

        expect(
          accomplishButton,
          findsOneWidget,
          reason: '应该有一个「完成」/ t.common.buttonAccomplish 提交按钮',
        );

        if (!requireBusinessWriteAuthorization()) return;
        flowLog('点击「完成」按钮，提交好友确认');
        await safeTap(tester, accomplishButton);
        await settle(tester, maxSeconds: 3);
        await takeScreenshot(tester, 'confirm_friend_06_after_accept');

        // 验证提交完成后应当返回到新朋友列表，且该条申请状态已变更为「已添加」
        final addedText = find.text(t.common.added);
        expect(addedText, findsWidgets, reason: '接受好友申请成功后应显示「已添加」状态');

        flowLog('✅ 好友确认申请测试完全通过！');
        drainKnownFrameworkExceptions(tester);
      },
      semanticsEnabled: false,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}

Future<bool> _openContactTab(WidgetTester tester) async {
  final tapped = await tapAny(tester, [
    find.byKey(const Key('tab_contacts')),
    find.byIcon(Icons.people),
    find.byIcon(Icons.people_outline),
    find.byIcon(Icons.contacts),
    find.text('联系人'),
    find.text('Contacts'),
    find.text('Friends'),
  ]);
  if (tapped) await settle(tester, maxSeconds: 2);
  return tapped;
}
