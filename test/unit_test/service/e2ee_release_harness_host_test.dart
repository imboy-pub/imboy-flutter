/// Host-only entrypoint for the C11 harness self-tests.
///
/// This uses flutter_tester, an in-memory transport and synthetic identities.
/// It does not qualify AC-22/AC-23 or start a real backend/device journey.
library;

import '../../../integration_test/e2ee_release/harness_smoke_test.dart'
    as release_harness;

void main() => release_harness.main();
