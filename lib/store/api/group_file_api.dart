import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:imboy/component/http/http_client.dart';

/// 群文件 API 客户端
class GroupFileApi extends HttpClient {
  int _toInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  List<Map<String, dynamic>> _normalizeList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _normalizeCategoryStats(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      map['category'] = (map['category'] ?? '').toString();
      map['count'] = _toInt(map['count']);
      map['total_size'] = _toInt(map['total_size']);
      return map;
    }).toList();
  }

  /// 获取群文件列表
  Future<Map<String, dynamic>> getFiles({
    required String groupId,
    int page = 1,
    int size = 20,
    String? category,
  }) async {
    final query = <String, dynamic>{'gid': groupId, 'page': page, 'size': size};
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }

    final resp = await get('/v1/group/file/list', queryParameters: query);
    debugPrint("GroupFileApi_getFiles resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final payload = Map<String, dynamic>.from(resp.payload);
    final list = _normalizeList(payload['list'] ?? payload['items']);
    final total = _toInt(payload['total'], fallback: list.length);
    return {
      'list': list,
      'total': total,
      'page': _toInt(payload['page'], fallback: page),
      'size': _toInt(payload['size'], fallback: size),
    };
  }

  /// 获取群文件分类统计
  Future<List<Map<String, dynamic>>> getCategoryStats({
    required String groupId,
  }) async {
    final gid = groupId.trim();
    if (gid.isEmpty) {
      return [];
    }

    final resp = await get(
      '/v1/group/file/categories',
      queryParameters: {'gid': gid},
    );
    debugPrint("GroupFileApi_getCategoryStats resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    final payload = Map<String, dynamic>.from(resp.payload);
    return _normalizeCategoryStats(payload['items'] ?? payload['list']);
  }

  /// 搜索群文件
  Future<Map<String, dynamic>> searchFiles({
    required String groupId,
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    final gid = groupId.trim();
    final kw = keyword.trim();
    if (gid.isEmpty || kw.isEmpty) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final resp = await get(
      '/v1/group/file/search',
      queryParameters: {'gid': gid, 'keyword': kw, 'page': page, 'size': size},
    );
    debugPrint("GroupFileApi_searchFiles resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final payload = Map<String, dynamic>.from(resp.payload);
    final list = _normalizeList(payload['items'] ?? payload['list']);
    final total = _toInt(payload['total'], fallback: list.length);
    return {
      'list': list,
      'total': total,
      'page': _toInt(payload['page'], fallback: page),
      'size': _toInt(payload['size'], fallback: size),
    };
  }

  /// 上传群文件
  Future<Map<String, dynamic>?> uploadFile({
    required String groupId,
    required String fileName,
    required List<int> fileBytes,
    String? fileType,
  }) async {
    final gid = groupId.trim();
    final name = fileName.trim();
    if (gid.isEmpty || name.isEmpty || fileBytes.isEmpty) {
      return null;
    }

    final data = <String, dynamic>{
      'gid': gid,
      'file_name': name,
      'file': MultipartFile.fromBytes(fileBytes, filename: name),
    };
    final normalizedFileType = fileType?.trim();
    if (normalizedFileType != null && normalizedFileType.isNotEmpty) {
      data['file_type'] = normalizedFileType;
    }

    final resp = await post(
      '/v1/group/file/upload',
      data: FormData.fromMap(data),
      options: Options(contentType: 'multipart/form-data'),
    );
    debugPrint("GroupFileApi_uploadFile resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload);
  }

  /// 删除群文件
  Future<bool> deleteFile(dynamic fileId) async {
    if (fileId == null) return false;
    final text = fileId.toString().trim();
    if (text.isEmpty) return false;
    final resp = await post('/v1/group/file/delete', data: {'file_id': text});
    debugPrint("GroupFileApi_deleteFile resp: ok=${resp.ok}");
    return resp.ok;
  }
}
