/// Durable ownership fence between encrypted local audio and its server capture.
library;

import 'dart:convert';
import 'dart:io';

import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

import 'package:crypto/crypto.dart';

import '../presentation/talk_record_entry_context.dart';

import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';

class TalkRecordAccount {
  const TalkRecordAccount(this.endpoint, this.userId);
  final String endpoint;
  final String userId;
  bool get valid => endpoint.isNotEmpty && userId.isNotEmpty;
  String get storageKey =>
      sha256.convert(utf8.encode(jsonEncode([endpoint, userId]))).toString();
  @override
  bool operator ==(Object other) =>
      other is TalkRecordAccount &&
      endpoint == other.endpoint &&
      userId == other.userId;
  @override
  int get hashCode => Object.hash(endpoint, userId);
}

class TalkRecordLocalBinding {
  const TalkRecordLocalBinding({
    required this.account,
    required this.clientRecordingId,
    required this.context,
    required this.title,
    required this.processingMode,
    required this.deviceSessionId,
    this.deviceId = '',
    this.sessionId = '',
    this.recordId = '',
    this.recordEtag = '',
    this.captureId = '',
    this.leaseEpoch = -1,
    this.captureStatus = '',
    this.policyVersion = '',
    this.uploadPolicyVersion = '',
    this.submittedPolicyVersion = '',
    this.uploadPolicyAcknowledgedAt,
    this.uploadAttempted = false,
    this.processingConsentPolicyVersion = '',
    this.processingConsentProcessorVersion = '',
    this.processingConsentGeneration = '',
    this.processingConsentAcknowledgedAt,
    this.processorConfigVersion = '',
    this.language = 'auto',
    this.captureEtag = '',
    this.leaseUntil,
    this.completed = false,
    this.participants = const [],
    this.participantsRequested = false,
    this.participantsSynced = false,
  });
  final TalkRecordAccount account;
  final String clientRecordingId, deviceSessionId, title, processingMode;
  final String deviceId;
  final String policyVersion, processorConfigVersion, language;
  final String uploadPolicyVersion, submittedPolicyVersion;
  final DateTime? uploadPolicyAcknowledgedAt;
  final bool uploadAttempted;
  final String processingConsentPolicyVersion,
      processingConsentProcessorVersion;
  final String processingConsentGeneration;
  final DateTime? processingConsentAcknowledgedAt;
  String get effectiveProcessingPolicy => processingConsentGeneration.isEmpty
      ? policyVersion
      : processingConsentPolicyVersion;
  String get effectiveProcessingProcessor => processingConsentGeneration.isEmpty
      ? processorConfigVersion
      : processingConsentProcessorVersion;
  String get effectiveUploadPolicy =>
      uploadPolicyVersion.isEmpty ? policyVersion : uploadPolicyVersion;
  final TalkRecordEntryContext context;
  final String sessionId, recordId, recordEtag, captureId, captureEtag;
  final int leaseEpoch;
  final String captureStatus;
  final DateTime? leaseUntil;
  final bool completed;
  final List<TalkRecordParticipantInput> participants;
  final bool participantsRequested, participantsSynced;

