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

    private companion object {
        const val REQUEST_VPN = 1
        const val REQUEST_NOTIFICATIONS = 2
    }
}
