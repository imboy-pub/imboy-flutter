// This is a generated file - do not edit.
//
// Generated from imboy.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use msgDirectionDescriptor instead')
const MsgDirection$json = {
  '1': 'MsgDirection',
  '2': [
    {'1': 'MSG_DIRECTION_UNSPECIFIED', '2': 0},
    {'1': 'C2C', '2': 1},
    {'1': 'C2G', '2': 2},
    {'1': 'C2S', '2': 3},
    {'1': 'S2C', '2': 4},
    {'1': 'WEBRTC_OFFER', '2': 10},
    {'1': 'WEBRTC_ANSWER', '2': 11},
    {'1': 'WEBRTC_CANDIDATE', '2': 12},
    {'1': 'WEBRTC_BYE', '2': 13},
    {'1': 'C2C_SERVER_ACK', '2': 20},
    {'1': 'C2G_SERVER_ACK', '2': 21},
    {'1': 'CLIENT_ACK', '2': 22},
    {'1': 'CLIENT_ACK_CONFIRM', '2': 23},
  ],
};

/// Descriptor for `MsgDirection`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List msgDirectionDescriptor = $convert.base64Decode(
    'CgxNc2dEaXJlY3Rpb24SHQoZTVNHX0RJUkVDVElPTl9VTlNQRUNJRklFRBAAEgcKA0MyQxABEg'
    'cKA0MyRxACEgcKA0MyUxADEgcKA1MyQxAEEhAKDFdFQlJUQ19PRkZFUhAKEhEKDVdFQlJUQ19B'
    'TlNXRVIQCxIUChBXRUJSVENfQ0FORElEQVRFEAwSDgoKV0VCUlRDX0JZRRANEhIKDkMyQ19TRV'
    'JWRVJfQUNLEBQSEgoOQzJHX1NFUlZFUl9BQ0sQFRIOCgpDTElFTlRfQUNLEBYSFgoSQ0xJRU5U'
    'X0FDS19DT05GSVJNEBc=');

@$core.Deprecated('Use contentTypeDescriptor instead')
const ContentType$json = {
  '1': 'ContentType',
  '2': [
    {'1': 'CONTENT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'TEXT', '2': 1},
    {'1': 'IMAGE', '2': 2},
    {'1': 'VIDEO', '2': 3},
    {'1': 'AUDIO', '2': 4},
    {'1': 'FILE', '2': 5},
    {'1': 'LOCATION', '2': 6},
    {'1': 'CUSTOM', '2': 7},
    {'1': 'E2EE', '2': 8},
  ],
};

/// Descriptor for `ContentType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List contentTypeDescriptor = $convert.base64Decode(
    'CgtDb250ZW50VHlwZRIcChhDT05URU5UX1RZUEVfVU5TUEVDSUZJRUQQABIICgRURVhUEAESCQ'
    'oFSU1BR0UQAhIJCgVWSURFTxADEgkKBUFVRElPEAQSCAoERklMRRAFEgwKCExPQ0FUSU9OEAYS'
    'CgoGQ1VTVE9NEAcSCAoERTJFRRAI');

@$core.Deprecated('Use s2CActionDescriptor instead')
const S2CAction$json = {
  '1': 'S2CAction',
  '2': [
    {'1': 'S2C_ACTION_UNSPECIFIED', '2': 0},
    {'1': 'PULL_OFFLINE_MSG', '2': 1},
    {'1': 'PLEASE_REFRESH_TOKEN', '2': 2},
    {'1': 'DEVICE_KICKED', '2': 3},
    {'1': 'APP_UPGRADE', '2': 4},
    {'1': 'C2C_DEL_EVERYONE', '2': 5},
    {'1': 'C2G_DEL_FOR_ME', '2': 6},
    {'1': 'C2G_DEL_EVERYONE', '2': 7},
    {'1': 'STORE_SHARD', '2': 8},
    {'1': 'SHARD_STORED', '2': 9},
    {'1': 'E2EE_KEY_CHANGED_ACK', '2': 10},
    {'1': 'INVALID_MESSAGE_TYPE', '2': 11},
    {'1': 'POLICY_VIOLATION', '2': 12},
    {'1': 'LOGGED_ANOTHER_DEVICE', '2': 13},
  ],
};

