import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_provider.dart';
import 'package:imboy/store/model/user_tag_model.dart';

/// 发布后真机实测：新建标签点「完成」，页面正常关闭、数据也真落库了，
/// 但列表纹丝不动，退出重进才看得到 `postdeploy0804`。
///
/// 根因不是漏调刷新 —— `user_tag_save_page` 确实调了
/// `contactTagListProvider.notifier.updateTag(newTag)`，且注释写着「添加到列表」。
/// 是 `updateTag` 只有「已存在则替换」那一支，`indexWhere` 返回 -1 时静默返回，
/// 而新建标签的 tagId 在列表里必然不存在。静默失败藏在名实不符里。
UserTagModel _tag(int tagId, String name) => UserTagModel(
  userId: 1,
  tagId: tagId,
  scene: 2,
  name: name,
  subtitle: '',
  refererTime: 0,
  updatedAt: 0,
  createdAt: 0,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  ContactTagListNotifier notifier() =>
      container.read(contactTagListProvider.notifier);

  List<UserTagModel> items() => container.read(contactTagListProvider).items;

  group('updateTag 是 upsert，不是纯 update', () {
    test('列表里不存在的标签会被追加，而不是被静默丢弃', () {
      notifier().updateTag(_tag(101, 'qa0804'));
      notifier().updateTag(_tag(202, 'postdeploy0804'));

      expect(items().map((e) => e.name).toList(), [
        'qa0804',
        'postdeploy0804',
      ], reason: '新建标签必须立即出现在列表里，不该等退出重进');
    });

    test('追加到尾部，与服务端 page() 的返回顺序一致', () {
      notifier().updateTag(_tag(101, 'qa0804'));
      notifier().updateTag(_tag(202, 'postdeploy0804'));

      expect(items().last.name, 'postdeploy0804');
    });

    test('已存在的标签走替换，不会重复插入一条', () {
      notifier().updateTag(_tag(101, '旧名'));
      notifier().updateTag(_tag(101, '新名'));

      expect(items().length, 1);
      expect(items().single.name, '新名');
    });

    test('null 直接忽略，不产生空洞条目', () {
      notifier().updateTag(_tag(101, 'qa0804'));
      notifier().updateTag(null);

      expect(items().length, 1);
    });
  });
}
