// This is a generated file - do not edit.
//
// Generated from imboy.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Message direction / channel type
class MsgDirection extends $pb.ProtobufEnum {
  static const MsgDirection MSG_DIRECTION_UNSPECIFIED =
      MsgDirection._(0, _omitEnumNames ? '' : 'MSG_DIRECTION_UNSPECIFIED');
  static const MsgDirection C2C =
      MsgDirection._(1, _omitEnumNames ? '' : 'C2C');
  static const MsgDirection C2G =
      MsgDirection._(2, _omitEnumNames ? '' : 'C2G');
  static const MsgDirection C2S =
      MsgDirection._(3, _omitEnumNames ? '' : 'C2S');
  static const MsgDirection S2C =
      MsgDirection._(4, _omitEnumNames ? '' : 'S2C');
  static const MsgDirection C2CH =
      MsgDirection._(5, _omitEnumNames ? '' : 'C2CH');

  /// WebRTC signaling types
  static const MsgDirection WEBRTC_OFFER =
      MsgDirection._(10, _omitEnumNames ? '' : 'WEBRTC_OFFER');
  static const MsgDirection WEBRTC_ANSWER =
      MsgDirection._(11, _omitEnumNames ? '' : 'WEBRTC_ANSWER');
  static const MsgDirection WEBRTC_CANDIDATE =
      MsgDirection._(12, _omitEnumNames ? '' : 'WEBRTC_CANDIDATE');
  static const MsgDirection WEBRTC_BYE =
      MsgDirection._(13, _omitEnumNames ? '' : 'WEBRTC_BYE');

  /// ACK types
  static const MsgDirection C2C_SERVER_ACK =
      MsgDirection._(20, _omitEnumNames ? '' : 'C2C_SERVER_ACK');
  static const MsgDirection C2G_SERVER_ACK =
      MsgDirection._(21, _omitEnumNames ? '' : 'C2G_SERVER_ACK');
  static const MsgDirection CLIENT_ACK =
      MsgDirection._(22, _omitEnumNames ? '' : 'CLIENT_ACK');
  static const MsgDirection CLIENT_ACK_CONFIRM =
      MsgDirection._(23, _omitEnumNames ? '' : 'CLIENT_ACK_CONFIRM');
  static const MsgDirection C2CH_SERVER_ACK =
      MsgDirection._(24, _omitEnumNames ? '' : 'C2CH_SERVER_ACK');

  static const $core.List<MsgDirection> values = <MsgDirection>[
    MSG_DIRECTION_UNSPECIFIED,
    C2C,
    C2G,
    C2S,
    S2C,
    C2CH,
    WEBRTC_OFFER,
    WEBRTC_ANSWER,
    WEBRTC_CANDIDATE,
    WEBRTC_BYE,
    C2C_SERVER_ACK,
    C2G_SERVER_ACK,
    CLIENT_ACK,
    CLIENT_ACK_CONFIRM,
    C2CH_SERVER_ACK,
  ];

  static final $core.Map<$core.int, MsgDirection> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static MsgDirection? valueOf($core.int value) => _byValue[value];

  const MsgDirection._(super.value, super.name);
}

/// Content type of the message payload
class ContentType extends $pb.ProtobufEnum {
  static const ContentType CONTENT_TYPE_UNSPECIFIED =
      ContentType._(0, _omitEnumNames ? '' : 'CONTENT_TYPE_UNSPECIFIED');
  static const ContentType TEXT =
      ContentType._(1, _omitEnumNames ? '' : 'TEXT');
  static const ContentType IMAGE =
      ContentType._(2, _omitEnumNames ? '' : 'IMAGE');
  static const ContentType VIDEO =
      ContentType._(3, _omitEnumNames ? '' : 'VIDEO');
  static const ContentType AUDIO =
      ContentType._(4, _omitEnumNames ? '' : 'AUDIO');
  static const ContentType FILE =
      ContentType._(5, _omitEnumNames ? '' : 'FILE');
  static const ContentType LOCATION =
      ContentType._(6, _omitEnumNames ? '' : 'LOCATION');
  static const ContentType CUSTOM =
      ContentType._(7, _omitEnumNames ? '' : 'CUSTOM');
  static const ContentType E2EE =
      ContentType._(8, _omitEnumNames ? '' : 'E2EE');