/// Descriptor for `S2CAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List s2CActionDescriptor = $convert.base64Decode(
    'CglTMkNBY3Rpb24SGgoWUzJDX0FDVElPTl9VTlNQRUNJRklFRBAAEhQKEFBVTExfT0ZGTElORV'
    '9NU0cQARIYChRQTEVBU0VfUkVGUkVTSF9UT0tFThACEhEKDURFVklDRV9LSUNLRUQQAxIPCgtB'
    'UFBfVVBHUkFERRAEEhQKEEMyQ19ERUxfRVZFUllPTkUQBRISCg5DMkdfREVMX0ZPUl9NRRAGEh'
    'QKEEMyR19ERUxfRVZFUllPTkUQBxIPCgtTVE9SRV9TSEFSRBAIEhAKDFNIQVJEX1NUT1JFRBAJ'
    'EhgKFEUyRUVfS0VZX0NIQU5HRURfQUNLEAoSGAoUSU5WQUxJRF9NRVNTQUdFX1RZUEUQCxIUCh'
    'BQT0xJQ1lfVklPTEFUSU9OEAwSGQoVTE9HR0VEX0FOT1RIRVJfREVWSUNFEA0=');

@$core.Deprecated('Use iMBoyMessageDescriptor instead')
const IMBoyMessage$json = {
  '1': 'IMBoyMessage',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.imboy.MsgDirection',
      '10': 'type'
    },
    {'1': 'from', '3': 3, '4': 1, '5': 18, '10': 'from'},
    {'1': 'to', '3': 4, '4': 1, '5': 18, '10': 'to'},
    {
      '1': 'msg_type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.imboy.ContentType',
      '10': 'msgType'
    },
    {'1': 'action', '3': 6, '4': 1, '5': 9, '10': 'action'},
    {
      '1': 'e2ee',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.imboy.E2EEMeta',
      '10': 'e2ee'
    },
    {'1': 'payload', '3': 8, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'created_at', '3': 9, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'server_ts', '3': 10, '4': 1, '5': 3, '10': 'serverTs'},
    {'1': 'expire_secs', '3': 11, '4': 1, '5': 5, '10': 'expireSecs'},
    {'1': 'conv_seq', '3': 12, '4': 1, '5': 3, '10': 'convSeq'},
  ],
};

/// Descriptor for `IMBoyMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iMBoyMessageDescriptor = $convert.base64Decode(
    'CgxJTUJveU1lc3NhZ2USDgoCaWQYASABKAlSAmlkEicKBHR5cGUYAiABKA4yEy5pbWJveS5Nc2'
    'dEaXJlY3Rpb25SBHR5cGUSEgoEZnJvbRgDIAEoElIEZnJvbRIOCgJ0bxgEIAEoElICdG8SLQoI'
    'bXNnX3R5cGUYBSABKA4yEi5pbWJveS5Db250ZW50VHlwZVIHbXNnVHlwZRIWCgZhY3Rpb24YBi'
    'ABKAlSBmFjdGlvbhIjCgRlMmVlGAcgASgLMg8uaW1ib3kuRTJFRU1ldGFSBGUyZWUSGAoHcGF5'
    'bG9hZBgIIAEoDFIHcGF5bG9hZBIdCgpjcmVhdGVkX2F0GAkgASgDUgljcmVhdGVkQXQSGwoJc2'
    'VydmVyX3RzGAogASgDUghzZXJ2ZXJUcxIfCgtleHBpcmVfc2VjcxgLIAEoBVIKZXhwaXJlU2Vj'
    'cxIZCghjb252X3NlcRgMIAEoA1IHY29udlNlcQ==');

