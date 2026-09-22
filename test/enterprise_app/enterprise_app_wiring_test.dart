/// FULL-05 — 接线证据测试（plan §3.3「会话/详情/通知/搜索/历史一致」）。
///
/// 与 GZ 期 `oa_tab_navigation_registration_test.dart` 同款手法：对真实共享
/// 文件做**源码断言**，证明企业托管消息的来源判定确实接进了真实渲染/投递
/// 路径，而不是只在模块内自测。
///
/// 断言的是「接线存在且共用同一判定入口」这一结构事实，不复制实现细节。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String relativePath) =>
    File('${Directory.current.path}/$relativePath').readAsStringSync();

void main() {
  group('会话气泡（聊天页渲染链）', () {
    const String path = 'lib/component/chat/message.dart';

    test('气泡构建器调用企业来源装饰', () {
      final String src = read(path);
      expect(
        src.contains('HostedMessageBubbleDecoration.decorate('),
        isTrue,
        reason: '会话气泡必须接企业托管来源装饰',
      );
      expect(
        src.contains(
          "import 'package:imboy/modules/enterprise_app/public.dart'",
        ),
        isTrue,
      );
      expect(src.contains('metadata: message.metadata'), isTrue);
    });

    test('装饰以 return 收口（try 与 catch 两条路径都覆盖）', () {
      final String src = read(path);
      expect(
        src.contains('return HostedMessageBubbleDecoration.decorate('),
        isTrue,
        reason: '必须作为唯一返回点，否则 fallback 分支会漏掉装饰',
      );
    });
  });

  group('搜索面', () {
    const String path = 'lib/page/search/message_search_page.dart';

    test('搜索结果渲染调用同一判定入口', () {
      final String src = read(path);
      expect(src.contains('resolveHostedMessageFacts('), isTrue);
      expect(src.contains('HostedMessageFactsRow('), isTrue);
      expect(
        src.contains(
          "import 'package:imboy/modules/enterprise_app/public.dart'",
        ),
        isTrue,
      );
    });
  });

  group('通知面（本地通知文案）', () {
    const String path = 'lib/service/message.dart';

    test('本地消息通知的标题拼接企业来源前缀', () {
      final String src = read(path);
      expect(src.contains('hostedMessageNotificationPrefix('), isTrue);
      expect(src.contains("senderName: '\$hostedPrefix\$senderName'"), isTrue);
    });
  });

  group('唯一判定入口（不允许第二份实现）', () {
    test('全仓只有 enterprise_message_origin.dart 定义来源分类枚举', () {
      final List<String> declarations = <String>[];
      for (final FileSystemEntity e in Directory(
        '${Directory.current.path}/lib',
      ).listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final String src = e.readAsStringSync();
        if (src.contains('enum HostedMessageClass')) declarations.add(e.path);
      }
      expect(declarations.length, 1, reason: '判定入口必须唯一：$declarations');
      expect(declarations.single, endsWith('enterprise_message_origin.dart'));
    });

    test('业务面只经 public.dart 引入企业应用模块（模块边界约定）', () {
      final List<String> offenders = <String>[];
      for (final FileSystemEntity e in Directory(
        '${Directory.current.path}/lib',
      ).listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (e.path.contains('/modules/enterprise_app/')) continue;
        final String src = e.readAsStringSync();
        if (src.contains("package:imboy/modules/enterprise_app/domain/") ||
            src.contains(
              "package:imboy/modules/enterprise_app/presentation/",
            ) ||
            src.contains(
              "package:imboy/modules/enterprise_app/infrastructure/",
            )) {
          offenders.add(e.path);
        }
      }
      expect(offenders, isEmpty, reason: '越界直连模块内部路径：$offenders');
    });
  });

  group('Human-Human E2EE 路径零改动（INV-6 的接线侧保障）', () {
    test('聊天渲染链不自行解释来源（无第二份判定）', () {
      final String src = read('lib/component/chat/message.dart');
      // 装饰只做「调用 + 透传 metadata」；分类逻辑必须留在 enterprise_app 内。
      expect(src.contains('HostedMessageBubbleDecoration.decorate('), isTrue);
      expect(
        src.contains('HostedMessageClass'),
        isFalse,
        reason: '渲染层不得二次解释来源分类',
      );
      expect(
        src.contains("metadata?['origin']") || src.contains('["origin"]'),
        isFalse,
        reason: '渲染层不得自行解析 origin 字段',
      );
    });

    test('装饰函数对普通消息返回原 child（源码级早退守卫）', () {
      final String src = read(
        'lib/modules/enterprise_app/presentation/hosted_message_facts.dart',
      );
      expect(
        src.contains(
          'if (!facts.showsDelegationBadge && !facts.needsOriginWarning) {',
        ),
        isTrue,
        reason: '必须有「普通消息原样返回」的早退分支',
      );
      expect(src.contains('return child;'), isTrue);
    });

    test('e2ee 解密/告警链路未出现在企业应用模块中', () {
      final List<String> hits = <String>[];
      for (final FileSystemEntity e in Directory(
        '${Directory.current.path}/lib/modules/enterprise_app',
      ).listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final String src = e.readAsStringSync();
        if (RegExp(r'\bdecrypt|E2EEService|vodozemac\b').hasMatch(src)) {
          hits.add(e.path);
        }
      }
      expect(hits, isEmpty, reason: '企业模块不得触碰解密实现（只读事实）：$hits');
    });
  });
}
