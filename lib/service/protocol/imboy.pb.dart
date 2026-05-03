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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'imboy.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'imboy.pbenum.dart';

/// IMBoyMessage is the single entry point for all WebSocket binary frames.
/// Both client and server send/receive this message type exclusively.
class IMBoyMessage extends $pb.GeneratedMessage {
  factory IMBoyMessage({
    $core.String? id,
    MsgDirection? type,
    $fixnum.Int64? from,
    $fixnum.Int64? to,
    ContentType? msgType,
    $core.String? action,
    E2EEMeta? e2ee,
    $core.List<$core.int>? payload,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? serverTs,
    $core.int? expireSecs,
    $fixnum.Int64? convSeq,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (type != null) result.type = type;
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    if (msgType != null) result.msgType = msgType;
    if (action != null) result.action = action;
    if (e2ee != null) result.e2ee = e2ee;
    if (payload != null) result.payload = payload;
    if (createdAt != null) result.createdAt = createdAt;
    if (serverTs != null) result.serverTs = serverTs;
    if (expireSecs != null) result.expireSecs = expireSecs;
    if (convSeq != null) result.convSeq = convSeq;
    return result;
  }

  IMBoyMessage._();

  factory IMBoyMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IMBoyMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IMBoyMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aE<MsgDirection>(2, _omitFieldNames ? '' : 'type',
        enumValues: MsgDirection.values)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'from', $pb.PbFieldType.OS6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'to', $pb.PbFieldType.OS6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<ContentType>(5, _omitFieldNames ? '' : 'msgType',
        enumValues: ContentType.values)
    ..aOS(6, _omitFieldNames ? '' : 'action')
    ..aOM<E2EEMeta>(7, _omitFieldNames ? '' : 'e2ee',
        subBuilder: E2EEMeta.create)
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aInt64(9, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(10, _omitFieldNames ? '' : 'serverTs')
    ..aI(11, _omitFieldNames ? '' : 'expireSecs')
    ..aInt64(12, _omitFieldNames ? '' : 'convSeq')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IMBoyMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IMBoyMessage copyWith(void Function(IMBoyMessage) updates) =>
      super.copyWith((message) => updates(message as IMBoyMessage))
          as IMBoyMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IMBoyMessage create() => IMBoyMessage._();
  @$core.override
  IMBoyMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IMBoyMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IMBoyMessage>(create);
  static IMBoyMessage? _defaultInstance;

  /// Unique message identifier (TSID)
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// Message direction / channel
  @$pb.TagNumber(2)
  MsgDirection get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(MsgDirection value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  /// Sender UID (TSID as sint64, 0 for server-originated)
  @$pb.TagNumber(3)
  $fixnum.Int64 get from => $_getI64(2);
  @$pb.TagNumber(3)
  set from($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrom() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrom() => $_clearField(3);

  /// Recipient UID or Group ID (TSID as sint64)
  @$pb.TagNumber(4)
  $fixnum.Int64 get to => $_getI64(3);
  @$pb.TagNumber(4)
  set to($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTo() => $_has(3);
  @$pb.TagNumber(4)
  void clearTo() => $_clearField(4);

  /// Content type of the payload
  @$pb.TagNumber(5)
  ContentType get msgType => $_getN(4);
  @$pb.TagNumber(5)
  set msgType(ContentType value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasMsgType() => $_has(4);
  @$pb.TagNumber(5)
  void clearMsgType() => $_clearField(5);

  /// Action for message operations (revoke, edit, read, etc.)
  /// Empty string means normal message (no action)
  @$pb.TagNumber(6)
  $core.String get action => $_getSZ(5);
  @$pb.TagNumber(6)
  set action($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAction() => $_has(5);
  @$pb.TagNumber(6)
  void clearAction() => $_clearField(6);

  /// End-to-end encryption metadata (null/absent if not encrypted)
  @$pb.TagNumber(7)
  E2EEMeta get e2ee => $_getN(6);
  @$pb.TagNumber(7)
  set e2ee(E2EEMeta value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasE2ee() => $_has(6);
  @$pb.TagNumber(7)
  void clearE2ee() => $_clearField(7);
  @$pb.TagNumber(7)
  E2EEMeta ensureE2ee() => $_ensure(6);

  /// Message payload - varies by msg_type, see PayloadXxx messages
  @$pb.TagNumber(8)
  $core.List<$core.int> get payload => $_getN(7);
  @$pb.TagNumber(8)
  set payload($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPayload() => $_has(7);
  @$pb.TagNumber(8)
  void clearPayload() => $_clearField(8);

  /// Client-side creation time (business time only, NOT authoritative for ordering)
  /// RFC3339 string in current JSON protocol, here as millisecond timestamp
  @$pb.TagNumber(9)
  $fixnum.Int64 get createdAt => $_getI64(8);
  @$pb.TagNumber(9)
  set createdAt($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCreatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreatedAt() => $_clearField(9);

  /// Server-assigned timestamp (authoritative for ordering)
  /// Only present in server-to-client messages
  @$pb.TagNumber(10)
  $fixnum.Int64 get serverTs => $_getI64(9);
  @$pb.TagNumber(10)
  set serverTs($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasServerTs() => $_has(9);
  @$pb.TagNumber(10)
  void clearServerTs() => $_clearField(10);

  /// Message self-destruct timer in seconds (0 = no expiry)
  @$pb.TagNumber(11)
  $core.int get expireSecs => $_getIZ(10);
  @$pb.TagNumber(11)
  set expireSecs($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasExpireSecs() => $_has(10);
  @$pb.TagNumber(11)
  void clearExpireSecs() => $_clearField(11);

  /// Conversation sequence number (for strict ordering in history sync)
  /// Only present in archived/synced messages
  @$pb.TagNumber(12)
  $fixnum.Int64 get convSeq => $_getI64(11);
  @$pb.TagNumber(12)
  set convSeq($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasConvSeq() => $_has(11);
  @$pb.TagNumber(12)
  void clearConvSeq() => $_clearField(12);
}

/// E2EE metadata attached to encrypted messages
class E2EEMeta extends $pb.GeneratedMessage {
  factory E2EEMeta({
    $core.int? ver,
    $core.String? suite,
    $core.List<$core.int>? nonce,
    $core.Iterable<E2EEDeviceKey>? keys,
  }) {
    final result = create();
    if (ver != null) result.ver = ver;
    if (suite != null) result.suite = suite;
    if (nonce != null) result.nonce = nonce;
    if (keys != null) result.keys.addAll(keys);
    return result;
  }

  E2EEMeta._();

  factory E2EEMeta.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory E2EEMeta.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'E2EEMeta',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'ver')
    ..aOS(2, _omitFieldNames ? '' : 'suite')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OY)
    ..pPM<E2EEDeviceKey>(4, _omitFieldNames ? '' : 'keys',
        subBuilder: E2EEDeviceKey.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  E2EEMeta clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  E2EEMeta copyWith(void Function(E2EEMeta) updates) =>
      super.copyWith((message) => updates(message as E2EEMeta)) as E2EEMeta;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static E2EEMeta create() => E2EEMeta._();
  @$core.override
  E2EEMeta createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static E2EEMeta getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<E2EEMeta>(create);
  static E2EEMeta? _defaultInstance;

  /// E2EE protocol version
  @$pb.TagNumber(1)
  $core.int get ver => $_getIZ(0);
  @$pb.TagNumber(1)
  set ver($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVer() => $_has(0);
  @$pb.TagNumber(1)
  void clearVer() => $_clearField(1);

  /// Cipher suite identifier, e.g. "RSA-OAEP-256+AES-256-GCM"
  @$pb.TagNumber(2)
  $core.String get suite => $_getSZ(1);
  @$pb.TagNumber(2)
  set suite($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuite() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuite() => $_clearField(2);

  /// Nonce/IV for the symmetric cipher (base64-encoded in JSON, raw bytes here)
  @$pb.TagNumber(3)
  $core.List<$core.int> get nonce => $_getN(2);
  @$pb.TagNumber(3)
  set nonce($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNonce() => $_has(2);
  @$pb.TagNumber(3)
  void clearNonce() => $_clearField(3);

  /// Per-device encrypted symmetric keys
  @$pb.TagNumber(4)
  $pb.PbList<E2EEDeviceKey> get keys => $_getList(3);
}

/// Per-device wrapped key for E2EE
class E2EEDeviceKey extends $pb.GeneratedMessage {
  factory E2EEDeviceKey({
    $core.String? did,
    $core.String? kid,
    $core.String? wrapAlg,
    $core.List<$core.int>? ek,
  }) {
    final result = create();
    if (did != null) result.did = did;
    if (kid != null) result.kid = kid;
    if (wrapAlg != null) result.wrapAlg = wrapAlg;
    if (ek != null) result.ek = ek;
    return result;
  }

  E2EEDeviceKey._();

  factory E2EEDeviceKey.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory E2EEDeviceKey.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'E2EEDeviceKey',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'did')
    ..aOS(2, _omitFieldNames ? '' : 'kid')
    ..aOS(3, _omitFieldNames ? '' : 'wrapAlg')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'ek', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  E2EEDeviceKey clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  E2EEDeviceKey copyWith(void Function(E2EEDeviceKey) updates) =>
      super.copyWith((message) => updates(message as E2EEDeviceKey))
          as E2EEDeviceKey;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static E2EEDeviceKey create() => E2EEDeviceKey._();
  @$core.override
  E2EEDeviceKey createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static E2EEDeviceKey getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<E2EEDeviceKey>(create);
  static E2EEDeviceKey? _defaultInstance;

  /// Device ID
  @$pb.TagNumber(1)
  $core.String get did => $_getSZ(0);
  @$pb.TagNumber(1)
  set did($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDid() => $_has(0);
  @$pb.TagNumber(1)
  void clearDid() => $_clearField(1);

  /// Key ID (public key fingerprint)
  @$pb.TagNumber(2)
  $core.String get kid => $_getSZ(1);
  @$pb.TagNumber(2)
  set kid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKid() => $_has(1);
  @$pb.TagNumber(2)
  void clearKid() => $_clearField(2);

  /// Key wrapping algorithm, e.g. "RSA-OAEP-256"
  @$pb.TagNumber(3)
  $core.String get wrapAlg => $_getSZ(2);
  @$pb.TagNumber(3)
  set wrapAlg($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWrapAlg() => $_has(2);
  @$pb.TagNumber(3)
  void clearWrapAlg() => $_clearField(3);

  /// Encrypted symmetric key (base64-encoded in JSON, raw bytes here)
  @$pb.TagNumber(4)
  $core.List<$core.int> get ek => $_getN(3);
  @$pb.TagNumber(4)
  set ek($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEk() => $_has(3);
  @$pb.TagNumber(4)
  void clearEk() => $_clearField(4);
}

/// --- Text Message ---
class PayloadText extends $pb.GeneratedMessage {
  factory PayloadText({
    $core.String? body,
    $core.Iterable<$fixnum.Int64>? mentions,
    ReplyRef? replyTo,
  }) {
    final result = create();
    if (body != null) result.body = body;
    if (mentions != null) result.mentions.addAll(mentions);
    if (replyTo != null) result.replyTo = replyTo;
    return result;
  }

  PayloadText._();

  factory PayloadText.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadText.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadText',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'body')
    ..p<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'mentions', $pb.PbFieldType.KS6)
    ..aOM<ReplyRef>(3, _omitFieldNames ? '' : 'replyTo',
        subBuilder: ReplyRef.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadText clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadText copyWith(void Function(PayloadText) updates) =>
      super.copyWith((message) => updates(message as PayloadText))
          as PayloadText;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadText create() => PayloadText._();
  @$core.override
  PayloadText createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadText getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadText>(create);
  static PayloadText? _defaultInstance;

  /// Message body text
  @$pb.TagNumber(1)
  $core.String get body => $_getSZ(0);
  @$pb.TagNumber(1)
  set body($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBody() => $_has(0);
  @$pb.TagNumber(1)
  void clearBody() => $_clearField(1);

  /// @mentioned user UIDs (TSID)
  @$pb.TagNumber(2)
  $pb.PbList<$fixnum.Int64> get mentions => $_getList(1);

  /// Reply-to reference (optional)
  @$pb.TagNumber(3)
  ReplyRef get replyTo => $_getN(2);
  @$pb.TagNumber(3)
  set replyTo(ReplyRef value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasReplyTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearReplyTo() => $_clearField(3);
  @$pb.TagNumber(3)
  ReplyRef ensureReplyTo() => $_ensure(2);
}

/// Reference to a message being replied to
class ReplyRef extends $pb.GeneratedMessage {
  factory ReplyRef({
    $core.String? msgId,
    $fixnum.Int64? fromId,
    $core.String? snippet,
  }) {
    final result = create();
    if (msgId != null) result.msgId = msgId;
    if (fromId != null) result.fromId = fromId;
    if (snippet != null) result.snippet = snippet;
    return result;
  }

  ReplyRef._();

  factory ReplyRef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReplyRef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReplyRef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'msgId')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'fromId', $pb.PbFieldType.OS6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'snippet')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplyRef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplyRef copyWith(void Function(ReplyRef) updates) =>
      super.copyWith((message) => updates(message as ReplyRef)) as ReplyRef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReplyRef create() => ReplyRef._();
  @$core.override
  ReplyRef createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReplyRef getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReplyRef>(create);
  static ReplyRef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get msgId => $_getSZ(0);
  @$pb.TagNumber(1)
  set msgId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMsgId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsgId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get fromId => $_getI64(1);
  @$pb.TagNumber(2)
  set fromId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFromId() => $_has(1);
  @$pb.TagNumber(2)
  void clearFromId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get snippet => $_getSZ(2);
  @$pb.TagNumber(3)
  set snippet($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSnippet() => $_has(2);
  @$pb.TagNumber(3)
  void clearSnippet() => $_clearField(3);
}

/// --- Image Message ---
class PayloadImage extends $pb.GeneratedMessage {
  factory PayloadImage({
    $core.String? url,
    $core.int? width,
    $core.int? height,
    $fixnum.Int64? size,
    $core.String? mimeType,
    $core.String? thumbnailUrl,
    $core.int? thumbnailWidth,
    $core.int? thumbnailHeight,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (size != null) result.size = size;
    if (mimeType != null) result.mimeType = mimeType;
    if (thumbnailUrl != null) result.thumbnailUrl = thumbnailUrl;
    if (thumbnailWidth != null) result.thumbnailWidth = thumbnailWidth;
    if (thumbnailHeight != null) result.thumbnailHeight = thumbnailHeight;
    return result;
  }

  PayloadImage._();

  factory PayloadImage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadImage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadImage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aI(3, _omitFieldNames ? '' : 'height')
    ..aInt64(4, _omitFieldNames ? '' : 'size')
    ..aOS(5, _omitFieldNames ? '' : 'mimeType')
    ..aOS(6, _omitFieldNames ? '' : 'thumbnailUrl')
    ..aI(7, _omitFieldNames ? '' : 'thumbnailWidth')
    ..aI(8, _omitFieldNames ? '' : 'thumbnailHeight')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadImage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadImage copyWith(void Function(PayloadImage) updates) =>
      super.copyWith((message) => updates(message as PayloadImage))
          as PayloadImage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadImage create() => PayloadImage._();
  @$core.override
  PayloadImage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadImage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadImage>(create);
  static PayloadImage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get height => $_getIZ(2);
  @$pb.TagNumber(3)
  set height($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get mimeType => $_getSZ(4);
  @$pb.TagNumber(5)
  set mimeType($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMimeType() => $_has(4);
  @$pb.TagNumber(5)
  void clearMimeType() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get thumbnailUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set thumbnailUrl($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasThumbnailUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearThumbnailUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get thumbnailWidth => $_getIZ(6);
  @$pb.TagNumber(7)
  set thumbnailWidth($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasThumbnailWidth() => $_has(6);
  @$pb.TagNumber(7)
  void clearThumbnailWidth() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get thumbnailHeight => $_getIZ(7);
  @$pb.TagNumber(8)
  set thumbnailHeight($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasThumbnailHeight() => $_has(7);
  @$pb.TagNumber(8)
  void clearThumbnailHeight() => $_clearField(8);
}

/// --- Video Message ---
class PayloadVideo extends $pb.GeneratedMessage {
  factory PayloadVideo({
    $core.String? url,
    $core.int? width,
    $core.int? height,
    $fixnum.Int64? size,
    $core.int? duration,
    $core.String? mimeType,
    $core.String? thumbnailUrl,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (size != null) result.size = size;
    if (duration != null) result.duration = duration;
    if (mimeType != null) result.mimeType = mimeType;
    if (thumbnailUrl != null) result.thumbnailUrl = thumbnailUrl;
    return result;
  }

  PayloadVideo._();

  factory PayloadVideo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadVideo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadVideo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aI(3, _omitFieldNames ? '' : 'height')
    ..aInt64(4, _omitFieldNames ? '' : 'size')
    ..aI(5, _omitFieldNames ? '' : 'duration')
    ..aOS(6, _omitFieldNames ? '' : 'mimeType')
    ..aOS(7, _omitFieldNames ? '' : 'thumbnailUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadVideo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadVideo copyWith(void Function(PayloadVideo) updates) =>
      super.copyWith((message) => updates(message as PayloadVideo))
          as PayloadVideo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadVideo create() => PayloadVideo._();
  @$core.override
  PayloadVideo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadVideo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadVideo>(create);
  static PayloadVideo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get height => $_getIZ(2);
  @$pb.TagNumber(3)
  set height($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get duration => $_getIZ(4);
  @$pb.TagNumber(5)
  set duration($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearDuration() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get mimeType => $_getSZ(5);
  @$pb.TagNumber(6)
  set mimeType($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMimeType() => $_has(5);
  @$pb.TagNumber(6)
  void clearMimeType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get thumbnailUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set thumbnailUrl($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasThumbnailUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearThumbnailUrl() => $_clearField(7);
}

/// --- Audio Message ---
class PayloadAudio extends $pb.GeneratedMessage {
  factory PayloadAudio({
    $core.String? url,
    $fixnum.Int64? size,
    $core.int? duration,
    $core.String? mimeType,
    $core.Iterable<$core.int>? waveform,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (size != null) result.size = size;
    if (duration != null) result.duration = duration;
    if (mimeType != null) result.mimeType = mimeType;
    if (waveform != null) result.waveform.addAll(waveform);
    return result;
  }

  PayloadAudio._();

  factory PayloadAudio.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadAudio.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadAudio',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aInt64(2, _omitFieldNames ? '' : 'size')
    ..aI(3, _omitFieldNames ? '' : 'duration')
    ..aOS(4, _omitFieldNames ? '' : 'mimeType')
    ..p<$core.int>(5, _omitFieldNames ? '' : 'waveform', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadAudio clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadAudio copyWith(void Function(PayloadAudio) updates) =>
      super.copyWith((message) => updates(message as PayloadAudio))
          as PayloadAudio;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadAudio create() => PayloadAudio._();
  @$core.override
  PayloadAudio createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadAudio getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadAudio>(create);
  static PayloadAudio? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get size => $_getI64(1);
  @$pb.TagNumber(2)
  set size($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get duration => $_getIZ(2);
  @$pb.TagNumber(3)
  set duration($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDuration() => $_has(2);
  @$pb.TagNumber(3)
  void clearDuration() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get mimeType => $_getSZ(3);
  @$pb.TagNumber(4)
  set mimeType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMimeType() => $_has(3);
  @$pb.TagNumber(4)
  void clearMimeType() => $_clearField(4);

  /// Waveform data for visualization (optional)
  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get waveform => $_getList(4);
}

/// --- File Message ---
class PayloadFile extends $pb.GeneratedMessage {
  factory PayloadFile({
    $core.String? url,
    $core.String? filename,
    $fixnum.Int64? size,
    $core.String? mimeType,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (filename != null) result.filename = filename;
    if (size != null) result.size = size;
    if (mimeType != null) result.mimeType = mimeType;
    return result;
  }

  PayloadFile._();

  factory PayloadFile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadFile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadFile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aOS(2, _omitFieldNames ? '' : 'filename')
    ..aInt64(3, _omitFieldNames ? '' : 'size')
    ..aOS(4, _omitFieldNames ? '' : 'mimeType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadFile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadFile copyWith(void Function(PayloadFile) updates) =>
      super.copyWith((message) => updates(message as PayloadFile))
          as PayloadFile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadFile create() => PayloadFile._();
  @$core.override
  PayloadFile createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadFile getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadFile>(create);
  static PayloadFile? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get filename => $_getSZ(1);
  @$pb.TagNumber(2)
  set filename($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFilename() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilename() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get size => $_getI64(2);
  @$pb.TagNumber(3)
  set size($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get mimeType => $_getSZ(3);
  @$pb.TagNumber(4)
  set mimeType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMimeType() => $_has(3);
  @$pb.TagNumber(4)
  void clearMimeType() => $_clearField(4);
}

/// --- Location Message ---
class PayloadLocation extends $pb.GeneratedMessage {
  factory PayloadLocation({
    $core.double? latitude,
    $core.double? longitude,
    $core.String? title,
    $core.String? address,
  }) {
    final result = create();
    if (latitude != null) result.latitude = latitude;
    if (longitude != null) result.longitude = longitude;
    if (title != null) result.title = title;
    if (address != null) result.address = address;
    return result;
  }

  PayloadLocation._();

  factory PayloadLocation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadLocation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadLocation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'latitude')
    ..aD(2, _omitFieldNames ? '' : 'longitude')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'address')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadLocation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadLocation copyWith(void Function(PayloadLocation) updates) =>
      super.copyWith((message) => updates(message as PayloadLocation))
          as PayloadLocation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadLocation create() => PayloadLocation._();
  @$core.override
  PayloadLocation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadLocation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadLocation>(create);
  static PayloadLocation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get latitude => $_getN(0);
  @$pb.TagNumber(1)
  set latitude($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLatitude() => $_has(0);
  @$pb.TagNumber(1)
  void clearLatitude() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get longitude => $_getN(1);
  @$pb.TagNumber(2)
  set longitude($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLongitude() => $_has(1);
  @$pb.TagNumber(2)
  void clearLongitude() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get address => $_getSZ(3);
  @$pb.TagNumber(4)
  set address($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAddress() => $_has(3);
  @$pb.TagNumber(4)
  void clearAddress() => $_clearField(4);
}

/// --- Message Revoke ---
class PayloadRevoke extends $pb.GeneratedMessage {
  factory PayloadRevoke({
    $core.String? originalMsgId,
    $fixnum.Int64? revokedAt,
  }) {
    final result = create();
    if (originalMsgId != null) result.originalMsgId = originalMsgId;
    if (revokedAt != null) result.revokedAt = revokedAt;
    return result;
  }

  PayloadRevoke._();

  factory PayloadRevoke.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadRevoke.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadRevoke',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'originalMsgId')
    ..aInt64(2, _omitFieldNames ? '' : 'revokedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadRevoke clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadRevoke copyWith(void Function(PayloadRevoke) updates) =>
      super.copyWith((message) => updates(message as PayloadRevoke))
          as PayloadRevoke;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadRevoke create() => PayloadRevoke._();
  @$core.override
  PayloadRevoke createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadRevoke getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadRevoke>(create);
  static PayloadRevoke? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get originalMsgId => $_getSZ(0);
  @$pb.TagNumber(1)
  set originalMsgId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOriginalMsgId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOriginalMsgId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get revokedAt => $_getI64(1);
  @$pb.TagNumber(2)
  set revokedAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRevokedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearRevokedAt() => $_clearField(2);
}

/// --- Message Edit ---
class PayloadEdit extends $pb.GeneratedMessage {
  factory PayloadEdit({
    $core.String? originalMsgId,
    $core.String? body,
    $fixnum.Int64? editedAt,
  }) {
    final result = create();
    if (originalMsgId != null) result.originalMsgId = originalMsgId;
    if (body != null) result.body = body;
    if (editedAt != null) result.editedAt = editedAt;
    return result;
  }

  PayloadEdit._();

  factory PayloadEdit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadEdit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadEdit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'originalMsgId')
    ..aOS(2, _omitFieldNames ? '' : 'body')
    ..aInt64(3, _omitFieldNames ? '' : 'editedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadEdit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadEdit copyWith(void Function(PayloadEdit) updates) =>
      super.copyWith((message) => updates(message as PayloadEdit))
          as PayloadEdit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadEdit create() => PayloadEdit._();
  @$core.override
  PayloadEdit createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadEdit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadEdit>(create);
  static PayloadEdit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get originalMsgId => $_getSZ(0);
  @$pb.TagNumber(1)
  set originalMsgId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOriginalMsgId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOriginalMsgId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get body => $_getSZ(1);
  @$pb.TagNumber(2)
  set body($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBody() => $_has(1);
  @$pb.TagNumber(2)
  void clearBody() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get editedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set editedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEditedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearEditedAt() => $_clearField(3);
}

/// --- Message Read Receipt ---
class PayloadRead extends $pb.GeneratedMessage {
  factory PayloadRead({
    $core.String? originalMsgId,
    $fixnum.Int64? readAt,
  }) {
    final result = create();
    if (originalMsgId != null) result.originalMsgId = originalMsgId;
    if (readAt != null) result.readAt = readAt;
    return result;
  }

  PayloadRead._();

  factory PayloadRead.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadRead.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadRead',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'originalMsgId')
    ..aInt64(2, _omitFieldNames ? '' : 'readAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadRead clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadRead copyWith(void Function(PayloadRead) updates) =>
      super.copyWith((message) => updates(message as PayloadRead))
          as PayloadRead;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadRead create() => PayloadRead._();
  @$core.override
  PayloadRead createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadRead getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadRead>(create);
  static PayloadRead? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get originalMsgId => $_getSZ(0);
  @$pb.TagNumber(1)
  set originalMsgId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOriginalMsgId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOriginalMsgId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get readAt => $_getI64(1);
  @$pb.TagNumber(2)
  set readAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReadAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearReadAt() => $_clearField(2);
}

/// Token refresh notification
class PayloadRefreshToken extends $pb.GeneratedMessage {
  factory PayloadRefreshToken({
    $fixnum.Int64? expireAt,
  }) {
    final result = create();
    if (expireAt != null) result.expireAt = expireAt;
    return result;
  }

  PayloadRefreshToken._();

  factory PayloadRefreshToken.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadRefreshToken.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadRefreshToken',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'expireAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadRefreshToken clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadRefreshToken copyWith(void Function(PayloadRefreshToken) updates) =>
      super.copyWith((message) => updates(message as PayloadRefreshToken))
          as PayloadRefreshToken;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadRefreshToken create() => PayloadRefreshToken._();
  @$core.override
  PayloadRefreshToken createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadRefreshToken getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadRefreshToken>(create);
  static PayloadRefreshToken? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get expireAt => $_getI64(0);
  @$pb.TagNumber(1)
  set expireAt($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExpireAt() => $_has(0);
  @$pb.TagNumber(1)
  void clearExpireAt() => $_clearField(1);
}

/// App upgrade notification
class PayloadAppUpgrade extends $pb.GeneratedMessage {
  factory PayloadAppUpgrade({
    $core.String? upgradeType,
    $core.String? vsn,
    $core.String? downloadUrl,
    $core.String? description,
    $core.Iterable<$core.String>? changelog,
    $fixnum.Int64? fileSize,
    $core.String? fileHash,
  }) {
    final result = create();
    if (upgradeType != null) result.upgradeType = upgradeType;
    if (vsn != null) result.vsn = vsn;
    if (downloadUrl != null) result.downloadUrl = downloadUrl;
    if (description != null) result.description = description;
    if (changelog != null) result.changelog.addAll(changelog);
    if (fileSize != null) result.fileSize = fileSize;
    if (fileHash != null) result.fileHash = fileHash;
    return result;
  }

  PayloadAppUpgrade._();

  factory PayloadAppUpgrade.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadAppUpgrade.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadAppUpgrade',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'upgradeType')
    ..aOS(2, _omitFieldNames ? '' : 'vsn')
    ..aOS(3, _omitFieldNames ? '' : 'downloadUrl')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..pPS(5, _omitFieldNames ? '' : 'changelog')
    ..aInt64(6, _omitFieldNames ? '' : 'fileSize')
    ..aOS(7, _omitFieldNames ? '' : 'fileHash')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadAppUpgrade clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadAppUpgrade copyWith(void Function(PayloadAppUpgrade) updates) =>
      super.copyWith((message) => updates(message as PayloadAppUpgrade))
          as PayloadAppUpgrade;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadAppUpgrade create() => PayloadAppUpgrade._();
  @$core.override
  PayloadAppUpgrade createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadAppUpgrade getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadAppUpgrade>(create);
  static PayloadAppUpgrade? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get upgradeType => $_getSZ(0);
  @$pb.TagNumber(1)
  set upgradeType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUpgradeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpgradeType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get vsn => $_getSZ(1);
  @$pb.TagNumber(2)
  set vsn($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVsn() => $_has(1);
  @$pb.TagNumber(2)
  void clearVsn() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get downloadUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set downloadUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDownloadUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearDownloadUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get changelog => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get fileSize => $_getI64(5);
  @$pb.TagNumber(6)
  set fileSize($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFileSize() => $_has(5);
  @$pb.TagNumber(6)
  void clearFileSize() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get fileHash => $_getSZ(6);
  @$pb.TagNumber(7)
  set fileHash($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFileHash() => $_has(6);
  @$pb.TagNumber(7)
  void clearFileHash() => $_clearField(7);
}

/// Device kicked notification
class PayloadDeviceKicked extends $pb.GeneratedMessage {
  factory PayloadDeviceKicked({
    $core.String? reason,
  }) {
    final result = create();
    if (reason != null) result.reason = reason;
    return result;
  }

  PayloadDeviceKicked._();

  factory PayloadDeviceKicked.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadDeviceKicked.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadDeviceKicked',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadDeviceKicked clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadDeviceKicked copyWith(void Function(PayloadDeviceKicked) updates) =>
      super.copyWith((message) => updates(message as PayloadDeviceKicked))
          as PayloadDeviceKicked;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadDeviceKicked create() => PayloadDeviceKicked._();
  @$core.override
  PayloadDeviceKicked createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadDeviceKicked getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadDeviceKicked>(create);
  static PayloadDeviceKicked? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => $_clearField(1);
}

/// Logged in from another device notification
class PayloadLoggedAnotherDevice extends $pb.GeneratedMessage {
  factory PayloadLoggedAnotherDevice({
    $core.String? did,
    $core.String? dname,
  }) {
    final result = create();
    if (did != null) result.did = did;
    if (dname != null) result.dname = dname;
    return result;
  }

  PayloadLoggedAnotherDevice._();

  factory PayloadLoggedAnotherDevice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadLoggedAnotherDevice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadLoggedAnotherDevice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'did')
    ..aOS(2, _omitFieldNames ? '' : 'dname')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadLoggedAnotherDevice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadLoggedAnotherDevice copyWith(
          void Function(PayloadLoggedAnotherDevice) updates) =>
      super.copyWith(
              (message) => updates(message as PayloadLoggedAnotherDevice))
          as PayloadLoggedAnotherDevice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadLoggedAnotherDevice create() => PayloadLoggedAnotherDevice._();
  @$core.override
  PayloadLoggedAnotherDevice createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadLoggedAnotherDevice getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadLoggedAnotherDevice>(create);
  static PayloadLoggedAnotherDevice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get did => $_getSZ(0);
  @$pb.TagNumber(1)
  set did($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDid() => $_has(0);
  @$pb.TagNumber(1)
  void clearDid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get dname => $_getSZ(1);
  @$pb.TagNumber(2)
  set dname($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDname() => $_has(1);
  @$pb.TagNumber(2)
  void clearDname() => $_clearField(2);
}

/// Message deleted notification
class PayloadMsgDeleted extends $pb.GeneratedMessage {
  factory PayloadMsgDeleted({
    $core.String? oldMsgId,
  }) {
    final result = create();
    if (oldMsgId != null) result.oldMsgId = oldMsgId;
    return result;
  }

  PayloadMsgDeleted._();

  factory PayloadMsgDeleted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadMsgDeleted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadMsgDeleted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'oldMsgId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadMsgDeleted clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadMsgDeleted copyWith(void Function(PayloadMsgDeleted) updates) =>
      super.copyWith((message) => updates(message as PayloadMsgDeleted))
          as PayloadMsgDeleted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadMsgDeleted create() => PayloadMsgDeleted._();
  @$core.override
  PayloadMsgDeleted createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadMsgDeleted getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadMsgDeleted>(create);
  static PayloadMsgDeleted? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get oldMsgId => $_getSZ(0);
  @$pb.TagNumber(1)
  set oldMsgId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOldMsgId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOldMsgId() => $_clearField(1);
}

/// Incremental message sync request
class PayloadSync extends $pb.GeneratedMessage {
  factory PayloadSync({
    $core.Iterable<SyncCursor>? cursors,
    $core.int? limit,
  }) {
    final result = create();
    if (cursors != null) result.cursors.addAll(cursors);
    if (limit != null) result.limit = limit;
    return result;
  }

  PayloadSync._();

  factory PayloadSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..pPM<SyncCursor>(1, _omitFieldNames ? '' : 'cursors',
        subBuilder: SyncCursor.create)
    ..aI(2, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadSync copyWith(void Function(PayloadSync) updates) =>
      super.copyWith((message) => updates(message as PayloadSync))
          as PayloadSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadSync create() => PayloadSync._();
  @$core.override
  PayloadSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadSync getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadSync>(create);
  static PayloadSync? _defaultInstance;

  /// Per-conversation cursors for incremental sync
  @$pb.TagNumber(1)
  $pb.PbList<SyncCursor> get cursors => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);
}

/// Sync cursor for a single conversation
class SyncCursor extends $pb.GeneratedMessage {
  factory SyncCursor({
    $core.String? convKey,
    $fixnum.Int64? lastConvSeq,
  }) {
    final result = create();
    if (convKey != null) result.convKey = convKey;
    if (lastConvSeq != null) result.lastConvSeq = lastConvSeq;
    return result;
  }

  SyncCursor._();

  factory SyncCursor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncCursor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncCursor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'convKey')
    ..aInt64(2, _omitFieldNames ? '' : 'lastConvSeq')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncCursor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncCursor copyWith(void Function(SyncCursor) updates) =>
      super.copyWith((message) => updates(message as SyncCursor)) as SyncCursor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncCursor create() => SyncCursor._();
  @$core.override
  SyncCursor createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncCursor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncCursor>(create);
  static SyncCursor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get convKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set convKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConvKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearConvKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get lastConvSeq => $_getI64(1);
  @$pb.TagNumber(2)
  set lastConvSeq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLastConvSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearLastConvSeq() => $_clearField(2);
}

/// Sync response (server sends back as S2C)
class PayloadSyncResult extends $pb.GeneratedMessage {
  factory PayloadSyncResult({
    $core.Iterable<IMBoyMessage>? messages,
    $core.bool? hasMore,
  }) {
    final result = create();
    if (messages != null) result.messages.addAll(messages);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  PayloadSyncResult._();

  factory PayloadSyncResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadSyncResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadSyncResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..pPM<IMBoyMessage>(1, _omitFieldNames ? '' : 'messages',
        subBuilder: IMBoyMessage.create)
    ..aOB(2, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadSyncResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadSyncResult copyWith(void Function(PayloadSyncResult) updates) =>
      super.copyWith((message) => updates(message as PayloadSyncResult))
          as PayloadSyncResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadSyncResult create() => PayloadSyncResult._();
  @$core.override
  PayloadSyncResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadSyncResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadSyncResult>(create);
  static PayloadSyncResult? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<IMBoyMessage> get messages => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasMore => $_getBF(1);
  @$pb.TagNumber(2)
  set hasMore($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasMore() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasMore() => $_clearField(2);
}

/// Client acknowledgement for received messages
/// Replaces the text-based "CLIENT_ACK,{Type},{MsgId},{DID}" protocol
class PayloadClientAck extends $pb.GeneratedMessage {
  factory PayloadClientAck({
    MsgDirection? msgDirection,
    $core.String? msgId,
    $core.String? did,
  }) {
    final result = create();
    if (msgDirection != null) result.msgDirection = msgDirection;
    if (msgId != null) result.msgId = msgId;
    if (did != null) result.did = did;
    return result;
  }

  PayloadClientAck._();

  factory PayloadClientAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadClientAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadClientAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aE<MsgDirection>(1, _omitFieldNames ? '' : 'msgDirection',
        enumValues: MsgDirection.values)
    ..aOS(2, _omitFieldNames ? '' : 'msgId')
    ..aOS(3, _omitFieldNames ? '' : 'did')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadClientAck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadClientAck copyWith(void Function(PayloadClientAck) updates) =>
      super.copyWith((message) => updates(message as PayloadClientAck))
          as PayloadClientAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadClientAck create() => PayloadClientAck._();
  @$core.override
  PayloadClientAck createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadClientAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadClientAck>(create);
  static PayloadClientAck? _defaultInstance;

  @$pb.TagNumber(1)
  MsgDirection get msgDirection => $_getN(0);
  @$pb.TagNumber(1)
  set msgDirection(MsgDirection value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMsgDirection() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsgDirection() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msgId => $_getSZ(1);
  @$pb.TagNumber(2)
  set msgId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get did => $_getSZ(2);
  @$pb.TagNumber(3)
  set did($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDid() => $_has(2);
  @$pb.TagNumber(3)
  void clearDid() => $_clearField(3);
}

/// Server confirmation of client ACK
class PayloadClientAckConfirm extends $pb.GeneratedMessage {
  factory PayloadClientAckConfirm({
    $core.String? msgId,
    $fixnum.Int64? serverTs,
  }) {
    final result = create();
    if (msgId != null) result.msgId = msgId;
    if (serverTs != null) result.serverTs = serverTs;
    return result;
  }

  PayloadClientAckConfirm._();

  factory PayloadClientAckConfirm.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadClientAckConfirm.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadClientAckConfirm',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'msgId')
    ..aInt64(2, _omitFieldNames ? '' : 'serverTs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadClientAckConfirm clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadClientAckConfirm copyWith(
          void Function(PayloadClientAckConfirm) updates) =>
      super.copyWith((message) => updates(message as PayloadClientAckConfirm))
          as PayloadClientAckConfirm;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadClientAckConfirm create() => PayloadClientAckConfirm._();
  @$core.override
  PayloadClientAckConfirm createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadClientAckConfirm getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadClientAckConfirm>(create);
  static PayloadClientAckConfirm? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get msgId => $_getSZ(0);
  @$pb.TagNumber(1)
  set msgId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMsgId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsgId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get serverTs => $_getI64(1);
  @$pb.TagNumber(2)
  set serverTs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasServerTs() => $_has(1);
  @$pb.TagNumber(2)
  void clearServerTs() => $_clearField(2);
}

class PayloadWebRTCOffer extends $pb.GeneratedMessage {
  factory PayloadWebRTCOffer({
    $core.String? sdp,
    $core.String? callId,
    $core.String? mediaType,
  }) {
    final result = create();
    if (sdp != null) result.sdp = sdp;
    if (callId != null) result.callId = callId;
    if (mediaType != null) result.mediaType = mediaType;
    return result;
  }

  PayloadWebRTCOffer._();

  factory PayloadWebRTCOffer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadWebRTCOffer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadWebRTCOffer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sdp')
    ..aOS(2, _omitFieldNames ? '' : 'callId')
    ..aOS(3, _omitFieldNames ? '' : 'mediaType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadWebRTCOffer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadWebRTCOffer copyWith(void Function(PayloadWebRTCOffer) updates) =>
      super.copyWith((message) => updates(message as PayloadWebRTCOffer))
          as PayloadWebRTCOffer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadWebRTCOffer create() => PayloadWebRTCOffer._();
  @$core.override
  PayloadWebRTCOffer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadWebRTCOffer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadWebRTCOffer>(create);
  static PayloadWebRTCOffer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sdp => $_getSZ(0);
  @$pb.TagNumber(1)
  set sdp($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSdp() => $_has(0);
  @$pb.TagNumber(1)
  void clearSdp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get callId => $_getSZ(1);
  @$pb.TagNumber(2)
  set callId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCallId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCallId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get mediaType => $_getSZ(2);
  @$pb.TagNumber(3)
  set mediaType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMediaType() => $_has(2);
  @$pb.TagNumber(3)
  void clearMediaType() => $_clearField(3);
}

class PayloadWebRTCAnswer extends $pb.GeneratedMessage {
  factory PayloadWebRTCAnswer({
    $core.String? sdp,
    $core.String? callId,
  }) {
    final result = create();
    if (sdp != null) result.sdp = sdp;
    if (callId != null) result.callId = callId;
    return result;
  }

  PayloadWebRTCAnswer._();

  factory PayloadWebRTCAnswer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadWebRTCAnswer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadWebRTCAnswer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sdp')
    ..aOS(2, _omitFieldNames ? '' : 'callId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadWebRTCAnswer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadWebRTCAnswer copyWith(void Function(PayloadWebRTCAnswer) updates) =>
      super.copyWith((message) => updates(message as PayloadWebRTCAnswer))
          as PayloadWebRTCAnswer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadWebRTCAnswer create() => PayloadWebRTCAnswer._();
  @$core.override
  PayloadWebRTCAnswer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadWebRTCAnswer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadWebRTCAnswer>(create);
  static PayloadWebRTCAnswer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sdp => $_getSZ(0);
  @$pb.TagNumber(1)
  set sdp($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSdp() => $_has(0);
  @$pb.TagNumber(1)
  void clearSdp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get callId => $_getSZ(1);
  @$pb.TagNumber(2)
  set callId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCallId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCallId() => $_clearField(2);
}

class PayloadWebRTCCandidate extends $pb.GeneratedMessage {
  factory PayloadWebRTCCandidate({
    $core.String? candidate,
    $core.String? sdpMid,
    $core.int? sdpMLineIndex,
    $core.String? callId,
  }) {
    final result = create();
    if (candidate != null) result.candidate = candidate;
    if (sdpMid != null) result.sdpMid = sdpMid;
    if (sdpMLineIndex != null) result.sdpMLineIndex = sdpMLineIndex;
    if (callId != null) result.callId = callId;
    return result;
  }

  PayloadWebRTCCandidate._();

  factory PayloadWebRTCCandidate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadWebRTCCandidate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadWebRTCCandidate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'candidate')
    ..aOS(2, _omitFieldNames ? '' : 'sdpMid')
    ..aI(3, _omitFieldNames ? '' : 'sdpMLineIndex')
    ..aOS(4, _omitFieldNames ? '' : 'callId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadWebRTCCandidate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadWebRTCCandidate copyWith(
          void Function(PayloadWebRTCCandidate) updates) =>
      super.copyWith((message) => updates(message as PayloadWebRTCCandidate))
          as PayloadWebRTCCandidate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadWebRTCCandidate create() => PayloadWebRTCCandidate._();
  @$core.override
  PayloadWebRTCCandidate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadWebRTCCandidate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadWebRTCCandidate>(create);
  static PayloadWebRTCCandidate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get candidate => $_getSZ(0);
  @$pb.TagNumber(1)
  set candidate($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCandidate() => $_has(0);
  @$pb.TagNumber(1)
  void clearCandidate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sdpMid => $_getSZ(1);
  @$pb.TagNumber(2)
  set sdpMid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSdpMid() => $_has(1);
  @$pb.TagNumber(2)
  void clearSdpMid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get sdpMLineIndex => $_getIZ(2);
  @$pb.TagNumber(3)
  set sdpMLineIndex($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSdpMLineIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearSdpMLineIndex() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get callId => $_getSZ(3);
  @$pb.TagNumber(4)
  set callId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCallId() => $_has(3);
  @$pb.TagNumber(4)
  void clearCallId() => $_clearField(4);
}

class PayloadWebRTCBye extends $pb.GeneratedMessage {
  factory PayloadWebRTCBye({
    $core.String? callId,
    $core.String? reason,
  }) {
    final result = create();
    if (callId != null) result.callId = callId;
    if (reason != null) result.reason = reason;
    return result;
  }

  PayloadWebRTCBye._();

  factory PayloadWebRTCBye.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PayloadWebRTCBye.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayloadWebRTCBye',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'callId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadWebRTCBye clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayloadWebRTCBye copyWith(void Function(PayloadWebRTCBye) updates) =>
      super.copyWith((message) => updates(message as PayloadWebRTCBye))
          as PayloadWebRTCBye;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PayloadWebRTCBye create() => PayloadWebRTCBye._();
  @$core.override
  PayloadWebRTCBye createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PayloadWebRTCBye getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayloadWebRTCBye>(create);
  static PayloadWebRTCBye? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get callId => $_getSZ(0);
  @$pb.TagNumber(1)
  set callId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCallId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCallId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

/// For sending multiple messages in a single WebSocket frame
class IMBoyBatch extends $pb.GeneratedMessage {
  factory IMBoyBatch({
    $core.Iterable<IMBoyMessage>? messages,
  }) {
    final result = create();
    if (messages != null) result.messages.addAll(messages);
    return result;
  }

  IMBoyBatch._();

  factory IMBoyBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IMBoyBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IMBoyBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'imboy'),
      createEmptyInstance: create)
    ..pPM<IMBoyMessage>(1, _omitFieldNames ? '' : 'messages',
        subBuilder: IMBoyMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IMBoyBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IMBoyBatch copyWith(void Function(IMBoyBatch) updates) =>
      super.copyWith((message) => updates(message as IMBoyBatch)) as IMBoyBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IMBoyBatch create() => IMBoyBatch._();
  @$core.override
  IMBoyBatch createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IMBoyBatch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IMBoyBatch>(create);
  static IMBoyBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<IMBoyMessage> get messages => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
