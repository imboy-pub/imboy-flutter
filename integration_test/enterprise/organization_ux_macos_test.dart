import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/organization/human_directory_page_widget_test.dart'
    as directory;
import '../../test/organization/organization_departments_page_widget_test.dart'
    as departments;

import '../../test/ux_matrix/ux_harness.dart'
    show initUxHarness, teardownUxHarness;

/// Exercise production directory and department widgets in the macOS engine.
/// Existing synthetic data adapters isolate this UI contract from backend auth.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUp(() => expect(Platform.isMacOS, isTrue));
  group('macOS directory', () {
    setUp(initUxHarness);
    tearDown(teardownUxHarness);
    directory.main(realTime: true);
  });
  group('macOS departments', departments.main);
}
