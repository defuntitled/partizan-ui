package partizan.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.Executors
import partizan.core.SplitConfig
import partizan.core.SplitMode
import partizan.core.VpnConfig
import partizan.core.VpnException
import partizan.core.VpnState
import partizan.core.VpnStatus
import partizan.core.start as coreStart
import partizan.core.stop as coreStop

/**
 * The VPN: builds the TUN interface, hands its fd to the core and keeps a foreground
 * notification while the tunnel exists. The core owns the session; this service owns the
 * Android lifecycle around it.
 */
class PartizanVpnService : VpnService() {
    /** `stop` in the core blocks while the session closes: never on the main thread. */
    private val worker = Executors.newSingleThreadExecutor()
    private var running = false

    private val observer: (VpnStatus) -> Unit = { status ->
        if (running) notificationManager().notify(NOTIFICATION_ID, notification(status))
    }

    override fun onCreate() {
        super.onCreate()
        StatusHub.observe(observer)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val uri = intent.getStringExtra(EXTRA_URI)
                if (uri == null) {
                    stopSelf()
                } else {
                    up(uri, intent.getIntExtra(EXTRA_MTU, DEFAULT_MTU))
                }
            }
            ACTION_STOP -> down()
            // Restarted by the system without our intent (always-on comes in A11): nothing to
            // bring up without a profile.
            else -> if (!running) stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun up(uri: String, mtu: Int) {
        if (running) return
        val connecting = VpnStatus(VpnState.CONNECTING, null, null, 0uL, 0uL, 0uL, null)
        startForeground(connecting)
        val tun =
            try {
                Builder()
                    .setSession(getString(R.string.app_name))
                    .setMtu(mtu)
                    .addAddress(TUN_V4, 32)
                    .addAddress(TUN_V6, 128)
                    // Everything, DNS included, goes into the interface; split tunneling (A09)
                    // narrows the routes.
                    .addRoute("0.0.0.0", 0)
                    .addRoute("::", 0)
                    .addDnsServer(DNS_V4)
                    .addDnsServer(DNS_V6)
                    // The app's own sockets, the core's connection to the server among them,
                    // stay outside: no loop.
                    .addDisallowedApplication(packageName)
                    .setBlocking(false)
                    .establish()
            } catch (e: Exception) {
                fail("TUN: ${e.message}")
                return
            }
        if (tun == null) {
            fail("VPN permission was withdrawn")
            return
        }
        val config = VpnConfig(uri, SplitConfig(SplitMode.EXCLUDE, emptyList()), mtu.toUShort())
        try {
            // The core takes the fd over and closes it on stop.
            coreStart(tun.detachFd(), config, StatusHub)
            running = true
        } catch (e: VpnException) {
            fail(e.message ?: e.javaClass.simpleName)
        }
    }

    private fun down() {
        running = false
        worker.execute {
            coreStop()
            Handler(Looper.getMainLooper()).post {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }

    /** The user turned the VPN off in system settings, or another VPN took over. */
    override fun onRevoke() {
        Log.i(TAG, "VPN revoked by the system")
        down()
    }

    override fun onDestroy() {
        StatusHub.forget(observer)
        if (running) {
            running = false
            worker.execute { coreStop() }
        }
        worker.shutdown()
        super.onDestroy()
    }

    private fun fail(reason: String) {
        Log.w(TAG, "tunnel not started: $reason")
        running = false
        StatusHub.onStatus(VpnStatus(VpnState.ERROR, null, null, 0uL, 0uL, 0uL, reason))
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startForeground(status: VpnStatus) {
        notificationManager().createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.vpn_channel),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification(status),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification(status))
        }
    }

    private fun notification(status: VpnStatus): Notification {
        val open =
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            )
        val disconnect =
            PendingIntent.getService(
                this,
                1,
                Intent(this, PartizanVpnService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_IMMUTABLE,
            )
        val text =
            buildString {
                append(stateText(status.state))
                status.transport?.let { append(" · ").append(it.uppercase()) }
                status.rttMs?.let { append(" · ").append(it).append(" мс") }
            }
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_vpn)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(null, getString(R.string.disconnect), disconnect)
                    .build(),
            ).build()
    }

    private fun stateText(state: VpnState): String =
        getString(
            when (state) {
                VpnState.IDLE -> R.string.state_idle
                VpnState.CONNECTING -> R.string.state_connecting
                VpnState.CONNECTED -> R.string.state_connected
                VpnState.RECONNECTING -> R.string.state_reconnecting
                VpnState.REVOKED -> R.string.state_revoked
                VpnState.ERROR -> R.string.state_error
            },
        )

    private fun notificationManager() = getSystemService(NotificationManager::class.java)

    companion object {
        private const val TAG = "partizan"
        private const val ACTION_START = "partizan.client.START"
        private const val ACTION_STOP = "partizan.client.STOP"
        private const val EXTRA_URI = "uri"
        private const val EXTRA_MTU = "mtu"
        private const val CHANNEL_ID = "vpn"
        private const val NOTIFICATION_ID = 1
        const val DEFAULT_MTU = 1400

        // Interface addresses: private ranges, never seen beyond the device.
        private const val TUN_V4 = "10.111.0.2"
        private const val TUN_V6 = "fd00:111::2"

        // Resolvers the system is told to use; their queries travel through the tunnel.
        private const val DNS_V4 = "1.1.1.1"
        private const val DNS_V6 = "2606:4700:4700::1111"

        fun start(context: Context, uri: String, mtu: Int) {
            val intent =
                Intent(context, PartizanVpnService::class.java)
                    .setAction(ACTION_START)
                    .putExtra(EXTRA_URI, uri)
                    .putExtra(EXTRA_MTU, mtu)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, PartizanVpnService::class.java).setAction(ACTION_STOP),
            )
        }
    }
}