@$core.Deprecated('Use e2EEMetaDescriptor instead')
const E2EEMeta$json = {
  '1': 'E2EEMeta',
  '2': [
    {'1': 'ver', '3': 1, '4': 1, '5': 5, '10': 'ver'},
    {'1': 'suite', '3': 2, '4': 1, '5': 9, '10': 'suite'},
    {'1': 'nonce', '3': 3, '4': 1, '5': 12, '10': 'nonce'},
    {
      '1': 'keys',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.imboy.E2EEDeviceKey',
      '10': 'keys'
    },
  ],
};

/// Descriptor for `E2EEMeta`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List e2EEMetaDescriptor = $convert.base64Decode(
    'CghFMkVFTWV0YRIQCgN2ZXIYASABKAVSA3ZlchIUCgVzdWl0ZRgCIAEoCVIFc3VpdGUSFAoFbm'
    '9uY2UYAyABKAxSBW5vbmNlEigKBGtleXMYBCADKAsyFC5pbWJveS5FMkVFRGV2aWNlS2V5UgRr'
    'ZXlz');

@$core.Deprecated('Use e2EEDeviceKeyDescriptor instead')
const E2EEDeviceKey$json = {
  '1': 'E2EEDeviceKey',
  '2': [
    {'1': 'did', '3': 1, '4': 1, '5': 9, '10': 'did'},
    {'1': 'kid', '3': 2, '4': 1, '5': 9, '10': 'kid'},
    {'1': 'wrap_alg', '3': 3, '4': 1, '5': 9, '10': 'wrapAlg'},
    {'1': 'ek', '3': 4, '4': 1, '5': 12, '10': 'ek'},
  ],
};

/// Descriptor for `E2EEDeviceKey`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List e2EEDeviceKeyDescriptor = $convert.base64Decode(
    'Cg1FMkVFRGV2aWNlS2V5EhAKA2RpZBgBIAEoCVIDZGlkEhAKA2tpZBgCIAEoCVIDa2lkEhkKCH'
    'dyYXBfYWxnGAMgASgJUgd3cmFwQWxnEg4KAmVrGAQgASgMUgJlaw==');

@$core.Deprecated('Use payloadTextDescriptor instead')
const PayloadText$json = {
  '1': 'PayloadText',
  '2': [
    {'1': 'body', '3': 1, '4': 1, '5': 9, '10': 'body'},
    {'1': 'mentions', '3': 2, '4': 3, '5': 18, '10': 'mentions'},
    {
      '1': 'reply_to',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.imboy.ReplyRef',
      '10': 'replyTo'
    },
  ],
};

/// Descriptor for `PayloadText`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadTextDescriptor = $convert.base64Decode(
    'CgtQYXlsb2FkVGV4dBISCgRib2R5GAEgASgJUgRib2R5EhoKCG1lbnRpb25zGAIgAygSUghtZW'
    '50aW9ucxIqCghyZXBseV90bxgDIAEoCzIPLmltYm95LlJlcGx5UmVmUgdyZXBseVRv');

@$core.Deprecated('Use replyRefDescriptor instead')
const ReplyRef$json = {
  '1': 'ReplyRef',
  '2': [
    {'1': 'msg_id', '3': 1, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'from_id', '3': 2, '4': 1, '5': 18, '10': 'fromId'},
    {'1': 'snippet', '3': 3, '4': 1, '5': 9, '10': 'snippet'},
  ],
};

/// Descriptor for `ReplyRef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replyRefDescriptor = $convert.base64Decode(
    'CghSZXBseVJlZhIVCgZtc2dfaWQYASABKAlSBW1zZ0lkEhcKB2Zyb21faWQYAiABKBJSBmZyb2'
    '1JZBIYCgdzbmlwcGV0GAMgASgJUgdzbmlwcGV0');

@$core.Deprecated('Use payloadImageDescriptor instead')
const PayloadImage$json = {
  '1': 'PayloadImage',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'width', '3': 2, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 3, '4': 1, '5': 5, '10': 'height'},
    {'1': 'size', '3': 4, '4': 1, '5': 3, '10': 'size'},
    {'1': 'mime_type', '3': 5, '4': 1, '5': 9, '10': 'mimeType'},
    {'1': 'thumbnail_url', '3': 6, '4': 1, '5': 9, '10': 'thumbnailUrl'},
    {'1': 'thumbnail_width', '3': 7, '4': 1, '5': 5, '10': 'thumbnailWidth'},
    {'1': 'thumbnail_height', '3': 8, '4': 1, '5': 5, '10': 'thumbnailHeight'},
  ],
};

