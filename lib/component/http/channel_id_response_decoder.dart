import 'dart:convert';

import 'package:dio/dio.dart';

/// Explicit response contracts. Do not use for other endpoints.
enum ChannelResponseShape {
  detail,
  subscribed,
  workspace,
  socket,
  unread,
  groupDetail,
  groupList,
  groupCreate,
  groupMember,
  groupWorkspace,
  groupSocket,
  trustSocket,
  deviceKeySocket,
  offline,
  contact,
  denylist,
  people,
  fts,
  messageResult,
}

/// Opt-in Dio response decoder. Set it on a JSON request for the matching
/// endpoint; ordinary requests retain Dio's normal decoder.
ResponseDecoder channelIdResponseDecoder(ChannelResponseShape shape) =>
    (List<int> bytes, RequestOptions options, ResponseBody response) {
      final decoded = utf8.decode(bytes, allowMalformed: true);
      final isJson =
          options.responseType == ResponseType.json &&
          Transformer.isJsonMimeType(
            response.headers[Headers.contentTypeHeader]?.first,
          );
      if (!isJson) return decoded;
      if (decoded.isEmpty) return null;
      return rewriteChannelIds(decoded, shape);
    };

/// Preserve raw decimal ID tokens before Dio's JSON parser can round them.
/// Only channel and creator IDs in detail and subscribed list payloads are in scope. Other values retain standard JSON decoding semantics.
String rewriteChannelIds(String source, ChannelResponseShape shape) {
  final decoded = jsonDecode(source); // Validate before scanning.
  return _Scanner(source, shape, decoded).rewrite();
}

class _Scanner {
  _Scanner(this.source, this.shape, this.decoded);
  final String source;
  final ChannelResponseShape shape;
  final dynamic decoded;
  String? offlineAction;
  final edits = <(int, int)>[];
  int pos = 0;

  String rewrite() {
    _value(const []);
    final out = StringBuffer();
    var previous = 0;
    for (final (start, end) in edits) {
      out.write(source.substring(previous, start));
      out.write('"');
      out.write(source.substring(start, end));
      out.write('"');
      previous = end;
    }
    out.write(source.substring(previous));
    return out.toString();
  }

  void _space() {
    while (pos < source.length &&
        (source.codeUnitAt(pos) == 32 ||
            source.codeUnitAt(pos) == 10 ||
            source.codeUnitAt(pos) == 13 ||
            source.codeUnitAt(pos) == 9)) {
      pos++;
    }
  }

  String _string() {
    final start = pos++;
    while (pos < source.length) {
      final c = source.codeUnitAt(pos++);
      if (c == 92) {
        pos++;
      } else if (c == 34) {
        break;
      }
    }
    return jsonDecode(source.substring(start, pos)) as String;
  }

