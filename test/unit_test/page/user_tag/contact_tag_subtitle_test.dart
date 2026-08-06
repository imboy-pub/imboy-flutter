import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_provider.dart';
import 'package:imboy/store/model/contact_model.dart';

/// BUG#74 回归：标签列表副标题读 `user_tag.subtitle` 列，而成员增删只写了
/// refererTime，导致同一行「(1)」与「暂无数据」自相矛盾。
///
/// 这里钉住副标题的构造规则，成员名取 `ContactModel.title`（remark > nickname > account）。
void main() {
  group('ContactTagDetailNotifier.buildTagSubtitle', () {
    test('多个成员用「, 」拼接', () {
      final subtitle = ContactTagDetailNotifier.buildTagSubtitle([
        ContactModel(peerId: 1, nickname: 'IMBoy'),
        ContactModel(peerId: 2, nickname: 'leeyi'),
      ]);
      expect(subtitle, 'IMBoy, leeyi');
    });

    test('备注优先于昵称（对齐 ContactModel.title 规则）', () {
      final subtitle = ContactTagDetailNotifier.buildTagSubtitle([
        ContactModel(peerId: 1, nickname: '昵称', remark: 'automation-buddy'),
      ]);
      expect(subtitle, 'automation-buddy');
    });

    test('昵称为空时回退到账号', () {
      final subtitle = ContactTagDetailNotifier.buildTagSubtitle([
        ContactModel(peerId: 1, nickname: '', account: '19999990001'),
      ]);
      expect(subtitle, '19999990001');
    });

    test('空列表返回空串 —— 列表页据此回退「暂无数据」', () {
      expect(ContactTagDetailNotifier.buildTagSubtitle([]), '');
    });

    test('名字全空的成员被跳过，不产生「, , 」这种空洞', () {
      final subtitle = ContactTagDetailNotifier.buildTagSubtitle([
        ContactModel(peerId: 1, nickname: 'IMBoy'),
        ContactModel(peerId: 2, nickname: '', account: ''),
        ContactModel(peerId: 3, nickname: 'leeyi'),
      ]);
      expect(subtitle, 'IMBoy, leeyi');
    });
  });
}