/// Descriptor for `PayloadImage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadImageDescriptor = $convert.base64Decode(
    'CgxQYXlsb2FkSW1hZ2USEAoDdXJsGAEgASgJUgN1cmwSFAoFd2lkdGgYAiABKAVSBXdpZHRoEh'
    'YKBmhlaWdodBgDIAEoBVIGaGVpZ2h0EhIKBHNpemUYBCABKANSBHNpemUSGwoJbWltZV90eXBl'
    'GAUgASgJUghtaW1lVHlwZRIjCg10aHVtYm5haWxfdXJsGAYgASgJUgx0aHVtYm5haWxVcmwSJw'
    'oPdGh1bWJuYWlsX3dpZHRoGAcgASgFUg50aHVtYm5haWxXaWR0aBIpChB0aHVtYm5haWxfaGVp'
    'Z2h0GAggASgFUg90aHVtYm5haWxIZWlnaHQ=');

@$core.Deprecated('Use payloadVideoDescriptor instead')
const PayloadVideo$json = {
  '1': 'PayloadVideo',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'width', '3': 2, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 3, '4': 1, '5': 5, '10': 'height'},
    {'1': 'size', '3': 4, '4': 1, '5': 3, '10': 'size'},
    {'1': 'duration', '3': 5, '4': 1, '5': 5, '10': 'duration'},
    {'1': 'mime_type', '3': 6, '4': 1, '5': 9, '10': 'mimeType'},
    {'1': 'thumbnail_url', '3': 7, '4': 1, '5': 9, '10': 'thumbnailUrl'},
  ],
};

/// Descriptor for `PayloadVideo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadVideoDescriptor = $convert.base64Decode(
    'CgxQYXlsb2FkVmlkZW8SEAoDdXJsGAEgASgJUgN1cmwSFAoFd2lkdGgYAiABKAVSBXdpZHRoEh'
    'YKBmhlaWdodBgDIAEoBVIGaGVpZ2h0EhIKBHNpemUYBCABKANSBHNpemUSGgoIZHVyYXRpb24Y'
    'BSABKAVSCGR1cmF0aW9uEhsKCW1pbWVfdHlwZRgGIAEoCVIIbWltZVR5cGUSIwoNdGh1bWJuYW'
    'lsX3VybBgHIAEoCVIMdGh1bWJuYWlsVXJs');

@$core.Deprecated('Use payloadAudioDescriptor instead')
const PayloadAudio$json = {
  '1': 'PayloadAudio',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'size', '3': 2, '4': 1, '5': 3, '10': 'size'},
    {'1': 'duration', '3': 3, '4': 1, '5': 5, '10': 'duration'},
    {'1': 'mime_type', '3': 4, '4': 1, '5': 9, '10': 'mimeType'},
    {'1': 'waveform', '3': 5, '4': 3, '5': 5, '10': 'waveform'},
  ],
};

/// Descriptor for `PayloadAudio`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadAudioDescriptor = $convert.base64Decode(
    'CgxQYXlsb2FkQXVkaW8SEAoDdXJsGAEgASgJUgN1cmwSEgoEc2l6ZRgCIAEoA1IEc2l6ZRIaCg'
    'hkdXJhdGlvbhgDIAEoBVIIZHVyYXRpb24SGwoJbWltZV90eXBlGAQgASgJUghtaW1lVHlwZRIa'
    'Cgh3YXZlZm9ybRgFIAMoBVIId2F2ZWZvcm0=');

@$core.Deprecated('Use payloadFileDescriptor instead')
const PayloadFile$json = {
  '1': 'PayloadFile',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'filename', '3': 2, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'size', '3': 3, '4': 1, '5': 3, '10': 'size'},
    {'1': 'mime_type', '3': 4, '4': 1, '5': 9, '10': 'mimeType'},
  ],
};

