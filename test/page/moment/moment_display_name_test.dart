import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 9: display-name priority must be `remark > nickname > uid`,
/// matching ContactModel.title() rules. If all three are empty, fall back to
/// a visible placeholder '?' so avatar initials never crash on substring(0,1).
void main() {
  group('resolveMomentDisplayName', () {
    test('remark wins when all three present', () {
      final name = resolveMomentDisplayName(
        remark: '老王',
        nickname: 'Wang Hao',
        uid: 'u_123',
      );
      expect(name, '老王');
    });

    test('nickname wins when remark is empty', () {
      final name = resolveMomentDisplayName(
        remark: '',
        nickname: 'Wang Hao',
        uid: 'u_123',
      );
      expect(name, 'Wang Hao');
    });

    test('uid wins when remark and nickname are empty', () {
      final name = resolveMomentDisplayName(
        remark: '',
        nickname: '',
        uid: 'u_123',
      );
      expect(name, 'u_123');
    });

    test('returns placeholder "?" when all three empty', () {
      final name = resolveMomentDisplayName(
        remark: '',
        nickname: '',
        uid: '',
      );
      expect(name, '?');
    });

    test('whitespace-only strings count as empty and fall through', () {
      final name = resolveMomentDisplayName(
        remark: '   ',
        nickname: 'Wang Hao',
        uid: 'u_123',
      );
      expect(name, 'Wang Hao');
    });
  });
}
