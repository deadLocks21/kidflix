package fr.dtfh.kidflix

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth:
// its BiometricPrompt needs a FragmentActivity host. The kids-lock channel
// below is unaffected — startLockTask / stopLockTask live on Activity.
class MainActivity : FlutterFragmentActivity() {
    private val lockChannel = "fr.dtfh.kidflix/app_lock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, lockChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLockTask" -> {
                        try {
                            startLockTask()
                            result.success(true)
                        } catch (_: IllegalStateException) {
                            result.success(false)
                        } catch (_: SecurityException) {
                            result.success(false)
                        }
                    }
                    "stopLockTask" -> {
                        try {
                            stopLockTask()
                            result.success(true)
                        } catch (_: IllegalStateException) {
                            result.success(false)
                        } catch (_: SecurityException) {
                            result.success(false)
                        }
                    }
                    "isLockTaskMode" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val locked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
                        } else {
                            @Suppress("DEPRECATION")
                            am.isInLockTaskMode
                        }
                        result.success(locked)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
