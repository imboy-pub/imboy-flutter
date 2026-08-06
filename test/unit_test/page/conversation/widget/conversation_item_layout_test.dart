/// 会话行的几何契约（DESIGN.md 8.3 A / 6.4）。
///
/// 起因是一处真实的视觉错位：头像后间距写的 14pt，而 conversation_page 的
/// 分隔线按 16(页面 padding) + 56(头像) + 12 = 84 起画——文字左缘和分隔线
/// 差了 2pt。单看代码不容易发现，因为这两个数字分散在两个文件里。
///
/// 这里把"分隔线起点必须等于文字左缘"钉成可执行断言，改任一边都会报警。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// conversation_page 里分隔线的左缩进，改这里必须同步改那边。
const double kSeparatorIndent = 84;
const double kAvatarSize = 56;

ConversationModel _model() => ConversationModel(
  id: 1,
  peerId: 1001,
  type: 'C2C',
  msgType: 'text',
  title: '张三',
  subtitle: '晚点聊',
  avatar: '',
  sign: '',
  lastTime: 0,
  unreadNum: 0,
);

void main() {
  _titleFallbackTests();
  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ConversationItem(model: _model(), onTapAvatar: null),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('文字左缘正好落在分隔线起点上', (tester) async {
    await pump(tester);

    final titleLeft = tester.getTopLeft(find.text('张三')).dx;
    expect(
      titleLeft,
      moreOrLessEquals(kSeparatorIndent, epsilon: 0.5),
      reason:
          '标题左缘 $titleLeft 与分隔线起点 $kSeparatorIndent 不齐——'
          '视觉上分隔线会比文字左边多出/少掉一截',
    );
  });

  testWidgets('几何来源可追溯：页面 padding + 头像 + 头像后间距 == 分隔线缩进', (tester) async {
    // 不是把 84 抄两遍，而是断言它由三个 token 推导出来。
    // 任何一项改了而另一处没跟上，这条就红。
    expect(
      AppSpacing.regular + kAvatarSize + AppSpacing.medium,
      kSeparatorIndent,
    );
  });

  testWidgets('按压反馈时长用规范值（DESIGN.md 6.4：100ms）', (tester) async {
    await pump(tester);

    final animated = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byType(ConversationItem),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      animated.duration,
      AppDuration.buttonPress,
      reason: '按压高亮时长偏离规范，列表点击手感会和其他页面不一致',
    );
  });

  testWidgets('不画 disclosure chevron', (tester) async {
    await pump(tester);

    // 整行都可点，箭头传达不了额外信息，只占宽度。
    // 微信 / Telegram / iMessage 的会话列表都没有这个箭头。
    expect(
      find.descendant(
        of: find.byType(ConversationItem),
        matching: find.byIcon(CupertinoIcons.chevron_right),
      ),
      findsNothing,
    );
  });

  testWidgets('按下不触发触感反馈', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester);
    await tester.press(find.text('张三'));
    await tester.pump();

    // iOS 系统列表按下不给触感，只有切换/选择类操作才给。
    // 每点一个会话都震一下，在高频列表里是噪音。
    expect(
      calls.where((c) => c.method == 'HapticFeedback.vibrate'),
      isEmpty,
      reason: '会话行按下触发了触感反馈',
    );
  });
}

/// BUG#4 家族：标题缺失时**绝不**回退到内部 ID。
///
/// 真机实测（批次 12/13）：群会话在消息列表里标题渲染成
/// `104603643803863040`，140% 字号下被截断成 `10460364380380…`——
/// 一串对用户毫无意义的数字，两个不同的群还长得一样。
///
/// §十七 给 GroupModel.displayTitle 定过同一条约定，这里把它钉到会话行上。
/// 反向验证过：把末档改回 `peerId.toString()` → 本用例立刻红。
void _titleFallbackTests() {
  ConversationModel namelessGroup() => ConversationModel(
    id: 2,
    peerId: 104603643803863040,
    type: 'C2G',
    msgType: 'text',
    title: '', // 无名群：服务端与本地都没有可用群名
    subtitle: 'hi',
    avatar: '',
    sign: '',
    lastTime: 0,
    unreadNum: 0,
  );

  testWidgets('标题为空的群会话显示「未命名」，不显示 gid', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ConversationItem(model: namelessGroup(), onTapAvatar: null),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('104603643803863040'),
      findsNothing,
      reason: '内部 TSID 不允许出现在会话列表标题上',
    );
    expect(find.text(t.main.unnamed), findsOneWidget);
  });

  testWidgets('存量脏值：title 里存的就是 gid，也必须显示「未命名」', (WidgetTester tester) async {
    // 修复前 _getGroupTitle 缺名时 return peerId，并被持久化进 title。
    // 这类值"非空"，纯兜底链救不回来——读时必须显式判定为缺失。
    final dirty = ConversationModel(
      id: 3,
      peerId: 104603643803863040,
      type: 'C2G',
      msgType: 'text',
      title: '104603643803863040',
      subtitle: 'hi',
      avatar: '',
      sign: '',
      lastTime: 0,
      unreadNum: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ConversationItem(model: dirty, onTapAvatar: null),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('104603643803863040'), findsNothing);
    expect(find.text(t.main.unnamed), findsOneWidget);
  });
}
