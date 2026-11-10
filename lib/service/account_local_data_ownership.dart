part of 'account_local_data_service.dart';

/// The cached recovery passphrase has its own owner; a stale last-login profile
/// cannot transfer that ownership to a different account.
String? _backupPassphraseOwner(Map<String, String> secure) {
  final raw = secure[kE2eeBackupPassphraseSecureKey];
  if (raw == null) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['uid'] is! String ||
        (value['uid'] as String).trim().isEmpty ||
        value['passphrase'] is! String) {
      throw const AccountLocalDataOwnershipException();
    }
    return value['uid'] as String;
  } on FormatException {
    throw const AccountLocalDataOwnershipException();
  }
}

Future<void> _rejectUnownedLegacyTemporaryFiles(Directory temporary) async {
  if (!await temporary.exists()) return;
  await for (final entry in temporary.list(followLinks: false)) {
    final name = p.basename(entry.path);
    final legacyFile =
        (name.startsWith('imboy_e2ee_backup_') && name.endsWith('.enc')) ||
        (name.startsWith('voice_tmp_') &&
            RegExp(r'\.(aac|webm|mp4)$').hasMatch(name)) ||
        (name.startsWith('imboy_data_') && name.endsWith('.json')) ||
        (name.startsWith('cropped_') && name.endsWith('.jpg')) ||
        name.startsWith('imboy-direct-');
    if (legacyFile) throw const AccountLocalDataOwnershipException();
    if (name == 'db_snapshots' &&
        (entry is! Directory ||
            !await entry.list(followLinks: false).isEmpty)) {
      throw const AccountLocalDataOwnershipException();
    }
  }
}

/// audio_waveforms' pinned native defaults wrote ownerless plaintext recordings:
/// Android cacheDir uses dd-MM-yy-hh-mm-ss + createTempFile digits; Apple
/// Documents uses YY-MM-dd-HH-mm-ss. Recognize only these defaults, never delete
/// arbitrary recordings or user exports in either directory.
Future<void> _rejectUnownedWaveformRecordings(
  Directory directory, {
  required bool randomizedSuffix,
}) async {
  if (!await directory.exists()) return;
  final name = randomizedSuffix
      ? RegExp(
          r'^(?:0[1-9]|[12][0-9]|3[01])-(?:0[1-9]|1[0-2])-[0-9]{2}-(?:0[1-9]|1[0-2])-[0-5][0-9]-[0-5][0-9][0-9]+\.m4a$',
        )
      : RegExp(
          r'^[0-9]{2}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])-(?:[01][0-9]|2[0-3])-[0-5][0-9]-[0-5][0-9]\.m4a$',
        );
  await for (final entry in directory.list(followLinks: false)) {
    if (name.hasMatch(p.basename(entry.path))) {
      throw const AccountLocalDataOwnershipException();
    }
  }
}

void _rejectUnownedLegacyPreferences() {
  for (final key in const [
    'chat_search_history',
    'message_search_history',
    'web_search_history',
    'user_collect_pinned_ids',
    'imboy.deleted_message_ids.v1',
  ]) {
    if (!StorageService.to.containsKey(key)) continue;
    try {
      final list = StorageService.to.getStringList(key);
      if (list != null && list.isEmpty) continue;
    } on Object {
      // Legacy versions used both JSON and string-list encodings.
      try {
        final raw = StorageService.to.getString(key);
        if (raw.isEmpty) continue;
        final value = jsonDecode(raw);
        if ((value is List && value.isEmpty) ||
            (value is Map && value.isEmpty)) {
          continue;
        }
      } on Object {
        throw const AccountLocalDataOwnershipException();
      }
    }
    throw const AccountLocalDataOwnershipException();
  }
  for (final raw
      in StorageService.to.getStringList('ws_message_queue') ?? <String>[]) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['ownerUid'] is! String ||
          (value['ownerUid'] as String).isEmpty) {
        throw const AccountLocalDataOwnershipException();
      }
    } on FormatException {
      throw const AccountLocalDataOwnershipException();
    }
  }
}

/// Recording keys use a legacy global prefix, but their session/checkpoint IDs
/// are recorded under an account directory. Read that evidence before removing
/// files; an unowned key or a conflicting binding must preserve every account.
Future<Set<String>> _recordingSecretsForAccount(
  Directory root,
  String selectedDigest,
  Set<String> secureKeys,
) async {
  final owners = <String, Set<String>>{};
  void add(String owner, String id) {
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id)) {
      throw const AccountLocalDataOwnershipException();
    }
    (owners['trk_$id'] ??= {}).add(owner);
  }

  if (await root.exists()) {
    await for (final account in root.list(followLinks: false)) {
      if (account is! Directory) continue;
      final owner = p.basename(account.path);
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(owner)) continue;
      final audio = Directory(p.join(account.path, 'audio'));
      if (await audio.exists()) {
        await for (final session in audio.list(followLinks: false)) {
          if (session is Directory) add(owner, p.basename(session.path));
        }
      }
      final ai = Directory(p.join(account.path, 'ai'));
      if (await ai.exists()) {
        await for (final checkpoint in ai.list(followLinks: false)) {
          final match = RegExp(
            r'^(talk-ai-[a-f0-9]{64})\.enc(?:\.tmp|\.owner)?$',
          ).firstMatch(p.basename(checkpoint.path));
          if (checkpoint is File && match != null) add(owner, match[1]!);
        }
      }
      await for (final binding in account.list(followLinks: false)) {
        if (binding is! File ||
            !RegExp(r'\.json(?:\.tmp)?$').hasMatch(binding.path)) {
          continue;
        }
        try {
          final value = jsonDecode(await binding.readAsString());
          if (value is! Map ||
              value['endpoint'] is! String ||
              value['user_id'] is! String ||
              AccountLocalDataService._digest([
                    value['endpoint'] as String,
                    value['user_id'] as String,
                  ]) !=
                  owner) {
            throw const AccountLocalDataOwnershipException();
          }
          final session = value['session_id'];
          if (session is String && session.isNotEmpty) add(owner, session);
        } on FormatException {
          throw const AccountLocalDataOwnershipException();
        }
      }
    }
  }
  for (final key in secureKeys.where((key) => key.startsWith('trk_'))) {
    if (owners[key]?.length != 1) {
      throw const AccountLocalDataOwnershipException();
    }
  }
  return owners.entries
      .where((entry) => entry.value.contains(selectedDigest))
      .map((entry) => entry.key)
      .toSet();
}
