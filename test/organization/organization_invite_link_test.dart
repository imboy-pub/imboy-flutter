import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/routing/organization_invite_link.dart';

void main() {
  test('share link round trips to native confirmation', () {
    final url = organizationInviteUrl('abcd2345');
    expect(url, 'https://imboy.pub/invite/org/ABCD2345');
    expect(
      organizationInviteLocation(url),
      '/organization/picker?autoJoin=1&code=ABCD2345',
    );
    expect(
      organizationInviteCode('https://www.imboy.pub/invite/org/ABCD2345'),
      'ABCD2345',
    );
    expect(organizationInviteCode('imboy://org/join?c=ABCD2345'), 'ABCD2345');
  });
  test('reject untrusted origins, ambiguous codes and malformed paths', () {
    for (final url in [
      'https://evil.test/invite/org/ABCD2345',
      'https://imboy.pub.evil.test/invite/org/ABCD2345',
      'https://imboy.pub@evil.test/invite/org/ABCD2345',
      'https://user@imboy.pub/invite/org/ABCD2345',
      'https://imboy.pub:444/invite/org/ABCD2345',
      'http://imboy.pub/invite/org/ABCD2345',
      'https://imboy.pub/invite/org/ABCD2345/extra',
      'https://imboy.pub/invite/org/ABCD2345?code=ZZZZ9999',
      'https://imboy.pub/invite/org/ABCD2345#extra',
      'https://imboy.pub/invite/org/ABCD0123',
      'imboy://org/join?c=ABCD2345&code=ZZZZ9999',
      'imboy://org/join?c=ABCD2345&c=ZZZZ9999',
      'https://evil.test/?next=imboy://org/join?c=ABCD2345',
      'imboy://org/join/extra?c=ABCD2345',
      'imboy://org/join?c=%FF',
      'https://imboy.pub/invite/org/%FF',
    ]) {
      expect(organizationInviteLocation(url), isNull, reason: url);
    }
  });
}
