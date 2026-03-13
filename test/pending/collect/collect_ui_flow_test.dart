import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/user_collect/user_collect_page.dart';

void main() {
  group('collect ui flow contract', () {
    test('default constructor keeps non-select mode', () {
      const page = UserCollectPage();

      expect(page.isSelect, isFalse);
      expect(page.peer, isEmpty);
    });

    test('select constructor preserves peer payload', () {
      const page = UserCollectPage(
        isSelect: true,
        peer: {'peer_id': 'u_1001', 'peer_name': 'Alice'},
      );

      expect(page.isSelect, isTrue);
      expect(page.peer['peer_id'], 'u_1001');
      expect(page.peer['peer_name'], 'Alice');
    });
  });
}