/// Descriptor for `PayloadFile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadFileDescriptor = $convert.base64Decode(
    'CgtQYXlsb2FkRmlsZRIQCgN1cmwYASABKAlSA3VybBIaCghmaWxlbmFtZRgCIAEoCVIIZmlsZW'
    '5hbWUSEgoEc2l6ZRgDIAEoA1IEc2l6ZRIbCgltaW1lX3R5cGUYBCABKAlSCG1pbWVUeXBl');

@$core.Deprecated('Use payloadLocationDescriptor instead')
const PayloadLocation$json = {
  '1': 'PayloadLocation',
  '2': [
    {'1': 'latitude', '3': 1, '4': 1, '5': 1, '10': 'latitude'},
    {'1': 'longitude', '3': 2, '4': 1, '5': 1, '10': 'longitude'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'address', '3': 4, '4': 1, '5': 9, '10': 'address'},
  ],
};

/// Descriptor for `PayloadLocation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadLocationDescriptor = $convert.base64Decode(
    'Cg9QYXlsb2FkTG9jYXRpb24SGgoIbGF0aXR1ZGUYASABKAFSCGxhdGl0dWRlEhwKCWxvbmdpdH'
    'VkZRgCIAEoAVIJbG9uZ2l0dWRlEhQKBXRpdGxlGAMgASgJUgV0aXRsZRIYCgdhZGRyZXNzGAQg'
    'ASgJUgdhZGRyZXNz');

@$core.Deprecated('Use payloadRevokeDescriptor instead')
const PayloadRevoke$json = {
  '1': 'PayloadRevoke',
  '2': [
    {'1': 'original_msg_id', '3': 1, '4': 1, '5': 9, '10': 'originalMsgId'},
    {'1': 'revoked_at', '3': 2, '4': 1, '5': 3, '10': 'revokedAt'},
  ],
};

/// Descriptor for `PayloadRevoke`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadRevokeDescriptor = $convert.base64Decode(
    'Cg1QYXlsb2FkUmV2b2tlEiYKD29yaWdpbmFsX21zZ19pZBgBIAEoCVINb3JpZ2luYWxNc2dJZB'
    'IdCgpyZXZva2VkX2F0GAIgASgDUglyZXZva2VkQXQ=');

@$core.Deprecated('Use payloadEditDescriptor instead')
const PayloadEdit$json = {
  '1': 'PayloadEdit',
  '2': [
    {'1': 'original_msg_id', '3': 1, '4': 1, '5': 9, '10': 'originalMsgId'},
    {'1': 'body', '3': 2, '4': 1, '5': 9, '10': 'body'},
    {'1': 'edited_at', '3': 3, '4': 1, '5': 3, '10': 'editedAt'},
  ],
};

/// Descriptor for `PayloadEdit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadEditDescriptor = $convert.base64Decode(
    'CgtQYXlsb2FkRWRpdBImCg9vcmlnaW5hbF9tc2dfaWQYASABKAlSDW9yaWdpbmFsTXNnSWQSEg'
    'oEYm9keRgCIAEoCVIEYm9keRIbCgllZGl0ZWRfYXQYAyABKANSCGVkaXRlZEF0');

@$core.Deprecated('Use payloadReadDescriptor instead')
const PayloadRead$json = {
  '1': 'PayloadRead',
  '2': [
    {'1': 'original_msg_id', '3': 1, '4': 1, '5': 9, '10': 'originalMsgId'},
    {'1': 'read_at', '3': 2, '4': 1, '5': 3, '10': 'readAt'},
  ],
};

/// Descriptor for `PayloadRead`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadReadDescriptor = $convert.base64Decode(
    'CgtQYXlsb2FkUmVhZBImCg9vcmlnaW5hbF9tc2dfaWQYASABKAlSDW9yaWdpbmFsTXNnSWQSFw'
    'oHcmVhZF9hdBgCIAEoA1IGcmVhZEF0');

