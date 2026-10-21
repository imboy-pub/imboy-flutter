package pub.imboy.app

import android.content.Intent
import android.net.Uri
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

  private var talkRecordForeground: TalkRecordForegroundBridge? = null

  override fun onResume() {
    super.onResume()
    talkRecordForeground?.setResumed(true)
  }

  override fun onPause() {
    talkRecordForeground?.setResumed(false)
    super.onPause()
  }

  override fun onDestroy() {
    talkRecordForeground?.dispose()
    talkRecordForeground = null
    super.onDestroy()
  }

  /// 冷启动时缓存的 ACTION_VIEW intent 的文件 URI。
  /// share_handler 只处理 ACTION_SEND，不处理 ACTION_VIEW（文件管理器「打开方式」场景）。
  /// Flutter 侧通过 imboy/backup_intent channel 读取此 URI，消费后置 null。
  private var initialViewFileUri: Uri? = null

  /// 冷启动时缓存的 imboy:// 深链 URI（MC-AC-22）。
  /// 与备份文件 VIEW 分流：scheme=imboy 走深链，其余按文件处理。
  private var initialDeepLinkUri: Uri? = null

  /// 热启动时通过此 channel 主动通知 Flutter 侧有新文件到达。
  private var backupIntentChannel: MethodChannel? = null

  /// 热启动时通过此 channel 主动推送 imboy:// 深链。
  private var deepLinkChannel: MethodChannel? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    talkRecordForeground = TalkRecordForegroundBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "imboy/secure")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "enable" -> {
            runOnUiThread {
              window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
              result.success(true)
            }
          }
          "disable" -> {
            runOnUiThread {
              window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
              result.success(true)
            }
          }
          else -> result.notImplemented()
        }
      }

    // E2EE 备份导入：处理 ACTION_VIEW（文件管理器「打开方式」场景）。
    // share_handler 的 Android 实现只处理 ACTION_SEND/ACTION_SEND_MULTIPLE，
    // 对 ACTION_VIEW 返回 null。这里补全 VIEW 的处理。
    backupIntentChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger, "imboy/backup_intent"
    )
    backupIntentChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "getInitialViewFile" -> {
          val uri = initialViewFileUri
          if (uri == null) {
            result.success(null)
          } else {
            try {
              val localPath = copyUriToCache(uri)
              initialViewFileUri = null
              result.success(localPath)
            } catch (e: Exception) {
              result.success(null)
            }
          }
        }
        else -> result.notImplemented()
      }
    }

    // imboy:// 深链（MC-AC-22）：冷启动 pull（getInitialLink，消费后置 null）。
    // 热启动走 onNewIntent → onDeepLink push。
    deepLinkChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger, "imboy/deep_link"
    )
    deepLinkChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "getInitialLink" -> {
          val link = initialDeepLinkUri?.toString()
          initialDeepLinkUri = null
          result.success(link)
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    // 热启动：缓存 URI，然后通知 Flutter 侧主动来取。
    // 冷启动不走这里（走 onCreate → getInitialViewFile 拉取）。
    cacheViewIntent(intent)
    if (initialViewFileUri != null) {
      backupIntentChannel?.invokeMethod("onNewViewFile", null)
    }
    val deepLink = consumeDeepLinkUri(intent)
    if (deepLink != null) {
      deepLinkChannel?.invokeMethod("onDeepLink", deepLink)
    }
  }

  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    // 冷启动：只缓存，不通知（Flutter engine 尚未就绪）。
    cacheViewIntent(intent)
  }

  private fun cacheViewIntent(intent: Intent?) {
    if (intent != null && intent.action == Intent.ACTION_VIEW) {
      val uri = intent.data
      if (uri != null) {
        if (isAppDeepLink(uri)) {
          initialDeepLinkUri = uri
        } else {
          initialViewFileUri = uri
        }
      }
    }
  }

  /// 从 VIEW intent 提取 imboy:// 深链（热启动路径用，不缓存）。
  private fun consumeDeepLinkUri(intent: Intent?): String? {
    if (intent == null || intent.action != Intent.ACTION_VIEW) return null
    val uri = intent.data ?: return null
    if (!isAppDeepLink(uri)) return null
    return uri.toString()
  }

  private fun isAppDeepLink(uri: Uri): Boolean {
    if (uri.scheme == "imboy") return true
    return uri.scheme == "https" && uri.host == "imboy.pub" &&
      (uri.port == -1 || uri.port == 443) &&
      uri.userInfo == null && uri.path?.startsWith("/channel/") == true
  }

  /// 把 content:// 或 file:// URI 复制到 cacheDir，返回本地文件路径。
  /// Dart 侧的 File 只能读本地路径，不能直接用 content URI。
  private fun copyUriToCache(uri: Uri): String {
    val timestamp = System.currentTimeMillis()
    val destFile = File(cacheDir, "imboy_e2ee_backup_view_$timestamp.enc")
    contentResolver.openInputStream(uri).use { input ->
      if (input == null) throw java.io.FileNotFoundException("无法打开: $uri")
      destFile.outputStream().use { output ->
        input.copyTo(output)
      }
    }
    return destFile.absolutePath
  }
}
