import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/channel_api.dart';

void main() {
  group('ChannelApi 游标归一化：假游标不得撑起「还有下一页」', () {
    test('null / 空串 / 空白 → 无下一页', () {
      expect(ChannelApi.normalizeCursor(null), isNull);
      expect(ChannelApi.normalizeCursor(''), isNull);
      expect(ChannelApi.normalizeCursor('   '), isNull);
    });

    // 后端 jsone 未开 undefined_as_null，Erlang atom undefined 会被编成
    // 字符串而非 JSON null —— 频道「已订阅」列表底部转圈不消失的真凶。
    test('Erlang atom 哨兵字符串 undefined / null → 无下一页', () {
      expect(ChannelApi.normalizeCursor('undefined'), isNull);
      expect(ChannelApi.normalizeCursor('null'), isNull);
    });

    test('真游标原样保留，数字转字符串', () {
      expect(ChannelApi.normalizeCursor('1699999999'), '1699999999');
      expect(ChannelApi.normalizeCursor(42), '42');
    });
  });
}