  TalkRecordLocalBinding withSession(String id) => copyWith(sessionId: id);
  TalkRecordLocalBinding copyWith({
    String? processingConsentPolicyVersion,
    String? processingConsentProcessorVersion,
    String? processingConsentGeneration,
    DateTime? processingConsentAcknowledgedAt,
    String? deviceId,
    String? uploadPolicyVersion,
    String? submittedPolicyVersion,
    DateTime? uploadPolicyAcknowledgedAt,
    bool? uploadAttempted,
    String? sessionId,
    String? recordId,
    String? recordEtag,
    String? captureId,
    String? captureEtag,
    int? leaseEpoch,
    String? captureStatus,
    DateTime? leaseUntil,
    bool? completed,
    bool? participantsSynced,
    List<TalkRecordParticipantInput>? participants,
    bool? participantsRequested,
  }) => TalkRecordLocalBinding(
    account: account,
    clientRecordingId: clientRecordingId,
    context: context,
    title: title,
    policyVersion: policyVersion,
    uploadPolicyVersion: uploadPolicyVersion ?? this.uploadPolicyVersion,
    submittedPolicyVersion:
        submittedPolicyVersion ?? this.submittedPolicyVersion,
    uploadPolicyAcknowledgedAt:
        uploadPolicyAcknowledgedAt ?? this.uploadPolicyAcknowledgedAt,
    uploadAttempted: uploadAttempted ?? this.uploadAttempted,
    processingConsentPolicyVersion:
        processingConsentPolicyVersion ?? this.processingConsentPolicyVersion,
    processingConsentProcessorVersion:
        processingConsentProcessorVersion ??
        this.processingConsentProcessorVersion,
    processingConsentGeneration:
        processingConsentGeneration ?? this.processingConsentGeneration,
    processingConsentAcknowledgedAt:
        processingConsentAcknowledgedAt ?? this.processingConsentAcknowledgedAt,
    processorConfigVersion: processorConfigVersion,
    language: language,
    processingMode: processingMode,
    deviceSessionId: deviceSessionId,
    deviceId: _pinnedDevice(deviceId),
    sessionId: sessionId ?? this.sessionId,
    recordId: recordId ?? this.recordId,
    recordEtag: recordEtag ?? this.recordEtag,
    captureId: captureId ?? this.captureId,
    captureEtag: captureEtag ?? this.captureEtag,
    leaseEpoch: leaseEpoch ?? this.leaseEpoch,
    captureStatus: captureStatus ?? this.captureStatus,
    leaseUntil: leaseUntil ?? this.leaseUntil,
    completed: completed ?? this.completed,
    participants: participants == null
        ? this.participants
        : List.unmodifiable(participants),
    participantsRequested: participantsRequested ?? this.participantsRequested,
    participantsSynced: participantsSynced ?? this.participantsSynced,
  );

