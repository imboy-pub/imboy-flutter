import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

import 'cs_attachment_preview_dialog.dart';
import 'cs_attachment_save.dart';

/// Owns only attachment preview routes for one seat-page binding.
class CsSessionPreviewScope {
  CsSessionPreviewScope({CsAttachmentSave? save})
    : _save = save ?? CsAttachmentSave();
  final CsAttachmentSave _save;
  final Set<DialogRoute<void>> _routes = {};
  int _generation = 0;
  bool _disposed = false;

  Future<void> show({
    required BuildContext context,
    required CsMessageAsset asset,
    required Future<CsVerifiedAssetContent?> Function() loadContent,
    required bool Function() isCurrent,
  }) async {
    final generation = _generation;
    bool allowed() => !_disposed && generation == _generation && isCurrent();
    if (!context.mounted || !allowed()) return;
    final translations = context.t;
    final content = await loadContent();
    if (content == null ||
        content.assetId != asset.id ||
        !context.mounted ||
        !allowed()) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    late DialogRoute<void> route;
    route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => allowed()
          ? CsAttachmentPreviewDialog(
              translations: translations,
              asset: asset,
              content: content,
              isCurrent: allowed,
              close: () => _remove([route]),
              save: _save,
            )
          : const SizedBox.shrink(),
    );
    if (!navigator.mounted || !allowed()) return;
    _routes.add(route);
    try {
      await navigator.push(route);
    } finally {
      _routes.remove(route);
    }
  }

  void invalidate() {
    _generation++;
    final old = _routes.toList();
    _remove(old);
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }

  void _remove(List<DialogRoute<void>> routes) {
    if (routes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        final navigator = route.navigator;
        if (route.isActive && navigator != null && navigator.mounted) {
          navigator.removeRoute(route);
        }
        _routes.remove(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
