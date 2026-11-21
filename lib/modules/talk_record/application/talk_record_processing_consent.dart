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

/// 处理可用性 = 部署侧已冻结的适用性证据（P-01:LOCAL:02）。
///
/// policyVersion/processorConfigVersion 与各启用位就是本机可见的
/// 「身份/年龄适用方案已确认」证据面：任一缺失（无证据）即视为未确认，
/// 只阻断转写/摘要这类可选处理的启用；record_only 基础录音不受此函数
/// 约束。证据缺失不能靠任何勾选/免责声明补足——见
/// [validateTalkRecordProcessingConsent]，确认记录从不参与可用性判定。
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
