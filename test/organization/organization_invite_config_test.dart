import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/routing/organization_invite_link.dart';
import 'package:imboy/config/const.dart' show webBaseUrl;

void main() {
  test(
    'configured share origin is accepted and other deployments stay external',
    () {
      final base = Uri.parse(webBaseUrl);
      final link = organizationInviteUrl('ABCD2345');
      expect(Uri.parse(link).origin, base.origin);
      expect(organizationInviteCode(link), 'ABCD2345');
      if (!{'imboy.pub', 'www.imboy.pub'}.contains(base.host)) {
        expect(
          organizationInviteCode('https://imboy.pub/invite/org/ABCD2345'),
          isNull,
        );
      }
      expect(
        organizationInviteCode(
          'https://other-deployment.test/invite/org/ABCD2345',
        ),
        isNull,
      );
    },
  );
}