@$core.Deprecated('Use payloadRefreshTokenDescriptor instead')
const PayloadRefreshToken$json = {
  '1': 'PayloadRefreshToken',
  '2': [
    {'1': 'expire_at', '3': 1, '4': 1, '5': 3, '10': 'expireAt'},
  ],
};

/// Descriptor for `PayloadRefreshToken`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadRefreshTokenDescriptor =
    $convert.base64Decode(
        'ChNQYXlsb2FkUmVmcmVzaFRva2VuEhsKCWV4cGlyZV9hdBgBIAEoA1IIZXhwaXJlQXQ=');

@$core.Deprecated('Use payloadAppUpgradeDescriptor instead')
const PayloadAppUpgrade$json = {
  '1': 'PayloadAppUpgrade',
  '2': [
    {'1': 'upgrade_type', '3': 1, '4': 1, '5': 9, '10': 'upgradeType'},
    {'1': 'vsn', '3': 2, '4': 1, '5': 9, '10': 'vsn'},
    {'1': 'download_url', '3': 3, '4': 1, '5': 9, '10': 'downloadUrl'},
    {'1': 'description', '3': 4, '4': 1, '5': 9, '10': 'description'},
    {'1': 'changelog', '3': 5, '4': 3, '5': 9, '10': 'changelog'},
    {'1': 'file_size', '3': 6, '4': 1, '5': 3, '10': 'fileSize'},
    {'1': 'file_hash', '3': 7, '4': 1, '5': 9, '10': 'fileHash'},
  ],
};

/// Descriptor for `PayloadAppUpgrade`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadAppUpgradeDescriptor = $convert.base64Decode(
    'ChFQYXlsb2FkQXBwVXBncmFkZRIhCgx1cGdyYWRlX3R5cGUYASABKAlSC3VwZ3JhZGVUeXBlEh'
    'AKA3ZzbhgCIAEoCVIDdnNuEiEKDGRvd25sb2FkX3VybBgDIAEoCVILZG93bmxvYWRVcmwSIAoL'
    'ZGVzY3JpcHRpb24YBCABKAlSC2Rlc2NyaXB0aW9uEhwKCWNoYW5nZWxvZxgFIAMoCVIJY2hhbm'
    'dlbG9nEhsKCWZpbGVfc2l6ZRgGIAEoA1IIZmlsZVNpemUSGwoJZmlsZV9oYXNoGAcgASgJUghm'
    'aWxlSGFzaA==');

@$core.Deprecated('Use payloadDeviceKickedDescriptor instead')
const PayloadDeviceKicked$json = {
  '1': 'PayloadDeviceKicked',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `PayloadDeviceKicked`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadDeviceKickedDescriptor =
    $convert.base64Decode(
        'ChNQYXlsb2FkRGV2aWNlS2lja2VkEhYKBnJlYXNvbhgBIAEoCVIGcmVhc29u');

@$core.Deprecated('Use payloadLoggedAnotherDeviceDescriptor instead')
const PayloadLoggedAnotherDevice$json = {
  '1': 'PayloadLoggedAnotherDevice',
  '2': [
    {'1': 'did', '3': 1, '4': 1, '5': 9, '10': 'did'},
    {'1': 'dname', '3': 2, '4': 1, '5': 9, '10': 'dname'},
  ],
};

/// Descriptor for `PayloadLoggedAnotherDevice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadLoggedAnotherDeviceDescriptor =
    $convert.base64Decode(
        'ChpQYXlsb2FkTG9nZ2VkQW5vdGhlckRldmljZRIQCgNkaWQYASABKAlSA2RpZBIUCgVkbmFtZR'
        'gCIAEoCVIFZG5hbWU=');

@$core.Deprecated('Use payloadMsgDeletedDescriptor instead')
const PayloadMsgDeleted$json = {
  '1': 'PayloadMsgDeleted',
  '2': [
    {'1': 'old_msg_id', '3': 1, '4': 1, '5': 9, '10': 'oldMsgId'},
  ],
};

/// Descriptor for `PayloadMsgDeleted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadMsgDeletedDescriptor = $convert.base64Decode(
    'ChFQYXlsb2FkTXNnRGVsZXRlZBIcCgpvbGRfbXNnX2lkGAEgASgJUghvbGRNc2dJZA==');

