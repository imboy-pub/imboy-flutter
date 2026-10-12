import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Owns only attachment preview routes for one seat-page binding.
class CsSessionPreviewScope {
  final Set<DialogRoute<void>> _routes = {};
  int _generation = 0;
  bool _disposed = false;

  Future<void> show({
    required BuildContext context,
    required CsMessageAsset asset,
    required Future<Uint8List?> Function() loadBytes,
    required bool Function() isCurrent,
  }) async {
    final generation = _generation;
    bool allowed() => !_disposed && generation == _generation && isCurrent();
    if (!context.mounted || !allowed()) return;
    final bytes = await loadBytes();
    if (bytes == null || !context.mounted || !allowed()) return;
    final t = context.t.customerService;
    final ok = context.t.common.buttonOk;
    final title = asset.fileName.isNotEmpty
        ? asset.fileName
        : t.attachPreviewTitle;
    final fallback = t.attachBinaryNoPreview;
    final navigator = Navigator.of(context, rootNavigator: true);
    late DialogRoute<void> route;
    route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => allowed()
          ? _content(asset, bytes, title, fallback, ok, () => _remove([route]))
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

  Widget _content(
    CsMessageAsset asset,
    Uint8List bytes,
    String title,
    String fallback,
    String ok,
    VoidCallback close,
  ) {
    return AlertDialog(
      title: Text(title),
      content: asset.isImage
          ? InteractiveViewer(
              maxScale: 4,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Text(fallback),
                ),
              ),
            )
          : SingleChildScrollView(child: Text(_text(bytes, fallback))),
      actions: [TextButton(onPressed: close, child: Text(ok))],
    );
  }

  String _text(Uint8List bytes, String fallback) {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll(RegExp(r'[\x00-\x08\x0E-\x1F]'), '');
    return text.isEmpty ? fallback : text;
  }
}