  String _pinnedDevice(String? next) {
    if (deviceId.isNotEmpty && next != null && next != deviceId) {
      throw StateError('Recording device identity is already pinned');
    }
    return next ?? deviceId;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'policy_version': policyVersion,
    'upload_policy_version': uploadPolicyVersion,
    'submitted_policy_version': submittedPolicyVersion,
    'upload_policy_acknowledged_at': uploadPolicyAcknowledgedAt
        ?.toUtc()
        .toIso8601String(),
    'upload_attempted': uploadAttempted,
    'processing_consent_policy_version': processingConsentPolicyVersion,
    'processing_consent_processor_version': processingConsentProcessorVersion,
    'processing_consent_generation': processingConsentGeneration,
    'processing_consent_acknowledged_at': processingConsentAcknowledgedAt
        ?.toUtc()
        .toIso8601String(),
    'processor_config_version': processorConfigVersion,
    'language': language,
    'endpoint': account.endpoint,
    'user_id': account.userId,
    'client_recording_id': clientRecordingId,
    'device_session_id': deviceSessionId,
    'device_id': deviceId,
    'context': context.toQuery(),
    'title': title,
    'processing_mode': processingMode,
    'session_id': sessionId,
    'record_id': recordId,
    'record_etag': recordEtag,
    'capture_id': captureId,
    'capture_etag': captureEtag,
    'lease_epoch': leaseEpoch,
    'capture_status': captureStatus,
    'lease_until': leaseUntil?.toUtc().toIso8601String(),
    'completed': completed,
    'participants': participants
        .map((item) => item.toJson())
        .toList(growable: false),
    'participants_requested': participantsRequested,
    'participants_synced': participantsSynced,
  };
  factory TalkRecordLocalBinding.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['context'] is! Map) {
      throw const FormatException('Invalid recording ownership binding');
    }
    String field(String key) => json[key] as String;
    final context = Map<String, String>.from(json['context'] as Map);
    if (!const ['personal', 'organization'].contains(context['scope']) ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(field('client_recording_id')) ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(field('device_session_id')) ||
        (field('session_id').isNotEmpty &&
            !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(field('session_id')))) {
      throw const FormatException('Invalid local binding identity');
    }
    return TalkRecordLocalBinding(
      account: TalkRecordAccount(field('endpoint'), field('user_id')),
      clientRecordingId: field('client_recording_id'),
      deviceSessionId: field('device_session_id'),
      deviceId: json['device_id'] as String? ?? '',
      context: TalkRecordEntryContext.fromQuery(context),
      title: field('title'),
      policyVersion: field('policy_version'),
      uploadPolicyVersion: json['upload_policy_version'] as String? ?? '',
      submittedPolicyVersion: json['submitted_policy_version'] as String? ?? '',
      uploadPolicyAcknowledgedAt: json['upload_policy_acknowledged_at'] == null
          ? null
          : DateTime.parse(json['upload_policy_acknowledged_at'] as String),
      uploadAttempted: json['upload_attempted'] as bool? ?? false,
      processingConsentPolicyVersion:
          json['processing_consent_policy_version'] as String? ?? '',
      processingConsentProcessorVersion:
          json['processing_consent_processor_version'] as String? ?? '',
      processingConsentGeneration:
          json['processing_consent_generation'] as String? ?? '',
      processingConsentAcknowledgedAt:
          json['processing_consent_acknowledged_at'] == null
          ? null
          : DateTime.parse(
              json['processing_consent_acknowledged_at'] as String,
            ),
      processorConfigVersion: json['processor_config_version'] as String? ?? '',
      language: field('language'),
      processingMode: field('processing_mode'),
      sessionId: field('session_id'),
      recordId: field('record_id'),
      recordEtag: field('record_etag'),
      captureId: field('capture_id'),
      captureEtag: field('capture_etag'),
      leaseEpoch: parseTalkRecordLeaseEpoch(json['lease_epoch']),
      captureStatus: json['capture_status'] as String? ?? '',
      leaseUntil: json['lease_until'] == null
          ? null
          : DateTime.parse(field('lease_until')),
      completed: json['completed'] as bool,
      participantsRequested: json['participants_requested'] as bool? ?? false,
      participantsSynced: json['participants_synced'] as bool? ?? false,
      participants: List.unmodifiable(
        (json['participants'] as List? ?? const []).map(
          (item) => TalkRecordParticipantInput.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }
}

/// Own account directory only; corrupt bindings fail closed, never reset to zero.
class TalkRecordBindingStore {
  TalkRecordBindingStore(this.root);
  final Directory root;
  Directory audioDirectory(TalkRecordAccount account) =>
      Directory('${root.path}/${account.storageKey}/audio');
  File _file(TalkRecordLocalBinding binding) => File(
    '${root.path}/${binding.account.storageKey}/${binding.clientRecordingId}.json',
  );

  Future<void> save(TalkRecordLocalBinding binding) async {
    if (!binding.account.valid ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(binding.clientRecordingId)) {
      throw const FormatException('Invalid recording owner');
    }
    final target = _file(binding);
    await target.parent.create(recursive: true);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(jsonEncode(binding.toJson()), flush: true);
    await tmp.rename(target.path);
  }

  Future<List<TalkRecordLocalBinding>> list(TalkRecordAccount account) async {
    if (!account.valid) throw StateError('Authentication required');
    final dir = Directory('${root.path}/${account.storageKey}');
    if (!await dir.exists()) return [];
    final out = <TalkRecordLocalBinding>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final binding = TalkRecordLocalBinding.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(await entity.readAsString()) as Map,
        ),
      );
      if (binding.account != account) {
        throw StateError('Recording owner mismatch');
      }
      out.add(binding);
    }
    return out;
  }
}
