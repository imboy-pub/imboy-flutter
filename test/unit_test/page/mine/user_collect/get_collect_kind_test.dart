/// getCollectKind 对多图（imageMulti）的类型判定
///
/// imageMulti 是 CustomMessage（metadata.msg_type = imageMulti），收藏种类应
/// 与单图一致为 2（图片）；既有 voice/video/location/visitCard 映射不变。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/user_collect/user_collect_provider.dart';

CustomMessage _custom(
  String msgType, [
  Map<String, dynamic> extra = const {},
]) => CustomMessage(
  id: 'm',
  authorId: 'u',
  createdAt: DateTime.utc(2026, 10, 23),
  metadata: {'msg_type': msgType, ...extra},
);

void main() {
  test('imageMulti → 2（图片）', () {
    final msg = _custom('imageMulti', {
      'images': [
        {'uri': 'a'},
        {'uri': 'b'},
      ],
      'total': 2,
    });
    expect(UserCollectNotifier.getCollectKind(msg), 2);
  });

  test('既有 CustomMessage 映射不变', () {
    expect(UserCollectNotifier.getCollectKind(_custom('voice')), 3);
    expect(UserCollectNotifier.getCollectKind(_custom('video')), 4);
    expect(UserCollectNotifier.getCollectKind(_custom('location')), 6);
    expect(UserCollectNotifier.getCollectKind(_custom('visitCard')), 7);
  });

  test('ImageMessage → 2，TextMessage → 1，null → 0', () {
    expect(
      UserCollectNotifier.getCollectKind(
        ImageMessage(
          id: 'i',
          authorId: 'u',
          createdAt: DateTime.utc(2026),
          source: 'k',
        ),
      ),
      2,
    );
    expect(
      UserCollectNotifier.getCollectKind(
        TextMessage(
          id: 't',
          authorId: 'u',
          createdAt: DateTime.utc(2026),
          text: 'hi',
        ),
      ),
      1,
    );
    expect(UserCollectNotifier.getCollectKind(null), 0);
  });
}
