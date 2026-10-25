// Android runs the shared native directory journey; desktop inputs remain waived.
import 'dart:io';

import 'organization_chart_nonoa_macos_test.dart' as journey;

void main() {
  if (!Platform.isAndroid) throw StateError('physical Android entry required');
  journey.main();
}
