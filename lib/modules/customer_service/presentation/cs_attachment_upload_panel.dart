import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class CsAttachmentUploadPanel extends StatelessWidget {
  const CsAttachmentUploadPanel({
    super.key,
    required this.operation,
    this.onCancel,
    this.messageUnconfirmed = false,
    this.onRetry,
  });
  final CsAssetUploadOperation operation;
  final bool messageUnconfirmed;
  final VoidCallback? onCancel, onRetry;
  bool get _active => {
    CsAssetUploadStage.preparing,
    CsAssetUploadStage.presigning,
    CsAssetUploadStage.uploading,
    CsAssetUploadStage.confirming,
  }.contains(operation.stage);
  String _text(BuildContext context) {
    final t = context.t.customerService;
    return switch (operation.stage) {
      CsAssetUploadStage.preparing => t.attachPreparing,
      CsAssetUploadStage.presigning => t.attachPresigning,
      CsAssetUploadStage.uploading => t.attachUploading(
        sent: operation.sentBytes.toString(),
        total: operation.totalBytes.toString(),
      ),
      CsAssetUploadStage.confirming => t.attachConfirming,
      CsAssetUploadStage.cancelled => t.attachCancelled,
      CsAssetUploadStage.unknown => t.attachUnknown,
      CsAssetUploadStage.failed =>
        operation.canRetry ? t.attachUploadFailed : t.attachUploadStopped,
      CsAssetUploadStage.complete =>
        messageUnconfirmed ? t.attachUploadedNotSent : t.attachUploaded,
    };
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.small),
    child: Column(
      key: const ValueKey('cs-upload-status'),
      mainAxisSize: MainAxisSize.min,
      children: [Text(_text(context)), _controls(context)],
    ),
  );
  Widget _controls(BuildContext context) {
    final t = context.t.customerService;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_active)
          TextButton(
            key: const ValueKey('cs-cancel-upload'),
            onPressed: onCancel,
            child: Text(t.attachCancel),
          ),
        if (!_active && operation.canRetry && onRetry != null)
          TextButton(
            key: const ValueKey('cs-retry-upload'),
            onPressed: onRetry,
            child: Text(t.attachRetry),
          ),
      ],
    );
  }
}
