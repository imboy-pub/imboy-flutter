/// 钉住 `shouldNotifyGroupMessage` 的决策契约 —— slice-5 (C6) RED-18。
///
/// 纯客户端行为（后端零改动）：用户对某群设置"消息免打扰"后，该群新消息
/// 不触发本地通知（不响铃、不震动、不弹横幅），但消息正常收进 Repo、
/// 未读数正常累加、会话列表仍可见。
///
/// 契约（优先级从高到低）：
///   1. `fromSelf == true` → 永不通知（自己发的不提醒自己）
///   2. `noticeDisabled == true` 且 `isMentioned == false` → 不通知
///   3. `noticeDisabled == true` 且 `isMentioned == true` → **仍通知**
///      （免打扰不屏蔽定向 @ 呼叫，行业共识：微信、Telegram、Slack 均如此）
///   4. 其余 → 通知
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_notice_rules.dart';

void main() {
  group('shouldNotifyGroupMessage — 决策契约', () {
    test('默认场景（未开免打扰、非自己、未被@）→ 通知', () {
      expect(
        shouldNotifyGroupMessage(
          noticeDisabled: false,
          fromSelf: false,
          isMentioned: false,
        ),
        isTrue,
      );
    });

    test('fromSelf=true → 永不通知（哪怕免打扰关闭 + 被@）', () {
      expect(
        shouldNotifyGroupMessage(
          noticeDisabled: false,
          fromSelf: true,
          isMentioned: true,
        ),
        isFalse,
        reason: '自己发的消息不提醒自己，优先级高于 @ 定向',
      );
    });

    test('noticeDisabled=true + 非@ → 不通知', () {
      expect(
        shouldNotifyGroupMessage(
          noticeDisabled: true,
          fromSelf: false,
          isMentioned: false,
        ),
        isFalse,
      );
    });

    test('noticeDisabled=true + 被@自己 → 仍通知（定向呼叫穿透免打扰）', () {
      expect(
        shouldNotifyGroupMessage(
          noticeDisabled: true,
          fromSelf: false,
          isMentioned: true,
        ),
        isTrue,
        reason: '免打扰不屏蔽 @ 定向，对齐微信/TG/Slack 行业共识',
      );
    });

    test('noticeDisabled=false + 被@自己 → 通知', () {
      expect(
        shouldNotifyGroupMessage(
          noticeDisabled: false,
          fromSelf: false,
          isMentioned: true,
        ),
        isTrue,
      );
    });

    test('fromSelf 优先级高于 noticeDisabled', () {
      // 即便免打扰开启，自己发也不额外触发
      expect(
        shouldNotifyGroupMessage(
          noticeDisabled: true,
          fromSelf: true,
          isMentioned: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldNotifyGroupMessage — 真值表穷尽（8 组合）', () {
    // 真值表：noticeDisabled × fromSelf × isMentioned → expected
    // fromSelf=true 永远 false（2^2 = 4 组均假）
    // fromSelf=false 时：noticeDisabled=false → true（2 组）
    //                   noticeDisabled=true + isMentioned=true → true
    //                   noticeDisabled=true + isMentioned=false → false
    const cases = <(bool, bool, bool, bool)>[
      // (noticeDisabled, fromSelf, isMentioned, expected)
      (false, false, false, true),
      (false, false, true, true),
      (false, true, false, false),
      (false, true, true, false),
      (true, false, false, false),
      (true, false, true, true),
      (true, true, false, false),
      (true, true, true, false),
    ];

    for (final (nd, fs, mention, expected) in cases) {
      test(
        'nd=$nd fromSelf=$fs mention=$mention → $expected',
        () {
          expect(
            shouldNotifyGroupMessage(
              noticeDisabled: nd,
              fromSelf: fs,
              isMentioned: mention,
            ),
            expected,
          );
        },
      );
    }
  });
}
