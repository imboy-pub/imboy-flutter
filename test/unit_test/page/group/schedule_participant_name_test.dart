import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/schedule/group_schedule_detail_page.dart';

/// 真机实测：群日程详情的参与人一栏显示成「50」——那是 uid。
/// 后端 `list_participants` 的 SELECT 里根本没有昵称列，
/// 原实现「nickname 空就显示 user_id」于是每一行都退化成内部 ID。
void main() {
  group('resolveParticipantName', () {
    const names = {'50': '张三', '77': ''};

    test('后端给了昵称就用后端的', () {
      final v = resolveParticipantName({
        'user_id': '50',
        'nickname': '服务端昵称',
      }, names);
      expect(v, '服务端昵称');
    });

    test('后端没给昵称时用本地群成员表的名字', () {
      final v = resolveParticipantName({'user_id': '50'}, names);
      expect(v, '张三');
    });

    test('本地也查不到时给占位名，绝不显示 uid', () {
      final v = resolveParticipantName({'user_id': '999'}, names);
      expect(v, t.main.unnamed);
      expect(v, isNot(contains('999')));
    });

    test('本地记录存在但名字是空串，同样不回退成 uid', () {
      final v = resolveParticipantName({'user_id': '77'}, names);
      expect(v, t.main.unnamed);
    });
  });
}
