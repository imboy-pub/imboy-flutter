package pub.imboy.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder

/** Only maintains the user-visible microphone foreground lifetime; owns no recorder. */
class TalkRecordForegroundService : Service() {
  class LocalBinder(val service: TalkRecordForegroundService) : Binder()
  private var owner: String? = null
  var onUnexpectedStop: (() -> Unit)? = null

  override fun onBind(intent: Intent): IBinder = LocalBinder(this)
  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY

  fun begin(token: String, paused: Boolean) {
    check(isClaimed(token)) { "Recording service claim lost" }
    check(owner == null || owner == token) { "Another recording owns this service" }
    val manager = getSystemService(NotificationManager::class.java)
    if (Build.VERSION.SDK_INT >= 26) {
      manager.createNotificationChannel(NotificationChannel(
        CHANNEL, getString(R.string.talk_record_channel), NotificationManager.IMPORTANCE_LOW
      ))
    }
    val launch = Intent(this, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val pending = PendingIntent.getActivity(this, 7311, launch,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
      else Notification.Builder(this)
    val notification = builder.setSmallIcon(android.R.drawable.ic_btn_speak_now)
      .setContentTitle(getString(if (paused) R.string.talk_record_paused else R.string.talk_record_recording))
      .setContentText(getString(R.string.talk_record_return))
      .setContentIntent(pending).setOngoing(true).setCategory(Notification.CATEGORY_SERVICE)
      .build()
    if (Build.VERSION.SDK_INT >= 30) {
      startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
    } else startForeground(ID, notification)
    owner = token
  }

  fun end(token: String) {
    if (owner == null) return
    check(owner == token) { "Recording service ownership mismatch" }
    owner = null
    onUnexpectedStop = null
    if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
      else @Suppress("DEPRECATION") stopForeground(true)
    stopSelf()
  }

  override fun onDestroy() {
    val callback = if (owner != null) onUnexpectedStop else null
    owner = null
    onUnexpectedStop = null
    callback?.invoke()
    super.onDestroy()
  }

  companion object {
    private var claimedOwner: String? = null
    @Synchronized fun claim(token: String): Boolean {
      if (claimedOwner != null) return false
      claimedOwner = token
      return true
    }
    @Synchronized fun isClaimed(token: String): Boolean = claimedOwner == token
    @Synchronized fun releaseClaim(token: String): Boolean {
      if (claimedOwner != token) return false
      claimedOwner = null
      return true
    }
    private const val CHANNEL = "talk_record_microphone"
    private const val ID = 7311
  }
}
