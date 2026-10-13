/// Real HTTP probe and real native Page journey are separate assertions.
/// Mandatory CS_E2E_* run admission is defined in cs_integration_fixture.dart.
/// No automatic fixture selection, adapter mocks, synthetic device ID or skips.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'cs_integration_fixture.dart';
import 'cs_integration_runtime.dart';
import 'cs_workbench_probe.dart';
import 'cs_workbench_page_journey.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'owned real HTTP contract probe and actual Native workbench journey',
    (tester) async {
      final fixture = CsIntegrationFixture.fromBuild();
      final runtime = CsIntegrationRuntime(fixture);
      final probe = CsWorkbenchProbe(runtime);
      try {
        await runtime.initialize();
        await probe.run();
        await CsWorkbenchPageJourney(tester, runtime).run();
      } on CsIntegrationAdmissionRefused {
        rethrow;
      } on Object {
        // Never stringify transport errors, headers, body or native paths.
        fail('CS_REAL_WORKBENCH_GATE_FAILED');
      } finally {
        probe.dispose();
        runtime.restoreEnvironment();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
