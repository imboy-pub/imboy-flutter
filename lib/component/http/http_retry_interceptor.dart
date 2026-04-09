import 'dart:async';

import 'package:dio/dio.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/app_logger.dart';

/// HTTP 请求重试拦截器
/// HTTP request retry interceptor with exponential backoff
///
/// 功能特性 (Features):
/// - 自动重试可恢复的错误（网络超时、连接失败等）
/// - 指数退避策略（避免服务器压力）
/// - 区分可重试和不可重试的错误
/// - 最大重试次数限制
/// - 自定义重试条件
///
/// 使用示例 (Usage Example):
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(HttpRetryInterceptor(
///   maxRetries: 3,
///   retryInterval: Duration(seconds: 1),
/// ));
/// ```
class HttpRetryInterceptor extends Interceptor {
  /// 最大重试次数
  final int maxRetries;

  /// 初始重试间隔
  final Duration retryInterval;

  /// 是否启用指数退避
  final bool exponentialBackoff;

  /// 自定义重试判断函数（返回 true 表示需要重试）
  final bool Function(DioException error)? retryEvaluator;

  /// 重试回调（可用于日志记录）
  final void Function(DioException error, int retryCount)? onRetry;

  /// 持有原始 Dio 实例的引用，重试时复用其配置（headers、adapter、拦截器链）
  Dio? _dio;

  HttpRetryInterceptor({
    this.maxRetries = 3,
    this.retryInterval = const Duration(seconds: 1),
    this.exponentialBackoff = true,
    this.retryEvaluator,
    this.onRetry,
  });

  /// 绑定到指定的 Dio 实例（在 addInterceptor 后自动调用）
  void bindDio(Dio dio) {
    _dio = dio;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // 检查是否应该重试
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra[_retryCountKey] as int? ?? 0;

      if (retryCount < maxRetries) {
        try {
          // 更新重试计数
          err.requestOptions.extra[_retryCountKey] = retryCount + 1;

          // 计算延迟时间
          final delay = _calculateDelay(retryCount);

          AppLogger.warning(
            'HTTP request failed, retrying... '
            '(${retryCount + 1}/$maxRetries) '
            'after ${delay.inMilliseconds}ms '
            'url: ${err.requestOptions.uri}',
          );

          // 触发重试回调
          onRetry?.call(err, retryCount + 1);

          // 延迟后重试
          await Future.delayed(delay);

          // 使用绑定的 Dio 实例重试，保留完整的配置（headers、adapter、证书等）
          // 如果未绑定则回退到 requestOptions 自带的配置
          final retryDio = _dio ?? Dio();
          // 同步最新的认证 headers，防止携带陈旧 token
          final currentHeaders = retryDio.options.headers;
          if (currentHeaders.containsKey('authorization')) {
            err.requestOptions.headers['authorization'] =
                currentHeaders['authorization'];
          }
          final response = await retryDio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          // 重试失败，继续传递错误
          AppLogger.error('HTTP retry failed: $e');
          return handler.next(err);
        }
      } else {
        AppLogger.error(
          'HTTP request failed after $maxRetries retries: '
          'url: ${err.requestOptions.uri}',
        );
      }
    }

    return handler.next(err);
  }

  /// 判断是否应该重试
  /// Determine if the request should be retried
  bool _shouldRetry(DioException err) {
    // 优先使用自定义判断函数
    if (retryEvaluator != null) {
      return retryEvaluator!(err);
    }

    // 默认重试逻辑
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        // 网络相关错误，可重试
        return true;

      case DioExceptionType.badResponse:
        // 仅重试 5xx 服务器错误
        final statusCode = err.response?.statusCode;
        if (statusCode != null && statusCode >= 500 && statusCode < 600) {
          return true;
        }
        // 4xx 错误不重试（客户端错误）
        return false;

      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
      default:
        // 其他错误不重试
        return false;
    }
  }

  /// 计算延迟时间
  /// Calculate delay duration
  Duration _calculateDelay(int retryCount) {
    if (!exponentialBackoff) {
      return retryInterval;
    }

    // 指数退避：延迟时间 = 初始间隔 * (2 ^ 重试次数)
    final milliseconds = retryInterval.inMilliseconds * (1 << retryCount);
    // 限制最大延迟时间为 30 秒
    const maxDelay = 30000;
    return Duration(milliseconds: milliseconds.clamp(0, maxDelay));
  }

  /// 重试计数存储键
  static const String _retryCountKey = 'retry_count';
}

/// HTTP 重试配置类
/// HTTP retry configuration class
class HttpRetryConfig {
  /// 最大重试次数
  final int maxRetries;

  /// 初始重试间隔
  final Duration retryInterval;

  /// 是否启用指数退避
  final bool exponentialBackoff;

  /// 是否在开发环境显示重试提示
  final bool showRetryToast;

  /// 可重试的 HTTP 状态码列表
  final List<int> retryableStatusCodes;

  /// 可重试的 Dio 错误类型列表
  final List<DioExceptionType> retryableErrorTypes;

  const HttpRetryConfig({
    this.maxRetries = 3,
    this.retryInterval = const Duration(seconds: 1),
    this.exponentialBackoff = true,
    this.showRetryToast = false,
    this.retryableStatusCodes = const [500, 502, 503, 504],
    this.retryableErrorTypes = const [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ],
  });

  /// 默认配置
  static const defaultConfig = HttpRetryConfig();

  /// 开发环境配置（较少重试，显示提示）
  static const devConfig = HttpRetryConfig(
    maxRetries: 2,
    retryInterval: Duration(seconds: 1),
    showRetryToast: true,
  );

  /// 生产环境配置（较多重试，无提示）
  static const prodConfig = HttpRetryConfig(
    maxRetries: 3,
    retryInterval: Duration(seconds: 2),
    exponentialBackoff: true,
    showRetryToast: false,
  );
}

/// 创建 HTTP 重试拦截器的工厂函数
/// Factory function to create HTTP retry interceptor
HttpRetryInterceptor createRetryInterceptor([HttpRetryConfig? config]) {
  final effectiveConfig = config ?? HttpRetryConfig.defaultConfig;

  return HttpRetryInterceptor(
    maxRetries: effectiveConfig.maxRetries,
    retryInterval: effectiveConfig.retryInterval,
    exponentialBackoff: effectiveConfig.exponentialBackoff,
    retryEvaluator: (error) {
      // 根据配置判断是否可重试

      // 检查错误类型
      if (effectiveConfig.retryableErrorTypes.contains(error.type)) {
        return true;
      }

      // 检查状态码
      if (error.type == DioExceptionType.badResponse) {
        final statusCode = error.response?.statusCode;
        if (statusCode != null &&
            effectiveConfig.retryableStatusCodes.contains(statusCode)) {
          return true;
        }
      }

      return false;
    },
    onRetry: (error, retryCount) {
      if (effectiveConfig.showRetryToast && recordLog) {
        AppLogger.warning(
          'HTTP 重试中... ($retryCount/${effectiveConfig.maxRetries})',
        );
      }
    },
  );
}
