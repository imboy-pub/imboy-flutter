import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/unit_test/page/workspace/workspace_channel_detail_page_test.dart'
    as channel;

/// Production navigation in the native engine; synthetic group data only.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => expect(Platform.isMacOS, isTrue));
  channel.main();
}
