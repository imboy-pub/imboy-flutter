import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/i18n/strings.g.dart';

/// API 服务辅助类
///
/// 提供通用的 API 请求辅助方法，减少重复代码
/// 适用于新 API 或符合标准模式的 API
///
/// 使用示例：
/// ```dart
/// class YourApi extends HttpClient {
///   final helper = BaseApiService();
///
///   Future<Map<String, dynamic>?> getData() async {
///     return helper.safeRequest(
///       () => get(API.yourEndpoint),
///       showError: true,
///     );
///   }
/// }
/// ```
class BaseApiService {
  /// 安全请求封装
  ///
  /// 统一处理错误和日志，返回 payload 或 null
  ///
  /// 参数：
  /// - [request]: API 请求函数
  /// - [showError]: 是否显示错误提示（默认 false）
  /// - [logTag]: 日志标签（用于 debug 输出）
  ///
  /// 返回：成功时返回 resp.payload，失败时返回 null
  Future<T?> safeRequest<T>(
    Future<IMBoyHttpResponse> Function() request, {
    bool showError = false,
    String? logTag,
  }) async {
    try {
      final resp = await request();

      if (logTag != null) {
        debugPrint("> on $logTag resp: ${resp.payload.toString()}");
      }

      if (!resp.ok) {
        if (showError && resp.msg.isNotEmpty) {
          EasyLoading.showError(resp.msg);
        }
        return null;
      }

      return resp.payload as T;
    } catch (e) {
      if (showError) {
        EasyLoading.showError(t.loadError);
      }
      debugPrint("> on BaseApiService error: $e");
      return null;
    }
  }

  /// 安全请求（返回 bool）
  ///
  /// 用于只关心成功/失败的 API 请求
  ///
  /// 参数：
  /// - [request]: API 请求函数
  /// - [showError]: 是否显示错误提示（默认 true）
  /// - [logTag]: 日志标签
  ///
  /// 返回：成功返回 true，失败返回 false
  Future<bool> safeBoolRequest(
    Future<IMBoyHttpResponse> Function() request, {
    bool showError = true,
    String? logTag,
  }) async {
    try {
      final resp = await request();

      if (logTag != null) {
        debugPrint("> on $logTag resp: ${resp.ok}, ${resp.payload.toString()}");
      }

      if (!resp.ok && showError && resp.msg.isNotEmpty) {
        EasyLoading.showError(resp.msg);
      }

      return resp.ok;
    } catch (e) {
      if (showError) {
        EasyLoading.showError(t.loadError);
      }
      debugPrint("> on BaseApiService error: $e");
      return false;
    }
  }

  /// 安全请求（返回列表）
  ///
  /// 用于返回列表数据的 API 请求
  ///
  /// 参数：
  /// - [request]: API 请求函数
  /// - [listKey]: 列表在 payload 中的键名（默认 'list'）
  /// - [showError]: 是否显示错误提示
  /// - [logTag]: 日志标签
  ///
  /// 返回：成功返回列表，失败返回空列表
  Future<List<T>> safeListRequest<T>(
    Future<IMBoyHttpResponse> Function() request, {
    String listKey = 'list',
    bool showError = false,
    String? logTag,
  }) async {
    try {
      final resp = await request();

      if (logTag != null) {
        debugPrint("> on $logTag resp: ${resp.payload.toString()}");
      }

      if (!resp.ok) {
        if (showError && resp.msg.isNotEmpty) {
          EasyLoading.showError(resp.msg);
        }
        return [];
      }

      final payload = resp.payload;
      if (payload is Map && payload.containsKey(listKey)) {
        final list = payload[listKey];
        if (list is List) {
          return List<T>.from(list);
        }
      }

      return [];
    } catch (e) {
      if (showError) {
        EasyLoading.showError(t.loadError);
      }
      debugPrint("> on BaseApiService error: $e");
      return [];
    }
  }

  /// 分页请求
  ///
  /// 统一处理分页请求的参数和返回值
  ///
  /// 参数：
  /// - [endpoint]: API 端点
  /// - [get]: GET 请求函数
  /// - [page]: 页码（默认 1）
  /// - [size]: 每页大小（默认 20）
  /// - [extraParams]: 额外的查询参数
  /// - [showError]: 是否显示错误提示
  /// - [logTag]: 日志标签
  ///
  /// 返回：成功返回 payload，失败返回 null
  Future<Map<String, dynamic>?> paginatedRequest(
    String endpoint,
    Future<IMBoyHttpResponse> Function(String, Map<String, dynamic>) get, {
    int page = 1,
    int size = 20,
    Map<String, dynamic>? extraParams,
    bool showError = false,
    String? logTag,
  }) async {
    final params = {'page': page, 'size': size, ...?extraParams};

    return safeRequest(
      () => get(endpoint, params),
      showError: showError,
      logTag: logTag ?? "PaginatedRequest($endpoint)",
    );
  }

  /// 带重试的请求
  ///
  /// 在请求失败时自动重试
  ///
  /// 参数：
  /// - [request]: API 请求函数
  /// - [maxRetries]: 最大重试次数（默认 1）
  /// - [showError]: 是否显示错误提示
  /// - [logTag]: 日志标签
  ///
  /// 返回：成功返回 payload，失败返回 null
  Future<T?> retryableRequest<T>(
    Future<IMBoyHttpResponse> Function() request, {
    int maxRetries = 1,
    bool showError = false,
    String? logTag,
  }) async {
    int attempts = 0;

    while (attempts <= maxRetries) {
      try {
        final resp = await request();

        if (logTag != null) {
          debugPrint(
            "> on $logTag (attempt ${attempts + 1}) resp: ${resp.payload.toString()}",
          );
        }

        if (resp.ok) {
          return resp.payload as T;
        }

        // 如果是最后一次尝试，返回 null
        if (attempts == maxRetries) {
          if (showError && resp.msg.isNotEmpty) {
            EasyLoading.showError(resp.msg);
          }
          return null;
        }
      } catch (e) {
        debugPrint("> on $logTag (attempt ${attempts + 1}) error: $e");

        // 如果是最后一次尝试，显示错误并返回 null
        if (attempts == maxRetries) {
          if (showError) {
            EasyLoading.showError(t.loadError);
          }
          return null;
        }
      }

      attempts++;
      // 短暂延迟后重试
      await Future.delayed(Duration(milliseconds: 500 * attempts));
    }

    return null;
  }
}
