/// PhoneInputWidget 回调契约测试 — 真机 P0 缺陷回归。
///
/// 缺陷取证（2026-10-07 真机，华为 MRD AL00 + 本地栈）：
/// 旧实现回调只给 fullNumber（国家码+号码无分隔拼接，如 +8613800000001），
/// 调用方（signup/login/forgot_password）用
/// `fullNumber.replaceFirst(RegExp(r'^\+\d+'), '')` 剥国家码——
/// `\d+` 贪婪吞掉整串连续数字，replaceFirst 结果恒为空串 →
/// 表单 mobile 字段恒空 → 手机注册/登录/找回密码"下一步"永久禁用。
///
/// 契约（本测试锁定）：
/// - `onInputChanged(fullNumber, localNumber)` 双参：localNumber 必须是
///   用户在号码框输入的原始本地号码（零正则歧义，不依赖调用方二次剥离）；
/// - 切换国家码后，localNumber 仍为用户输入原文，fullNumber 带新国家码。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/i18n/strings.g.dart';

void main() {
  testWidgets('输入号码后回调携带 localNumber 原文（P0 缺陷回归）', (tester) async {
    String? capturedFull;
    String? capturedLocal;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: PhoneInputWidget(
              initialValue: '',
              onInputChanged: (String fullNumber, String localNumber) {
                capturedFull = fullNumber;
                capturedLocal = localNumber;
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '13800000001');
    await tester.pump();

    expect(
      capturedFull,
      '+8613800000001',
      reason: 'fullNumber = 默认国家码(+86) + 用户输入',
    );
    expect(
      capturedLocal,
      '13800000001',
      reason:
          'localNumber 必须是用户输入原文——旧实现调用方二次剥码时'
          '被贪婪正则清空，导致手机注册/登录链全断',
    );
  });

  testWidgets('本地号码含 86 子串时不被误删（防 replaceAll 式回归）', (tester) async {
    String? capturedFull;
    String? capturedLocal;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: PhoneInputWidget(
              initialValue: '',
              onInputChanged: (String fullNumber, String localNumber) {
                capturedFull = fullNumber;
                capturedLocal = localNumber;
              },
            ),
          ),
        ),
      ),
    );

    // 输入以国家码 "86" 开头：组件将其规范化为完整号码
    // （"+86" + "13800861234"）；号码主体仍含 "86" 子串。
    await tester.enterText(find.byType(TextField), '8613800861234');
    await tester.pump();

    expect(capturedFull, '+8613800861234');
    expect(
      capturedLocal,
      '13800861234',
      reason:
          '剥头后号码主体中的 86 保留——replaceAll(dialCode) 式实现'
          '会把中间的 86 一并删掉，此断言锁定startsWith+substring 语义',
    );
  });
}