@$core.Deprecated('Use payloadSyncDescriptor instead')
const PayloadSync$json = {
  '1': 'PayloadSync',
  '2': [
    {
      '1': 'cursors',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.imboy.SyncCursor',
      '10': 'cursors'
    },
    {'1': 'limit', '3': 2, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `PayloadSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadSyncDescriptor = $convert.base64Decode(
    'CgtQYXlsb2FkU3luYxIrCgdjdXJzb3JzGAEgAygLMhEuaW1ib3kuU3luY0N1cnNvclIHY3Vyc2'
    '9ycxIUCgVsaW1pdBgCIAEoBVIFbGltaXQ=');

@$core.Deprecated('Use syncCursorDescriptor instead')
const SyncCursor$json = {
  '1': 'SyncCursor',
  '2': [
    {'1': 'conv_key', '3': 1, '4': 1, '5': 9, '10': 'convKey'},
    {'1': 'last_conv_seq', '3': 2, '4': 1, '5': 3, '10': 'lastConvSeq'},
  ],
};

/// Descriptor for `SyncCursor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncCursorDescriptor = $convert.base64Decode(
    'CgpTeW5jQ3Vyc29yEhkKCGNvbnZfa2V5GAEgASgJUgdjb252S2V5EiIKDWxhc3RfY29udl9zZX'
    'EYAiABKANSC2xhc3RDb252U2Vx');

@$core.Deprecated('Use payloadSyncResultDescriptor instead')
const PayloadSyncResult$json = {
  '1': 'PayloadSyncResult',
  '2': [
    {
      '1': 'messages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.imboy.IMBoyMessage',
      '10': 'messages'
    },
    {'1': 'has_more', '3': 2, '4': 1, '5': 8, '10': 'hasMore'},
  ],
};

/// Descriptor for `PayloadSyncResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadSyncResultDescriptor = $convert.base64Decode(
    'ChFQYXlsb2FkU3luY1Jlc3VsdBIvCghtZXNzYWdlcxgBIAMoCzITLmltYm95LklNQm95TWVzc2'
    'FnZVIIbWVzc2FnZXMSGQoIaGFzX21vcmUYAiABKAhSB2hhc01vcmU=');

@$core.Deprecated('Use payloadClientAckDescriptor instead')
const PayloadClientAck$json = {
  '1': 'PayloadClientAck',
  '2': [
    {
      '1': 'msg_direction',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.imboy.MsgDirection',
      '10': 'msgDirection'
    },
    {'1': 'msg_id', '3': 2, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'did', '3': 3, '4': 1, '5': 9, '10': 'did'},
  ],
};

/// Descriptor for `PayloadClientAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadClientAckDescriptor = $convert.base64Decode(
    'ChBQYXlsb2FkQ2xpZW50QWNrEjgKDW1zZ19kaXJlY3Rpb24YASABKA4yEy5pbWJveS5Nc2dEaX'
    'JlY3Rpb25SDG1zZ0RpcmVjdGlvbhIVCgZtc2dfaWQYAiABKAlSBW1zZ0lkEhAKA2RpZBgDIAEo'
    'CVIDZGlk');

@$core.Deprecated('Use payloadClientAckConfirmDescriptor instead')
const PayloadClientAckConfirm$json = {
  '1': 'PayloadClientAckConfirm',
  '2': [
    {'1': 'msg_id', '3': 1, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'server_ts', '3': 2, '4': 1, '5': 3, '10': 'serverTs'},
  ],
};

/// Descriptor for `PayloadClientAckConfirm`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadClientAckConfirmDescriptor =
    $convert.base64Decode(
        'ChdQYXlsb2FkQ2xpZW50QWNrQ29uZmlybRIVCgZtc2dfaWQYASABKAlSBW1zZ0lkEhsKCXNlcn'
        'Zlcl90cxgCIAEoA1IIc2VydmVyVHM=');

@$core.Deprecated('Use payloadWebRTCOfferDescriptor instead')
const PayloadWebRTCOffer$json = {
  '1': 'PayloadWebRTCOffer',
  '2': [
    {'1': 'sdp', '3': 1, '4': 1, '5': 9, '10': 'sdp'},
    {'1': 'call_id', '3': 2, '4': 1, '5': 9, '10': 'callId'},
    {'1': 'media_type', '3': 3, '4': 1, '5': 9, '10': 'mediaType'},
  ],
};

/// Descriptor for `PayloadWebRTCOffer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadWebRTCOfferDescriptor = $convert.base64Decode(
    'ChJQYXlsb2FkV2ViUlRDT2ZmZXISEAoDc2RwGAEgASgJUgNzZHASFwoHY2FsbF9pZBgCIAEoCV'
    'IGY2FsbElkEh0KCm1lZGlhX3R5cGUYAyABKAlSCW1lZGlhVHlwZQ==');

