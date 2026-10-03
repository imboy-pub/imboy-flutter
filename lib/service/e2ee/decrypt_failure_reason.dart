/// 指标只保存有限分类；信封错误可能包含不可信 CBOR 键或动态大小。
String normalizeDecryptFailureReason(Object? reason) {
  if (reason is! String) return 'unknown';
  if (_knownReasons.contains(reason)) return reason;
  if (reason.startsWith('bounds_')) return 'bounds_invalid';
  if (reason.startsWith('envelope_')) return 'envelope_invalid';
  return 'unknown';
}

const _knownReasons = <String>{
  'already_processed',
  'bounds_invalid',
  'context_mismatch_from',
  'context_mismatch_gid',
  'context_mismatch_id',
  'context_mismatch_msg_type',
  'context_mismatch_sender_did',
  'context_mismatch_session_id',
  'context_mismatch_to',
  'context_mismatch_type',
  'crypto_store_unavailable',
  'decrypt_error',
  'decrypt_failed',
  'duplicate_message',
  'envelope_invalid',
  'fan_out_missing_devices',
  'group_scope_mismatch',
  'header_mismatch_action',
  'header_mismatch_conversation_id',
  'header_mismatch_created_at_ms',
  'header_mismatch_destination',
  'header_mismatch_epoch_or_counter',
  'header_mismatch_message_id',
  'header_mismatch_message_type',
  'header_mismatch_protocol',
  'header_mismatch_protocol_version',
  'header_mismatch_scope',
  'header_mismatch_sender_did',
  'header_mismatch_sender_uid',
  'header_mismatch_session_ref',
  'historical_room_key_scope_denied',
  'inner_frame_cbor_invalid',
  'inner_frame_not_map',
  'inner_header_missing',
  'inner_payload_invalid',
  'invalid_ciphertext_format',
  'invalid_e2ee',
  'invalid_keys',
  'invalid_plaintext',
  'missing_ciphertext',
  'missing_fields',
  'missing_protocol_metadata',
  'mls_not_implemented',
  'no_device_envelope',
  'no_device_key',
  'nonce_mismatch',
  'unknown',
};
