/// Current processing consent is separate from historical capture notice.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';

import 'talk_record_local_binding.dart';

class TalkRecordProcessingConsentRequired implements Exception {
  const TalkRecordProcessingConsentRequired(this.capabilities);
  final TalkRecordCapabilitiesModel capabilities;
}

bool talkRecordProcessingAvailable(
  TalkRecordCapabilitiesModel cap,
  String mode,
) =>
    cap.recordingEnabled &&
    cap.processingAvailable &&
    cap.asrEnabled &&
    (mode == 'transcribe' || (mode == 'summarize' && cap.summaryEnabled)) &&
    cap.policyVersion.isNotEmpty &&
    cap.processorConfigVersion.isNotEmpty;

void validateTalkRecordProcessingConsent(
  TalkRecordLocalBinding binding,
  TalkRecordCapabilitiesModel cap,
) {
  if (binding.processingMode == 'record_only') return;
  if ((binding.processingConsentGeneration.isNotEmpty &&
          binding.processingConsentAcknowledgedAt == null) ||
      !talkRecordProcessingAvailable(cap, binding.processingMode) ||
      binding.effectiveProcessingPolicy != cap.policyVersion ||
      binding.effectiveProcessingProcessor != cap.processorConfigVersion) {
    throw TalkRecordProcessingConsentRequired(cap);
  }
}

String talkRecordConsentFingerprint(TalkRecordLocalBinding binding) => sha256
    .convert(
      utf8.encode(
        jsonEncode([
          binding.processingMode,
          binding.processingMode == 'record_only'
              ? binding.effectiveUploadPolicy
              : binding.effectiveProcessingPolicy,
          binding.processingMode == 'record_only'
              ? ''
              : binding.effectiveProcessingProcessor,
          binding.processingConsentGeneration,
        ]),
      ),
    )
    .toString();
