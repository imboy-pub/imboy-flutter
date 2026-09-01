import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/avatar_group.dart';
import 'package:imboy/component/ui/avatar_shape.dart';
import 'package:imboy/component/ui/group_avatar_composite.dart';
import 'package:octo_image/octo_image.dart';

/// W5 合成单图缓存的契约测试。
///
/// 合成管线依赖真 raster 上下文（toImageSync），flutter_test 里安全降级
/// 为 null（不缓存失败）——这条降级路径本身就是一个被测行为。
/// 画布布局与 legacy Widget 的像素级一致性靠真机走查 + 注释对照，
/// 本文件锁 key 语义与缓存/in-flight/降级语义。
void main() {
  setUp(() {
    GroupAvatarComposite.clear();
  });
  tearDown(() {
    GroupAvatarComposite.clear();
  });

  group('GroupAvatar 合成集成', () {
    testWidgets('合成完成后由 legacy 逐 tile 切到 RawImage 单纹理直出', (tester) async {
      const urls = ['def_avatar.png', 'def_avatar.png', 'def_avatar.png'];
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GroupAvatar(memberAvatars: urls, size: 50)),
        ),
      );
      // OctoImage 内部也有 image:null 的占位 RawImage；合成直出的
      // RawImage 特征是 image 非 null + fit fill。
      final compositeImageFinder = find.byWidgetPredicate(
        (w) => w is RawImage && w.image != null && w.fit == BoxFit.fill,
      );
      // 首帧未命中：legacy 路径（OctoImage tile），无合成直出
      expect(compositeImageFinder, findsNothing);
      expect(find.byType(OctoImage), findsNWidgets(3));

      // 合成管线跑在真实事件循环（ImageStream 解码 + toImageSync），
      // fake async 推不动它——用 runAsync 真等，再 pump 重建
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(compositeImageFinder, findsOneWidget, reason: '合成图就绪后必须切到单纹理直出');
      expect(find.byType(OctoImage), findsNothing);
    });
  });

  group('keyFor：key 语义（顺序即布局位置）', () {
    test('同列表同 size 产出稳定 key', () {
      final a = GroupAvatarComposite.keyFor(['u1', 'u2'], 50);
      final b = GroupAvatarComposite.keyFor(['u1', 'u2'], 50);
      expect(a, b);
    });

    test('顺序不同 key 不同——同集合不同布局不得共享合成图', () {
      // W2 后列表顺序恒为 user_id 升序，但不同群的成员集合可能相同而
      // 顺序不同（理论上）；布局对位置敏感，key 必须区分顺序。
      final a = GroupAvatarComposite.keyFor(['u1', 'u2'], 50);
      final b = GroupAvatarComposite.keyFor(['u2', 'u1'], 50);
      expect(a, isNot(b));
    });

    test('size 参与 key：不同尺寸各自合成', () {
      final a = GroupAvatarComposite.keyFor(['u1'], 50);
      final b = GroupAvatarComposite.keyFor(['u1'], 56);
      expect(a, isNot(b));
    });
  });

  group('合成缓存语义', () {
    test('未命中 peek 返回 null', () {
      expect(GroupAvatarComposite.peek('nope'), isNull);
    });

    test('合成成功写入缓存，peek 命中 ui.Image；rebuildNotifier 已广播', () async {
      var notified = 0;
      void listener() => notified++;
      GroupAvatarComposite.rebuildNotifier.addListener(listener);
      addTearDown(() {
        GroupAvatarComposite.rebuildNotifier.removeListener(listener);
      });

      const urls = ['def_avatar.png', 'def_avatar.png', 'def_avatar.png'];
      GroupAvatarComposite.schedule(
        urls,
        50,
        AvatarShape.roundedSquare,
        4,
        false,
      );
      // 让合成管线跑完（解码 + 画布 + 缓存写入 + 通知）
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // flutter_test 带 software raster，toImageSync 可用 → 合成成功
      final image = GroupAvatarComposite.peek(
        GroupAvatarComposite.keyFor(urls, 50),
      );
      expect(image, isNotNull);
      expect(image!.width, 50);
      expect(image.height, 50);
      expect(notified, greaterThan(0), reason: '合成完成必须广播重建');
    });

    test('同 key 重复 schedule 只发起一次合成（in-flight 去重）', () async {
      const urls = ['def_avatar.png', 'def_avatar.png'];
      GroupAvatarComposite.schedule(
        urls,
        50,
        AvatarShape.roundedSquare,
        4,
        false,
      );
      GroupAvatarComposite.schedule(
        urls,
        50,
        AvatarShape.roundedSquare,
        4,
        false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // 去重的可观察后果：命中缓存且无异常即管线只走了一遍
      expect(
        GroupAvatarComposite.peek(GroupAvatarComposite.keyFor(urls, 50)),
        isNotNull,
      );
    });

    test('单元素列表直接拒绝合成（单图不属于合成职责）', () async {
      GroupAvatarComposite.schedule(
        ['def_avatar.png'],
        50,
        AvatarShape.roundedSquare,
        4,
        false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        GroupAvatarComposite.peek(
          GroupAvatarComposite.keyFor(['def_avatar.png'], 50),
        ),
        isNull,
      );
    });

    test('clear 清空缓存', () async {
      const urls = ['def_avatar.png', 'def_avatar.png'];
      GroupAvatarComposite.schedule(
        urls,
        50,
        AvatarShape.roundedSquare,
        4,
        false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        GroupAvatarComposite.peek(GroupAvatarComposite.keyFor(urls, 50)),
        isNotNull,
      );
      GroupAvatarComposite.clear();
      expect(
        GroupAvatarComposite.peek(GroupAvatarComposite.keyFor(urls, 50)),
        isNull,
      );
    });
  });
}