  static const $core.List<ContentType> values = <ContentType>[
    CONTENT_TYPE_UNSPECIFIED,
    TEXT,
    IMAGE,
    VIDEO,
    AUDIO,
    FILE,
    LOCATION,
    CUSTOM,
    E2EE,
  ];

  static final $core.List<ContentType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static ContentType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ContentType._(super.value, super.name);
}

/// S2C system action types
class S2CAction extends $pb.ProtobufEnum {
  static const S2CAction S2C_ACTION_UNSPECIFIED =
      S2CAction._(0, _omitEnumNames ? '' : 'S2C_ACTION_UNSPECIFIED');
  static const S2CAction PULL_OFFLINE_MSG =
      S2CAction._(1, _omitEnumNames ? '' : 'PULL_OFFLINE_MSG');
  static const S2CAction PLEASE_REFRESH_TOKEN =
      S2CAction._(2, _omitEnumNames ? '' : 'PLEASE_REFRESH_TOKEN');
  static const S2CAction DEVICE_KICKED =
      S2CAction._(3, _omitEnumNames ? '' : 'DEVICE_KICKED');
  static const S2CAction APP_UPGRADE =
      S2CAction._(4, _omitEnumNames ? '' : 'APP_UPGRADE');
  static const S2CAction C2C_DEL_EVERYONE =
      S2CAction._(5, _omitEnumNames ? '' : 'C2C_DEL_EVERYONE');
  static const S2CAction C2G_DEL_FOR_ME =
      S2CAction._(6, _omitEnumNames ? '' : 'C2G_DEL_FOR_ME');
  static const S2CAction C2G_DEL_EVERYONE =
      S2CAction._(7, _omitEnumNames ? '' : 'C2G_DEL_EVERYONE');
  static const S2CAction STORE_SHARD =
      S2CAction._(8, _omitEnumNames ? '' : 'STORE_SHARD');
  static const S2CAction SHARD_STORED =
      S2CAction._(9, _omitEnumNames ? '' : 'SHARD_STORED');
  static const S2CAction E2EE_KEY_CHANGED_ACK =
      S2CAction._(10, _omitEnumNames ? '' : 'E2EE_KEY_CHANGED_ACK');
  static const S2CAction INVALID_MESSAGE_TYPE =
      S2CAction._(11, _omitEnumNames ? '' : 'INVALID_MESSAGE_TYPE');
  static const S2CAction POLICY_VIOLATION =
      S2CAction._(12, _omitEnumNames ? '' : 'POLICY_VIOLATION');
  static const S2CAction LOGGED_ANOTHER_DEVICE =
      S2CAction._(13, _omitEnumNames ? '' : 'LOGGED_ANOTHER_DEVICE');
  static const S2CAction C2CH_DEL_EVERYONE =
      S2CAction._(14, _omitEnumNames ? '' : 'C2CH_DEL_EVERYONE');

  static const $core.List<S2CAction> values = <S2CAction>[
    S2C_ACTION_UNSPECIFIED,
    PULL_OFFLINE_MSG,
    PLEASE_REFRESH_TOKEN,
    DEVICE_KICKED,
    APP_UPGRADE,
    C2C_DEL_EVERYONE,
    C2G_DEL_FOR_ME,
    C2G_DEL_EVERYONE,
    STORE_SHARD,
    SHARD_STORED,
    E2EE_KEY_CHANGED_ACK,
    INVALID_MESSAGE_TYPE,
    POLICY_VIOLATION,
    LOGGED_ANOTHER_DEVICE,
    C2CH_DEL_EVERYONE,
  ];

  static final $core.List<S2CAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 14);
  static S2CAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const S2CAction._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