@$core.Deprecated('Use payloadWebRTCAnswerDescriptor instead')
const PayloadWebRTCAnswer$json = {
  '1': 'PayloadWebRTCAnswer',
  '2': [
    {'1': 'sdp', '3': 1, '4': 1, '5': 9, '10': 'sdp'},
    {'1': 'call_id', '3': 2, '4': 1, '5': 9, '10': 'callId'},
  ],
};

/// Descriptor for `PayloadWebRTCAnswer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadWebRTCAnswerDescriptor = $convert.base64Decode(
    'ChNQYXlsb2FkV2ViUlRDQW5zd2VyEhAKA3NkcBgBIAEoCVIDc2RwEhcKB2NhbGxfaWQYAiABKA'
    'lSBmNhbGxJZA==');

@$core.Deprecated('Use payloadWebRTCCandidateDescriptor instead')
const PayloadWebRTCCandidate$json = {
  '1': 'PayloadWebRTCCandidate',
  '2': [
    {'1': 'candidate', '3': 1, '4': 1, '5': 9, '10': 'candidate'},
    {'1': 'sdp_mid', '3': 2, '4': 1, '5': 9, '10': 'sdpMid'},
    {'1': 'sdp_m_line_index', '3': 3, '4': 1, '5': 5, '10': 'sdpMLineIndex'},
    {'1': 'call_id', '3': 4, '4': 1, '5': 9, '10': 'callId'},
  ],
};

/// Descriptor for `PayloadWebRTCCandidate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadWebRTCCandidateDescriptor = $convert.base64Decode(
    'ChZQYXlsb2FkV2ViUlRDQ2FuZGlkYXRlEhwKCWNhbmRpZGF0ZRgBIAEoCVIJY2FuZGlkYXRlEh'
    'cKB3NkcF9taWQYAiABKAlSBnNkcE1pZBInChBzZHBfbV9saW5lX2luZGV4GAMgASgFUg1zZHBN'
    'TGluZUluZGV4EhcKB2NhbGxfaWQYBCABKAlSBmNhbGxJZA==');

@$core.Deprecated('Use payloadWebRTCByeDescriptor instead')
const PayloadWebRTCBye$json = {
  '1': 'PayloadWebRTCBye',
  '2': [
    {'1': 'call_id', '3': 1, '4': 1, '5': 9, '10': 'callId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `PayloadWebRTCBye`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadWebRTCByeDescriptor = $convert.base64Decode(
    'ChBQYXlsb2FkV2ViUlRDQnllEhcKB2NhbGxfaWQYASABKAlSBmNhbGxJZBIWCgZyZWFzb24YAi'
    'ABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use iMBoyBatchDescriptor instead')
const IMBoyBatch$json = {
  '1': 'IMBoyBatch',
  '2': [
    {
      '1': 'messages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.imboy.IMBoyMessage',
      '10': 'messages'
    },
  ],
};

/// Descriptor for `IMBoyBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iMBoyBatchDescriptor = $convert.base64Decode(
    'CgpJTUJveUJhdGNoEi8KCG1lc3NhZ2VzGAEgAygLMhMuaW1ib3kuSU1Cb3lNZXNzYWdlUghtZX'
    'NzYWdlcw==');
