import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// 群标签 API 客户端
///
/// 负责与后端 API 通信，处理群标签相关的网络请求
class GroupTagApi extends HttpClient {
  List<Map<String, dynamic>> _normalizeTagList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final tagName = (map['tag_name'] ?? map['name'])?.toString();
      if (tagName != null) {
        map['name'] = tagName;
      }
      return map;
    }).toList();
  }

  /// 获取群的标签列表
  Future<List<Map<String, dynamic>>> getGroupTags(String groupId) async {
    final resp = await get(API.groupTagList, queryParameters: {'gid': groupId});

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    return _normalizeTagList(resp.payload['list']);
  }

  /// 添加群标签
  Future<bool> addTag({
    required String groupId,
    required String name,
    String? color,
  }) async {
    final data = <String, dynamic>{'gid': groupId, 'tag_name': name};
    if (color != null) data['color'] = color;

    final resp = await post(API.groupTagAdd, data: data);
    return resp.ok;
  }

  /// 删除群标签
  Future<bool> removeTag({
    required String groupId,
    required String tagName,
  }) async {
    final resp = await post(
      API.groupTagRemove,
      data: {'gid': groupId, 'tag_name': tagName},
    );
    return resp.ok;
  }

  /// 按标签搜索群
  Future<List<Map<String, dynamic>>> searchByTag(
    String tagName, {
    int limit = 20,
  }) async {
    final resp = await get(
      API.groupTagSearch,
      queryParameters: {'tag_name': tagName, 'limit': limit},
    );

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    return _normalizeTagList(resp.payload['list']);
  }

  /// 获取热门标签
  Future<List<Map<String, dynamic>>> getHotTags({int limit = 20}) async {
    final resp = await get(API.groupTagHot, queryParameters: {'limit': limit});

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    return _normalizeTagList(resp.payload['list']);
  }
}
