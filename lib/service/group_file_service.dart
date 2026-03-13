import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/store/api/group_file_api.dart';

/// 群文件服务
class GroupFileService {
  static GroupFileService _instance = GroupFileService._privateConstructor();
  static GroupFileService get to => _instance;

  @visibleForTesting
  static set instanceForTest(GroupFileService? service) {
    _instance = service ?? GroupFileService._privateConstructor();
  }

  GroupFileService._privateConstructor() : _api = GroupFileApi();
  GroupFileService.withApi(this._api);

  final GroupFileApi _api;

  Future<Map<String, dynamic>> getFiles({
    required String groupId,
    int page = 1,
    int size = 20,
    String? category,
  }) async {
    try {
      return await _api.getFiles(
        groupId: groupId,
        page: page,
        size: size,
        category: category,
      );
    } catch (e) {
      iPrint('GroupFileService: 获取群文件失败 - $e');
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getCategoryStats({
    required String groupId,
  }) async {
    try {
      return await _api.getCategoryStats(groupId: groupId);
    } catch (e) {
      iPrint('GroupFileService: 获取群文件分类统计失败 - $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> searchFiles({
    required String groupId,
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _api.searchFiles(
        groupId: groupId,
        keyword: keyword,
        page: page,
        size: size,
      );
    } catch (e) {
      iPrint('GroupFileService: 搜索群文件失败 - $e');
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }
  }

  Future<Map<String, dynamic>?> uploadFile({
    required String groupId,
    required String fileName,
    required List<int> fileBytes,
    String? fileType,
  }) async {
    try {
      return await _api.uploadFile(
        groupId: groupId,
        fileName: fileName,
        fileBytes: fileBytes,
        fileType: fileType,
      );
    } catch (e) {
      iPrint('GroupFileService: 上传群文件失败 - $e');
      return null;
    }
  }

  Future<bool> deleteFile(dynamic fileId) async {
    try {
      return await _api.deleteFile(fileId);
    } catch (e) {
      iPrint('GroupFileService: 删除群文件失败 - $e');
      return false;
    }
  }
}
