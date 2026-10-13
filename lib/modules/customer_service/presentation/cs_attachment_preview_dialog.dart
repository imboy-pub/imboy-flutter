import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

import 'cs_attachment_save.dart';

class CsAttachmentPreviewDialog extends StatefulWidget {
  const CsAttachmentPreviewDialog({
    super.key,
    required this.asset,
    required this.translations,
    required this.content,
    required this.isCurrent,
    required this.close,
    required this.save,
  });
  final CsMessageAsset asset;
  final Translations translations;
  final CsVerifiedAssetContent content;
  final bool Function() isCurrent;
  final VoidCallback close;
  final CsAttachmentSave save;
  @override
  State<CsAttachmentPreviewDialog> createState() =>
      _CsAttachmentPreviewDialogState();
}

class _CsAttachmentPreviewDialogState extends State<CsAttachmentPreviewDialog> {
  bool _saving = false;
  late final String? _text = _decodeText();
  bool _textTruncated = false;
  CsAttachmentSaveResult? _result;
  String get _mime => widget.asset.mime.split(';').first.trim().toLowerCase();
  bool get _mimeMatches =>
      _mime == widget.content.mime.split(';').first.trim().toLowerCase();
  @override
  void dispose() {
    unawaited(MemoryImage(widget.content.bytes).evict().then<void>((_) {}));
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !widget.isCurrent()) return;
    setState(() {
      _saving = true;
      _result = null;
    });
    final result = await widget.save.save(
      content: widget.content,
      fileName: widget.asset.fileName,
      isCurrent: () => mounted && widget.isCurrent(),
    );
    if (!mounted || !widget.isCurrent()) return;
    setState(() {
      _saving = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) return const SizedBox.shrink();
    final t = widget.translations.customerService;
    return AlertDialog(
      title: Text(csSafeAttachmentName(widget.asset.fileName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _preview(t.attachBinaryNoPreview)),
          if (_result == CsAttachmentSaveResult.saved) Text(t.attachSaved),
          if (_result == CsAttachmentSaveResult.failed)
            Text(t.attachSaveFailed),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('cs-save-attachment'),
          onPressed: _saving ? null : _save,
          child: Text(t.attachSave),
        ),
        TextButton(
          onPressed: widget.close,
          child: Text(widget.translations.common.buttonOk),
        ),
      ],
    );
  }

  Widget _preview(String fallback) {
    if (_mimeMatches && _mime.startsWith('image/')) {
      return InteractiveViewer(
        maxScale: 4,
        child: Image.memory(
          widget.content.bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Text(fallback),
        ),
      );
    }
    if (_mimeMatches && _mime.startsWith('text/') && _text != null) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_text),
            if (_textTruncated)
              Text(widget.translations.customerService.attachPreviewTruncated),
          ],
        ),
      );
    }
    return Text(fallback);
  }

  String? _decodeText() {
    if (!_mimeMatches || !_mime.startsWith('text/')) return null;
    try {
      final text = utf8
          .decode(widget.content.bytes)
          .replaceAll(RegExp(r'[\x00-\x08\x0e-\x1f]'), '');
      if (text.isEmpty) return null;
      final runes = text.runes.take(5001).toList();
      _textTruncated = runes.length > 5000;
      return String.fromCharCodes(runes.take(5000));
    } on FormatException {
      return null;
    }
  }
}
