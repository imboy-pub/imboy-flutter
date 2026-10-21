package pub.imboy.app

import android.content.ComponentName
import android.content.ServiceConnection
import android.os.IBinder

/** Reject queued callbacks from a released binding before they mutate any current session. */
internal class TalkRecordServiceConnection(
  private val requested: String,
  private val owns: (String, ServiceConnection) -> Boolean,
  private val connected: (TalkRecordServiceConnection, IBinder) -> Unit,
  private val disconnected: () -> Unit,
  private val nullBinding: () -> Unit,
) : ServiceConnection {
  fun isCurrent(): Boolean = owns(requested, this)

  fun serviceStopped(expected: Any, current: () -> Any?): () -> Unit = {
    if (isCurrent() && current() === expected) disconnected()
  }

  override fun onServiceConnected(name: ComponentName?, binder: IBinder) {
    if (isCurrent()) connected(this, binder)
  }

  override fun onServiceDisconnected(name: ComponentName?) {
    if (isCurrent()) disconnected()
  }

  override fun onBindingDied(name: ComponentName?) {
    if (isCurrent()) disconnected()
  }

  override fun onNullBinding(name: ComponentName?) {
    if (isCurrent()) nullBinding()
  }
}
