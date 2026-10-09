// Owned Android entrypoint: no phone login, no business-response mocks.
// setUpAll establishes the real production session before the existing UI case.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'micro_community/owned_session.dart';
import 'micro_community_flow_test.dart' as journey;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(establishOwnedAndroidSession);
  journey.main();
}
