enum CsIntegrationAdmissionFailure {
  missing,
  origin,
  identity,
  history,
  lease,
  execution,
}

class CsIntegrationAdmissionRefused implements Exception {
  const CsIntegrationAdmissionRefused(this.reason);
  final CsIntegrationAdmissionFailure reason;
  @override
  String toString() => 'CS_INTEGRATION_ADMISSION_REFUSED:${reason.name}';
}

typedef CsRunSeat = ({
  String uid,
  String identity,
  String token,
  String refresh,
});

/// Syntactic admission only. Root must independently verify the live resource lease.
class CsIntegrationFixture {
  CsIntegrationFixture._(this._values, this.apiBase, this.historyIds);
  final Map<String, String> _values;
  final Uri apiBase;
  final List<String> historyIds;
  static const buildDefines = {
    'RUN_ID': String.fromEnvironment('CS_E2E_RUN_ID'),
    'API_BASE': String.fromEnvironment('CS_E2E_API_BASE'),
    'EXECUTION_APPROVED': String.fromEnvironment('CS_E2E_EXECUTION_APPROVED'),
    'DEVICE_PROFILE_OWNED': String.fromEnvironment(
      'CS_E2E_DEVICE_PROFILE_OWNED',
    ),
    'RESOURCE_SHA': String.fromEnvironment('CS_E2E_RESOURCE_SHA'),
    'SOURCE_SHA': String.fromEnvironment('CS_E2E_SOURCE_SHA'),
    'ACTOR_PROTOCOL_SHA': String.fromEnvironment('CS_E2E_ACTOR_PROTOCOL_SHA'),
    'ENVIRONMENT': String.fromEnvironment('CS_E2E_ENVIRONMENT'),
    'SIGN_KEY_SHA': String.fromEnvironment('CS_E2E_SIGN_KEY_SHA'),
    'DEVICE_ID': String.fromEnvironment('CS_E2E_DEVICE_ID'),
    'ORG_ID': String.fromEnvironment('CS_E2E_ORG_ID'),
    'WORKSPACE_ID': String.fromEnvironment('CS_E2E_WORKSPACE_ID'),
    'PROBE_SESSION_ID': String.fromEnvironment('CS_E2E_PROBE_SESSION_ID'),
    'PROBE_CONVERSATION_ID': String.fromEnvironment(
      'CS_E2E_PROBE_CONVERSATION_ID',
    ),
    'UI_SESSION_ID': String.fromEnvironment('CS_E2E_UI_SESSION_ID'),
    'UI_CONVERSATION_ID': String.fromEnvironment('CS_E2E_UI_CONVERSATION_ID'),
    'SEAT_A_UID': String.fromEnvironment('CS_E2E_SEAT_A_UID'),
    'SEAT_A_IDENTITY': String.fromEnvironment('CS_E2E_SEAT_A_IDENTITY'),
    'SEAT_A_JWT': String.fromEnvironment('CS_E2E_SEAT_A_JWT'),
    'SEAT_A_REFRESH': String.fromEnvironment('CS_E2E_SEAT_A_REFRESH'),
    'SEAT_B_UID': String.fromEnvironment('CS_E2E_SEAT_B_UID'),
    'SEAT_B_IDENTITY': String.fromEnvironment('CS_E2E_SEAT_B_IDENTITY'),
    'SEAT_B_JWT': String.fromEnvironment('CS_E2E_SEAT_B_JWT'),
    'SEAT_B_REFRESH': String.fromEnvironment('CS_E2E_SEAT_B_REFRESH'),
    'TRANSFER_TARGET_ID': String.fromEnvironment('CS_E2E_TRANSFER_TARGET_ID'),
    'HISTORY_IDS': String.fromEnvironment('CS_E2E_HISTORY_IDS'),
    'OLDEST_MARKER': String.fromEnvironment('CS_E2E_OLDEST_MARKER'),
    'NEWEST_MARKER': String.fromEnvironment('CS_E2E_NEWEST_MARKER'),
    'ASSET_SHA': String.fromEnvironment('CS_E2E_ASSET_SHA'),
    'ASSET_SIZE': String.fromEnvironment('CS_E2E_ASSET_SIZE'),
    'ASSET_NAME': String.fromEnvironment('CS_E2E_ASSET_NAME'),
    'SAVED_DEVICE_PATH': String.fromEnvironment('CS_E2E_SAVED_DEVICE_PATH'),
    'ASSET_DEVICE_PATH': String.fromEnvironment('CS_E2E_ASSET_DEVICE_PATH'),
    'ASSET_MIME': String.fromEnvironment('CS_E2E_ASSET_MIME'),
    'RATING_SCORE': String.fromEnvironment('CS_E2E_RATING_SCORE'),
  };
  factory CsIntegrationFixture.fromBuild() =>
      CsIntegrationFixture.parse(buildDefines);
  factory CsIntegrationFixture.parse(Map<String, String> values) {
    final copied = Map<String, String>.unmodifiable(values);
    for (final key in buildDefines.keys) {
      if ((copied[key] ?? '').isEmpty) {
        refuse(CsIntegrationAdmissionFailure.missing);
      }
    }
    _execution(copied);
    _identities(copied);
    final origin = Uri.tryParse(copied['API_BASE']!);
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      refuse(CsIntegrationAdmissionFailure.origin);
    }
    final history = copied['HISTORY_IDS']!.split(',');
    _history(history);
    _asset(copied);
    _devicePaths(copied);
    return CsIntegrationFixture._(
      copied,
      origin.replace(path: ''),
      List.unmodifiable(history),
    );
  }
  static Never refuse(CsIntegrationAdmissionFailure reason) =>
      throw CsIntegrationAdmissionRefused(reason);
  static bool positiveId(String value) {
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value)) return false;
    return BigInt.parse(value) <= BigInt.parse('9223372036854775807');
  }

  static void _execution(Map<String, String> v) {
    if (v['EXECUTION_APPROVED'] != 'true' ||
        v['DEVICE_PROFILE_OWNED'] != 'true') {
      refuse(CsIntegrationAdmissionFailure.execution);
    }
    if (!RegExp(r'^cx-[A-Za-z0-9-]{8,96}$').hasMatch(v['RUN_ID']!) ||
        ![
          'dev',
          'local',
          'local_home',
          'local_office',
        ].contains(v['ENVIRONMENT'])) {
      refuse(CsIntegrationAdmissionFailure.lease);
    }
    for (final key in [
      'RESOURCE_SHA',
      'SOURCE_SHA',
      'ACTOR_PROTOCOL_SHA',
      'SIGN_KEY_SHA',
      'ASSET_SHA',
    ]) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(v[key]!)) {
        refuse(CsIntegrationAdmissionFailure.lease);
      }
    }
    for (final key in [
      'SEAT_A_JWT',
      'SEAT_A_REFRESH',
      'SEAT_B_JWT',
      'SEAT_B_REFRESH',
    ]) {
      if (v[key]!.length > 8192 || RegExp(r'\s').hasMatch(v[key]!)) {
        refuse(CsIntegrationAdmissionFailure.identity);
      }
    }
  }

  static void _identities(Map<String, String> v) {
    for (final key in [
      'ORG_ID',
      'WORKSPACE_ID',
      'PROBE_SESSION_ID',
      'PROBE_CONVERSATION_ID',
      'UI_SESSION_ID',
      'UI_CONVERSATION_ID',
      'SEAT_A_UID',
      'SEAT_A_IDENTITY',
      'SEAT_B_UID',
      'SEAT_B_IDENTITY',
      'TRANSFER_TARGET_ID',
    ]) {
      if (!positiveId(v[key]!)) {
        refuse(CsIntegrationAdmissionFailure.identity);
      }
    }
    if (v['PROBE_SESSION_ID'] == v['UI_SESSION_ID'] ||
        v['PROBE_CONVERSATION_ID'] == v['UI_CONVERSATION_ID'] ||
        v['SEAT_A_UID'] == v['SEAT_B_UID'] ||
        v['SEAT_A_IDENTITY'] == v['SEAT_B_IDENTITY'] ||
        v['TRANSFER_TARGET_ID'] != v['SEAT_B_IDENTITY']) {
      refuse(CsIntegrationAdmissionFailure.identity);
    }
  }

  static void _history(List<String> ids) {
    if (ids.length != 200) refuse(CsIntegrationAdmissionFailure.history);
    BigInt? previous;
    for (final id in ids) {
      if (!positiveId(id)) refuse(CsIntegrationAdmissionFailure.history);
      final current = BigInt.parse(id);
      if (previous != null && current <= previous) {
        refuse(CsIntegrationAdmissionFailure.history);
      }
      previous = current;
    }
  }

  static void _asset(Map<String, String> v) {
    final size = int.tryParse(v['ASSET_SIZE']!),
        score = int.tryParse(v['RATING_SCORE']!);
    if (size == null ||
        size <= 0 ||
        size > 25 * 1024 * 1024 ||
        score == null ||
        score < 1 ||
        score > 5 ||
        !RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(v['ASSET_NAME']!) ||
        !v['OLDEST_MARKER']!.startsWith(v['RUN_ID']!) ||
        !v['NEWEST_MARKER']!.startsWith(v['RUN_ID']!)) {
      refuse(CsIntegrationAdmissionFailure.identity);
    }
  }

  /// This profile is Android user 0; aliases such as /sdcard are not accepted.
  static String deviceRunRoot(String runId) =>
      '/storage/emulated/0/Download/imboy-cs/$runId';
  static void _devicePaths(Map<String, String> values) {
    final root = deviceRunRoot(values['RUN_ID']!);
    final name = values['ASSET_NAME']!;
    if (name == '.' ||
        name == '..' ||
        values['ASSET_DEVICE_PATH'] != '$root/input/$name' ||
        values['SAVED_DEVICE_PATH'] != '$root/output/$name') {
      refuse(CsIntegrationAdmissionFailure.identity);
    }
  }

  String get runId => _values['RUN_ID']!;
  String get orgId => _values['ORG_ID']!;
  String get workspaceId => _values['WORKSPACE_ID']!;
  String get probeSessionId => _values['PROBE_SESSION_ID']!;
  String get probeConversationId => _values['PROBE_CONVERSATION_ID']!;
  String get uiSessionId => _values['UI_SESSION_ID']!;
  String get uiConversationId => _values['UI_CONVERSATION_ID']!;
  String get environment => _values['ENVIRONMENT']!;
  String get deviceId => _values['DEVICE_ID']!;
  String get signKeySha => _values['SIGN_KEY_SHA']!;
  String get oldestMarker => _values['OLDEST_MARKER']!;
  String get newestMarker => _values['NEWEST_MARKER']!;
  String get assetName => _values['ASSET_NAME']!;
  String get savedDevicePath => _values['SAVED_DEVICE_PATH']!;
  String get ownedDeviceRoot => deviceRunRoot(runId);
  String get assetDevicePath => _values['ASSET_DEVICE_PATH']!;
  String get assetMime => _values['ASSET_MIME']!;
  String get assetSha => _values['ASSET_SHA']!;
  int get assetSize => int.parse(_values['ASSET_SIZE']!);
  int get ratingScore => int.parse(_values['RATING_SCORE']!);
  CsRunSeat seat(String key) => (
    uid: _values['SEAT_${key}_UID']!,
    identity: _values['SEAT_${key}_IDENTITY']!,
    token: _values['SEAT_${key}_JWT']!,
    refresh: _values['SEAT_${key}_REFRESH']!,
  );
  @override
  String toString() => 'CS_INTEGRATION_FIXTURE';
}
