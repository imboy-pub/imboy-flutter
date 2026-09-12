import 'dart:convert';

const String kMegolmSectionKey = 'megolm_inbound';
const String kMegolmInboundPrefix = 'megolm_inbound_';
const String kMegolmHistoryGrantPrefix = 'megolm_history_grant_';
const String kMegolmRestoredGrantPrefix = 'megolm_restored_history_grant_';
const int kMegolmSectionFormatVersion = 2;
const int kMaxMegolmSessions = 2000;

class MegolmHistoryGrant {
  const MegolmHistoryGrant({
    required this.scope,
    required this.sessionId,
    required this.generationNo,
    required this.startSeq,
    required this.endSeq,
  });

  final String scope;
  final String sessionId;
  final int generationNo;
  final int startSeq;
  final int endSeq;

  String get epochId => sessionId;

  bool allows(int? convSeq) {
    if (convSeq == null || convSeq < startSeq) return false;
    return convSeq <= endSeq;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'scope': scope,
    'session_id': sessionId,
    'epoch_id': epochId,
    'generation_no': generationNo,
    'start_seq': startSeq,
    'end_seq': endSeq,
    'source': 'server_history_grant',
  };

  static MegolmHistoryGrant? parse(
    dynamic raw, {
    required String expectedScope,
    required String expectedSessionId,
  }) {
    Map<dynamic, dynamic>? map;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) map = decoded;
      } on FormatException {
        return null;
      }
    } else if (raw is Map) {
      map = raw;
    }
    if (map == null || map['version'] != 1) return null;

    final scope = map['scope'];
    final sessionId = map['session_id'];
    final epochId = map['epoch_id'];
    final generationNo = _positiveInt(map['generation_no']);
    final startSeq = _positiveInt(map['start_seq']);
    final endSeq = _positiveInt(map['end_seq']);
    if (scope != expectedScope ||
        sessionId != expectedSessionId ||
        epochId != expectedSessionId ||
        map['source'] != 'server_history_grant' ||
        generationNo == null ||
        startSeq == null ||
        endSeq == null ||
        endSeq < startSeq) {
      return null;
    }
    return MegolmHistoryGrant(
      scope: scope as String,
      sessionId: sessionId as String,
      generationNo: generationNo,
      startSeq: startSeq,
      endSeq: endSeq,
    );
  }
}

class MegolmBackupSession {
  const MegolmBackupSession({
    required this.scope,
    required this.sessionId,
    required this.exportedKey,
    required this.grant,
  });

  final String scope;
  final String sessionId;
  final String exportedKey;
  final MegolmHistoryGrant grant;

  String get suffix => '$scope:$sessionId';

  Map<String, dynamic> toJson() => {
    'scope': scope,
    'session_id': sessionId,
    'exported_key': exportedKey,
    'grant': grant.toJson(),
  };

  static MegolmBackupSession? parse(dynamic raw) {
    if (raw is! Map) return null;
    final scope = raw['scope'];
    final sessionId = raw['session_id'];
    final exportedKey = raw['exported_key'];
    if (scope is! String ||
        !_isGroupScope(scope) ||
        sessionId is! String ||
        sessionId.isEmpty ||
        exportedKey is! String ||
        exportedKey.isEmpty) {
      return null;
    }
    final grant = MegolmHistoryGrant.parse(
      raw['grant'],
      expectedScope: scope,
      expectedSessionId: sessionId,
    );
    if (grant == null) return null;
    return MegolmBackupSession(
      scope: scope,
      sessionId: sessionId,
      exportedKey: exportedKey,
      grant: grant,
    );
  }
}

class MegolmBackupSection {
  const MegolmBackupSection({
    required this.sessions,
    this.omittedSessionCount = 0,
  });

  final List<MegolmBackupSession> sessions;
  final int omittedSessionCount;

  bool get isEmpty => sessions.isEmpty;

  Map<String, dynamic> toJson() => {
    'format_version': kMegolmSectionFormatVersion,
    'sessions': sessions.map((e) => e.toJson()).toList(growable: false),
    'omitted_session_count': omittedSessionCount,
  };
}

MegolmBackupSection collectMegolmSection(Map<String, String> allEntries) {
  final sessions = <MegolmBackupSession>[];
  var omitted = 0;
  for (final entry in allEntries.entries) {
    if (!entry.key.startsWith(kMegolmInboundPrefix) || entry.value.isEmpty) {
      continue;
    }
    final suffix = entry.key.substring(kMegolmInboundPrefix.length);
    final separator = suffix.indexOf(':');
    if (separator <= 0 || separator == suffix.length - 1) {
      omitted++;
      continue;
    }
    final scope = suffix.substring(0, separator);
    final sessionId = suffix.substring(separator + 1);
    if (!_isGroupScope(scope)) {
      omitted++;
      continue;
    }
    final grant = MegolmHistoryGrant.parse(
      allEntries['$kMegolmHistoryGrantPrefix$suffix'],
      expectedScope: scope,
      expectedSessionId: sessionId,
    );
    if (grant == null || sessions.length >= kMaxMegolmSessions) {
      omitted++;
      continue;
    }
    sessions.add(
      MegolmBackupSession(
        scope: scope,
        sessionId: sessionId,
        exportedKey: entry.value,
        grant: grant,
      ),
    );
  }
  return MegolmBackupSection(
    sessions: List.unmodifiable(sessions),
    omittedSessionCount: omitted,
  );
}

MegolmBackupSection parseMegolmSection(dynamic raw) {
  if (raw is! Map) {
    return const MegolmBackupSection(sessions: []);
  }
  if (raw['format_version'] != kMegolmSectionFormatVersion) {
    final legacyCount = raw.entries
        .where(
          (e) =>
              e.key is String &&
              e.value is String &&
              (e.value as String).isNotEmpty,
        )
        .length;
    return MegolmBackupSection(
      sessions: const [],
      omittedSessionCount: legacyCount,
    );
  }
  final rows = raw['sessions'];
  if (rows is! List) {
    throw const FormatException('Megolm v2 sessions 结构无效');
  }
  final sessions = <MegolmBackupSession>[];
  var omitted = _nonNegativeInt(raw['omitted_session_count']) ?? 0;
  for (final row in rows) {
    final parsed = MegolmBackupSession.parse(row);
    if (parsed == null || sessions.length >= kMaxMegolmSessions) {
      omitted++;
    } else {
      sessions.add(parsed);
    }
  }
  return MegolmBackupSection(
    sessions: List.unmodifiable(sessions),
    omittedSessionCount: omitted,
  );
}

List<MapEntry<String, String>> megolmRestoreEntries(
  MegolmBackupSection section,
) {
  final out = <MapEntry<String, String>>[];
  for (final session in section.sessions) {
    final grantJson = jsonEncode(session.grant.toJson());
    out.add(
      MapEntry('$kMegolmRestoredGrantPrefix${session.suffix}', grantJson),
    );
    out.add(MapEntry('$kMegolmHistoryGrantPrefix${session.suffix}', grantJson));
    out.add(
      MapEntry('$kMegolmInboundPrefix${session.suffix}', session.exportedKey),
    );
  }
  return out;
}

bool _isGroupScope(String scope) {
  final value = BigInt.tryParse(scope);
  return value != null && value > BigInt.zero;
}

int? _positiveInt(dynamic value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _nonNegativeInt(dynamic value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 0 ? parsed : null;
}
