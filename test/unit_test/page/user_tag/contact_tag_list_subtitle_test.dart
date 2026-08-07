import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_provider.dart';
import 'package:imboy/store/model/user_tag_model.dart';

/// 回归：标签列表副标题不得在「有成员但拿不到预览」时谎报「暂无数据」。
///
/// 真机复现（批次27，标签 qa0804）：标题算出 (2)、详情页确有 2 名成员，
/// 副标题却是「暂无数据」。根因是两条数据源 —— `refererTime` 由服务端下发，
/// `subtitle` 却是本机进过详情页才写入的派生列，服务端 `user_tag/page` 从不返回。
UserTagModel _tag({String subtitle = '', int refererTime = 0}) => UserTagModel(
  userId: 50,
  tagId: 1,
  scene: 2,
  name: 'qa0804',
  subtitle: subtitle,
  refererTime: refererTime,
  updatedAt: 0,
  createdAt: 0,
);

void main() {
  group('ContactTagListNotifier.buildListSubtitle', () {
    test('有本地预览时原样显示', () {
      expect(
        ContactTagListNotifier.buildListSubtitle(
          _tag(subtitle: '张三, 李四', refererTime: 2),
          '暂无数据',
        ),
        '张三, 李四',
      );
    });

    // 这条就是 bug 本身：修前返回「暂无数据」，与标题的 (2) 自相矛盾。
    test('有成员但无本地预览时不渲染副标题', () {
      expect(
        ContactTagListNotifier.buildListSubtitle(_tag(refererTime: 2), '暂无数据'),
        isNull,
      );
    });

    test('确实零成员时才显示空态文案', () {
      expect(ContactTagListNotifier.buildListSubtitle(_tag(), '暂无数据'), '暂无数据');
    });
  });
}
