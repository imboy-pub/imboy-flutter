import 'package:flutter_test/flutter_test.dart' show Finder, find;
import 'package:material_ui/material_ui.dart' as material show Tooltip;

/// Matches standalone Material tooltips even when their semantics are excluded.
/// `find.byTooltip` only checks the SDK Tooltip type in that case.
Finder findMaterialTooltip(String message, {bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) => widget is material.Tooltip && widget.message == message,
    description: 'material_ui Tooltip with message "$message"',
    skipOffstage: skipOffstage,
  );
}
