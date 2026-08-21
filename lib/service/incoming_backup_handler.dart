import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_handler/share_handler.dart';

/// 捕获从外部 App（邮件、文件管理器、微信等）打开/分享进来的 E2EE 备份文件，
/// 复制到 App 可控的临时目录后返回本地路径，供 [E2EEBackupImportPage] 消费。
///
/// 两条数据来源：
/// - **share_handler 插件**：处理 Android `ACTION_SEND` / iOS Share Extension。
/// - **imboy/backup_intent MethodChannel**：补全 Android `ACTION_VIEW`
///   （文件管理器「打开方式」场景），因为 share_handler 的 Android 实现不处理 VIEW。
class IncomingBackupHandler {
  IncomingBackupHandler._();

  static const _backupIntentChannel = MethodChannel('imboy/backup_intent');

  /// 冷启动时消费初始共享文件；返回本地文件路径或 null（无备份文件）。
  /// 先查 share_handler（SEND），再查 backup_intent channel（VIEW）。
  static Future<String?> consumeInitialFile() async {
    try {
      // 1. share_handler：处理 ACTION_SEND (Android) / Share Extension (iOS)
      final media = await ShareHandler.instance.getInitialSharedMedia();
      if (media != null) {
        final path = await _extractBackupPath(media);
        if (path != null) {
          try {
            await ShareHandler.instance.resetInitialSharedMedia();
          } on Object catch (e) {
            if (kDebugMode) {
              debugPrint('[IncomingBackup] resetInitialSharedMedia: $e');
            }
          }
          return path;
        }
      }

      // 2. backup_intent channel：处理 Android ACTION_VIEW（冷启动）
      // iOS 不需要这个 channel（Share Extension 已覆盖），调用会是 no-op。
      if (Platform.isAndroid) {
        final viewPath = await _consumeViewFile();
        if (viewPath != null) return viewPath;
      }

      return null;
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[IncomingBackup] consumeInitialFile: $e');
      }
      return null;
    }
  }

  /// 热启动时监听共享文件流；收到 `.enc` 备份文件时发出本地路径。
  /// 合并 share_handler 的 stream 和 backup_intent 的 onNewViewFile 事件。
  static Stream<String> watchIncomingFiles() {
    final controller = StreamController<String>();

    // 1. share_handler stream（ACTION_SEND / iOS Share Extension）
    ShareHandler.instance.sharedMediaStream.listen(
      (media) async {
        final path = await _extractBackupPath(media);
        if (path != null && !controller.isClosed) {
          controller.add(path);
        }
      },
      onError: (Object e) {
        if (kDebugMode) {
          debugPrint('[IncomingBackup] share_handler stream error: $e');
        }
      },
    );

    // 2. backup_intent channel：Android ACTION_VIEW（热启动）
    // native 侧 onNewIntent 后 invokeMethod("onNewViewFile") 触发。
    if (Platform.isAndroid) {
      _backupIntentChannel.setMethodCallHandler((call) async {
        if (call.method == 'onNewViewFile') {
          final path = await _consumeViewFile();
          if (path != null && !controller.isClosed) {
            controller.add(path);
          }
        }
        return null;
      });
    }

    return controller.stream;
  }

  /// 从 backup_intent channel 拉取缓存的 ACTION_VIEW 文件 URI，
  /// native 侧已复制到 cacheDir，返回本地路径。
  static Future<String?> _consumeViewFile() async {
    try {
      final result = await _backupIntentChannel.invokeMethod<String>(
        'getInitialViewFile',
      );
      return result;
    } on MissingPluginException {
      // channel 未注册（非 Android 平台）
      return null;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[IncomingBackup] getInitialViewFile: $e');
      }
      return null;
    }
  }

  /// 从 [SharedMedia] 提取第一个 `.enc` 文件附件，复制到临时目录后返回路径。
  static Future<String?> _extractBackupPath(SharedMedia media) async {
    final attachments = media.attachments;
    if (attachments == null || attachments.isEmpty) return null;

    for (final att in attachments) {
      if (att == null) continue;
      if (att.type != SharedAttachmentType.file) continue;
      final srcPath = att.path;
      if (!srcPath.toLowerCase().endsWith('.enc')) continue;

      try {
        return await _copyToTemp(srcPath);
      } on Object catch (e) {
        if (kDebugMode) {
          debugPrint('[IncomingBackup] 复制失败 $srcPath: $e');
        }
        // 尝试下一个附件
        continue;
      }
    }
    return null;
  }

  /// 将源文件复制到 App 临时目录，返回新路径。
  /// iOS 的 share_handler 临时副本 / Android 的 content URI 都走这条路径。
  static Future<String> _copyToTemp(String srcPath) async {
    final src = File(srcPath);
    if (!await src.exists()) {
      throw FileSystemException('源文件不存在', srcPath);
    }
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final destPath =
        '${tempDir.path}/imboy_e2ee_backup_incoming_$timestamp.enc';
    await src.copy(destPath);
    return destPath;
  }
}
