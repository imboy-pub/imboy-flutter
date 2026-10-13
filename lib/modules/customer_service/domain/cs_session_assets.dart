part of 'cs_session_flow.dart';

extension CsSessionAssets on CsSessionFlow {
  String get _assetIdentity => '$orgId/$sessionId/$conversationId/$identityId';
  bool get _assetWritable =>
      _current && !readRevoked && !_actionPending && machine.canSend;
  Future<String> uploadAsset({
    required String mime,
    required Uint8List bytes,
    String fileName = '',
    CsAssetUploadOperation? operation,
  }) async {
    if (!_assetWritable || _writesInFlight > 0 || pendingClientMsgId != null) {
      return '';
    }
    final origin = _assetIdentity;
    _writesInFlight++;
    try {
      await resolveWorkspaceId();
      if (origin != _assetIdentity ||
          !_assetWritable ||
          workspaceId.isEmpty ||
          conversationId.isEmpty) {
        return '';
      }
      return await _uploadBound(mime, bytes, fileName, operation);
    } finally {
      _writesInFlight--;
    }
  }

  Future<String> _uploadBound(
    String mime,
    Uint8List bytes,
    String fileName,
    CsAssetUploadOperation? operation,
  ) async {
    final scope = _scope();
    final active = operation ?? CsAssetUploadOperation(onChanged: onChanged);
    active.bindScope(() => _same(scope) && _assetWritable);
    assetOperation = active;
    try {
      final asset = await _csApi.uploadEnterpriseAsset(
        orgId,
        workspaceId: workspaceId,
        conversationId: conversationId,
        mime: mime,
        bytes: bytes,
        fileName: fileName,
        operation: active,
      );
      return _same(scope) && _assetWritable ? asset.id : '';
    } on CsAssetOperationException catch (e) {
      if (_same(scope) && (e.status == 401 || e.status == 403)) {
        applyActionFailure(
          CsApiException(e.status!, 'asset permission refused'),
        );
      }
      return '';
    } on CsApiException catch (e) {
      if (_same(scope)) applyActionFailure(e);
      return '';
    }
  }

  void cancelAssetUpload() => assetOperation?.cancel();
  Future<CsVerifiedAssetContent?> fetchAssetContent(String assetId) async {
    if (!_current ||
        readRevoked ||
        !machine.canDownload ||
        conversationId.isEmpty) {
      return null;
    }
    final initial = _assetIdentity;
    await resolveWorkspaceId();
    if (!_current ||
        readRevoked ||
        !machine.canDownload ||
        workspaceId.isEmpty) {
      return null;
    }
    // Workspace resolution may fill an initially empty scope, never change its business identity.
    if (initial != _assetIdentity) return null;
    final scope = _scope();
    try {
      final content = await _csApi.fetchAssetContent(
        orgId,
        assetId,
        workspaceId: workspaceId,
      );
      return _same(scope) && !readRevoked && machine.canDownload
          ? content
          : null;
    } on EnterpriseApiException catch (e) {
      if (_same(scope)) {
        applyActionFailure(CsApiException(e.code, 'asset content rejected'));
      }
      return null;
    }
  }

  Future<Uint8List?> fetchAssetBytes(String assetId) async =>
      (await fetchAssetContent(assetId))?.bytes;
}
