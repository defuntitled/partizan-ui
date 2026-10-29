package partizan.client

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var pendingVpn: ((Boolean) -> Unit)? = null

    /** Where the tile or the widget asked the app to go, until Dart takes it. */
    private var target: String? = null

    /** Set by [VpnChannel]: hands a target to Dart while the app runs. */
    var onTarget: ((String) -> Unit)? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        target = intent?.getStringExtra(EXTRA_TARGET)
        super.onCreate(savedInstanceState)
        StatusHub.bind(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(EXTRA_TARGET)?.let { t -> onTarget?.invoke(t) ?: run { target = t } }
    }

    fun takeTarget(): String? = target.also { target = null }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VpnChannel.register(flutterEngine, this)
    }

    /**
     * Runs [then] with `true` once the user has allowed this app to be a VPN; the system dialog
     * shows only the first time (or after another VPN app took over).
     */
    fun withVpnPermission(then: (Boolean) -> Unit) {
        askNotifications()
        val consent = VpnService.prepare(this)
        if (consent == null) {
            then(true)
            return
        }
        pendingVpn?.invoke(false)
        pendingVpn = then
        startActivityForResult(consent, REQUEST_VPN)
    }

    @Deprecated("Activity result API of FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_VPN) {
            pendingVpn?.invoke(resultCode == RESULT_OK)
            pendingVpn = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    /** The tunnel's notification needs this on Android 13+; the tunnel works without it. */
    private fun askNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
        }
    }

    companion object {
        const val EXTRA_TARGET = "target"

        /** The server list: nothing to start. */
        const val TARGET_SERVERS = "servers"

        /** Start the active profile, asking for the VPN permission. */
        const val TARGET_CONNECT = "connect"

        private const val REQUEST_VPN = 1
        private const val REQUEST_NOTIFICATIONS = 2
    }
}
