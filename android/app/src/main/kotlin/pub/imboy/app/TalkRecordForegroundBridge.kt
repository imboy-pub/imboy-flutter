package pub.imboy.app

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** An acknowledged, token-owned bridge. Never starts a microphone service from background. */
class TalkRecordForegroundBridge(private val activity: Activity, messenger: BinaryMessenger) {
  private val channel = MethodChannel(messenger, "imboy/talk_record_foreground")
  private val handler = Handler(Looper.getMainLooper())
  private var resumed = false
  private var token: String? = null
  private var service: TalkRecordForegroundService? = null
  private var connection: ServiceConnection? = null
  private var pending: MethodChannel.Result? = null
  private var timeout: Runnable? = null

  private fun clearTimeout() {
    timeout?.let { handler.removeCallbacks(it) }
    timeout = null
  }

  init {
    channel.setMethodCallHandler { call, result ->
      val requested = call.argument<String>("token")
      if (requested.isNullOrBlank() || requested.length > 128) {
        result.error("invalid_owner", activity.getString(R.string.talk_record_invalid_owner), null)
      } else when (call.method) {
        "start" -> start(requested, result)
        "update" -> {
          if (requested != token || service == null) result.error("foreground_lost", activity.getString(R.string.talk_record_unavailable), null)
          else try {
            service!!.begin(requested, call.argument<Boolean>("paused") == true)
            result.success(true)
          } catch (_: Exception) { lost(); result.error("foreground_rejected", activity.getString(R.string.talk_record_rejected), null) }
        }
        "stop" -> {
          if (token == null && service == null && pending == null) result.success(true)
          else if (requested != token) result.error("owner_mismatch", activity.getString(R.string.talk_record_owner_mismatch), null)
          else {
            pending?.error("foreground_cancelled", activity.getString(R.string.talk_record_cancelled), null)
            pending = null
            release(); result.success(true)
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  fun setResumed(value: Boolean) { resumed = value }

  private fun start(requested: String, result: MethodChannel.Result) {
    if (token != null) {
      if (token == requested && service != null) result.success(true)
      else result.error("foreground_busy", activity.getString(R.string.talk_record_busy), null)
      return
    }
    if (!resumed || !activity.hasWindowFocus()) {
      result.error("foreground_visibility_required", activity.getString(R.string.talk_record_visible), null); return
    }
    if (Build.VERSION.SDK_INT >= 23 && activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      result.error("microphone_permission_required", activity.getString(R.string.talk_record_microphone), null); return
    }
    val manager = activity.getSystemService(NotificationManager::class.java)
    if ((Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) ||
        (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled())) {
      result.error("notification_permission_required", activity.getString(R.string.talk_record_notifications), null); return
    }
    if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel("talk_record_microphone")?.importance == NotificationManager.IMPORTANCE_NONE) {
      result.error("notification_channel_blocked", activity.getString(R.string.talk_record_notifications), null); return
    }
    if (!TalkRecordForegroundService.claim(requested)) {
      result.error("foreground_busy", activity.getString(R.string.talk_record_busy), null); return
    }
    token = requested
    pending = result
    bind(requested)
  }

  private fun bind(requested: String) {
    val intent = Intent(activity, TalkRecordForegroundService::class.java)
    val binding = TalkRecordServiceConnection(
      requested,
      owns = { owner, candidate -> token == owner && connection === candidate },
      connected = { current, binder ->
        val connectedService = (binder as TalkRecordForegroundService.LocalBinder).service
        service = connectedService
        try {
          check(resumed && activity.hasWindowFocus())
          // Binding alone is not foreground acknowledgement: begin must succeed.
          connectedService.begin(requested, false)
          connectedService.onUnexpectedStop = current.serviceStopped(connectedService) { service }
          clearTimeout()
          pending?.success(true); pending = null
        } catch (_: Exception) { fail("foreground_rejected", activity.getString(R.string.talk_record_rejected)) }
      },
      disconnected = { lost() },
      nullBinding = { fail("foreground_unavailable", activity.getString(R.string.talk_record_unavailable)) },
    )
    connection = binding
    try {
      if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(intent) else activity.startService(intent)
      check(activity.bindService(intent, binding, Context.BIND_AUTO_CREATE))
      val deadline = Runnable {
        if (token == requested && connection === binding) {
          fail("foreground_timeout", activity.getString(R.string.talk_record_timeout))
        }
      }
      timeout = deadline
      handler.postDelayed(deadline, 4000)
    } catch (_: Exception) { fail("foreground_rejected", activity.getString(R.string.talk_record_rejected)) }
  }

  private fun lost() {
    val owner = token ?: return
    fail("foreground_lost", activity.getString(R.string.talk_record_lost))
    channel.invokeMethod("lost", mapOf("token" to owner))
  }

  private fun fail(code: String, message: String) {
    pending?.error(code, message, null); pending = null
    release()
  }

  private fun release() {
    clearTimeout()
    val owner = token
    token = null
    val ownsService = owner != null && TalkRecordForegroundService.isClaimed(owner)
    if (ownsService && service != null) service!!.end(owner!!)
    service = null
    connection?.let { try { activity.unbindService(it) } catch (_: IllegalArgumentException) {} }
    connection = null
    // Explicitly targets our private service only, including partially failed startup.
    if (ownsService && TalkRecordForegroundService.releaseClaim(owner!!)) {
      activity.stopService(Intent(activity, TalkRecordForegroundService::class.java))
    }
  }

  fun dispose() {
    lost()
    channel.setMethodCallHandler(null)
  }
}