  void _value(List<String> path) {
    _space();
    final c = source[pos];
    if (c == '{') {
      pos++;
      _space();
      if (source[pos] == '}') {
        pos++;
        return;
      }
      while (true) {
        _space();
        final key = _string();
        _space();
        pos++; // colon
        _value([...path, key]);
        _space();
        if (source[pos++] == '}') return;
      }
    } else if (c == '[') {
      pos++;
      _space();
      if (source[pos] == ']') {
        pos++;
        return;
      }
      var index = 0;
      final isOfflineList =
          shape == ChannelResponseShape.offline &&
          _matches(path, const ['payload', 's2c', 'list']);
      final dynamic payload = isOfflineList && decoded is Map
          ? decoded['payload']
          : null;
      final dynamic s2c = payload is Map ? payload['s2c'] : null;
      final dynamic rows = s2c is Map ? s2c['list'] : null;
      while (true) {
        if (isOfflineList && rows is List && index < rows.length) {
          final row = rows[index];
          offlineAction = row is Map ? row['action']?.toString() : null;
        }
        _value([...path, '*']);
        if (isOfflineList) offlineAction = null;
        index++;
        _space();
        if (source[pos++] == ']') return;
      }
    } else if (c == '"') {
      _string();
    } else {
      final start = pos;
      while (pos < source.length && !',]} \n\r\t'.contains(source[pos])) {
        pos++;
      }
      final token = source.substring(start, pos);
      final digits =
          shape == ChannelResponseShape.socket && token.startsWith('-')
          ? token.substring(1)
          : token;
      final isDecimal =
          digits.isNotEmpty &&
          digits.codeUnits.every((n) => n >= 48 && n <= 57);
      final isGroup =
          shape == ChannelResponseShape.groupDetail ||
          shape == ChannelResponseShape.groupList ||
          shape == ChannelResponseShape.groupCreate ||
          shape == ChannelResponseShape.groupMember ||
          shape == ChannelResponseShape.groupWorkspace;
      final groupKeys = [
        'id',
        'gid',
        'group_id',
        'owner_uid',
        'creator_uid',
        'user_id',
        'workspace_id',
        'member_generation_id',
      ];
      final offlineGroup = offlineAction?.startsWith('group_') ?? false;
      final offlineChannel = offlineAction?.startsWith('channel_') ?? false;
      final offlineFriend =
          offlineAction == 'apply_friend' ||
          offlineAction == 'apply_friend_confirm';
      final offlineTrust = offlineAction == 'e2ee_trust_changed';
      final offlineDeviceKey = offlineAction == 'e2ee_device_key_changed';
      final selected = shape == ChannelResponseShape.messageResult
          ? _matches(path, const ['payload', 'peer_id'])
          : shape == ChannelResponseShape.fts
          ? ['list', 'items'].any(
              (list) => [
                'message_id',
                'id',
                'from',
                'to',
                'from_id',
                'to_id',
                'group_id',
              ].any((key) => _matches(path, ['payload', list, '*', key])),
            )
          : shape == ChannelResponseShape.denylist
          ? [
              'id',
              'denied_user_id',
            ].any((key) => _matches(path, ['payload', 'list', '*', key]))
          : shape == ChannelResponseShape.offline
          ? ['c2c', 'c2g'].any(
                  (kind) => ['from', 'to'].any(
                    (key) =>
                        _matches(path, ['payload', kind, 'list', '*', key]),
                  ),
                ) ||
                (offlineGroup ||
                        offlineChannel ||
                        offlineFriend ||
                        offlineTrust ||
                        offlineDeviceKey) &&
                    (['from', 'to', 'msg_id', 'id'].any(
                          (key) => _matches(path, [
                            'payload',
                            's2c',
                            'list',
                            '*',
                            key,
                          ]),
                        ) ||
                        [
                          if (offlineTrust) ...['actor_uid', 'target_uid'],
                          if (offlineDeviceKey) 'uid',
                          if (offlineGroup) ...[
                            'gid',
                            'group_id',
                            'user_id',
                            'leave_uid',
                            'from_owner_uid',
                            'to_owner_uid',
                            'notice_id',
                            'publisher_id',
                          ],
                          if (offlineChannel) ...[
                            'id',
                            'channel_id',
                            'message_id',
                            'author_id',
                            'user_id',
                            'parent_id',
                            'reply_to_uid',
                            'creator_id',
                            'creator_uid',
                            'workspace_id',
                            'discussion_group_id',
                            'local_id',
                            'real_id',
                          ],
                        ].any(
                          (key) =>
                              _matches(path, [
                                'payload',
                                's2c',
                                'list',
                                '*',
                                'payload',
                                key,
                              ]) ||
                              (offlineChannel &&
                                  _matches(path, [
                                    'payload',
                                    's2c',
                                    'list',
                                    '*',
                                    'payload',
                                    'channel',
                                    key,
                                  ])),
                        ))
          : shape == ChannelResponseShape.people
          ? [
              'id',
              'uid',
            ].any((key) => _matches(path, ['payload', 'list', '*', key]))
          : shape == ChannelResponseShape.contact
          ? ['id', 'peer_id', 'peerId', 'user_id'].any(
              (key) =>
                  _matches(path, ['payload', key]) ||
                  _matches(path, ['payload', 'friend', '*', key]),
            )
          : shape == ChannelResponseShape.deviceKeySocket
          ? _matches(path, const ['payload', 'uid']) ||
                _matches(path, const ['from']) ||
                _matches(path, const ['to'])
          : shape == ChannelResponseShape.trustSocket
          ? [
                  'actor_uid',
                  'target_uid',
                ].any((key) => _matches(path, ['payload', key])) ||
                _matches(path, const ['from']) ||
                _matches(path, const ['to'])
          : shape == ChannelResponseShape.groupSocket
          ? [
                  'gid',
                  'group_id',
                  'user_id',
                  'leave_uid',
                  'from_owner_uid',
                  'to_owner_uid',
                  'notice_id',
                  'publisher_id',
                ].any((key) => _matches(path, ['payload', key])) ||
                _matches(path, const ['from']) ||
                _matches(path, const ['to'])
          : isGroup
          ? groupKeys.any(
                  (key) =>
                      _matches(path, ['payload', key]) ||
                      _matches(path, ['payload', 'group', key]) ||
                      _matches(path, ['payload', 'list', '*', key]) ||
                      _matches(path, ['payload', 'member_list', '*', key]),
                ) ||
                (shape == ChannelResponseShape.groupWorkspace &&
                    _matches(path, const ['payload', 'next_cursor']))
          : shape == ChannelResponseShape.unread
          ? _matches(path, const ['payload', 'channels', '*', 'channel_id'])
          : shape == ChannelResponseShape.socket
          ? [
                  'id',
                  'channel_id',
                  'message_id',
                  'author_id',
                  'message_id',
                  'user_id',
                  'parent_id',
                  'reply_to_uid',
                  'creator_id',
                  'creator_uid',
                  'workspace_id',
                  'discussion_group_id',
                  'local_id',
                  'real_id',
                ].any(
                  (key) =>
                      _matches(path, ['payload', key]) ||
                      _matches(path, ['payload', 'channel', key]),
                ) ||
                _matches(path, const ['id'])
          : (shape == ChannelResponseShape.workspace &&
                    _matches(path, const ['payload', 'workspace_id'])) ||
                (shape != ChannelResponseShape.detail &&
                    _matches(path, const ['payload', 'next_cursor']))
          ? true
          : shape == ChannelResponseShape.detail
          ? [
              'id',
              'creator_uid',
              'creator_id',
              'author_id',
              'message_id',
              'user_id',
              'parent_id',
              'reply_to_uid',
              'channel_id',
              'workspace_id',
              'discussion_group_id',
            ].any((key) => _matches(path, ['payload', key]))
          : [
              'id',
              'creator_uid',
              'creator_id',
              'author_id',
              'message_id',
              'user_id',
              'parent_id',
              'reply_to_uid',
              'channel_id',
              'workspace_id',
              'discussion_group_id',
            ].any((key) => _matches(path, ['payload', 'list', '*', key]));
      if (selected && isDecimal) edits.add((start, pos));
    }
  }

  bool _matches(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);
}
