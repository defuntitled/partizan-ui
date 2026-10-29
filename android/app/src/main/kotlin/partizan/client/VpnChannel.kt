package partizan.client

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import partizan.core.StatusListener
import partizan.core.VpnException
import partizan.core.VpnStatus
import partizan.core.checkUri
import partizan.core.status

/**
 * Platform channels behind the Dart `ChannelVpnBridge`: `partizan/vpn` answers calls into the
 * core, `partizan/vpn/status` streams every status change.
 */
object VpnChannel {
    private const val METHODS = "partizan/vpn"
    private const val EVENTS = "partizan/vpn/status"

    /** `check_uri` blocks for seconds while it tries the server. */
    private val checks = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(engine: FlutterEngine, activity: MainActivity) {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status().toMap())
                "start" -> {
                    val uri = call.argument<String>("uri")
                    if (uri == null) {
                        result.error("args", "uri is required", null)
                        return@setMethodCallHandler
                    }
                    val mtu = call.argument<Int>("mtu") ?: PartizanVpnService.DEFAULT_MTU
                    // Asks for the VPN permission first if the system has not granted it yet.
                    activity.withVpnPermission { granted ->
                        if (granted) {
                            PartizanVpnService.start(activity, uri, mtu)
                            result.success(null)
                        } else {
                            result.error("denied", "VPN permission denied", null)
                        }
                    }
                }
                "checkUri" -> {
                    val uri = call.argument<String>("uri") ?: ""
                    checks.execute {
                        try {
                            val r = checkUri(uri)
                            val map =
                                mapOf(
                                    "host" to r.host,
                                    "port" to r.port.toInt(),
                                    "quicMs" to r.quicMs?.toInt(),
                                    "tlsMs" to r.tlsMs?.toInt(),
                                )
                            main.post { result.success(map) }
                        } catch (e: VpnException.InvalidUri) {
                            main.post { result.error("invalid_uri", e.reason, null) }
                        } catch (e: VpnException) {
                            main.post { result.error("unreachable", e.message, null) }
                        }
                    }
                }
                "stop" -> {
                    PartizanVpnService.stop(activity)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, EVENTS).setStreamHandler(StatusHub)
    }
}

/**
 * Fans the core's status changes out to Dart and to the service's notification. It is the
 * listener the service hands to `start`; the core calls it on a background thread, everyone is
 * fed on the main one.
 */
object StatusHub : StatusListener, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private val observers = CopyOnWriteArrayList<(VpnStatus) -> Unit>()

    fun observe(observer: (VpnStatus) -> Unit) {
        observers.add(observer)
    }

    fun forget(observer: (VpnStatus) -> Unit) {
        observers.remove(observer)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        events.success(status().toMap())
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onStatus(status: VpnStatus) {
        main.post {
            sink?.success(status.toMap())
            observers.forEach { it(status) }
        }
    }
}

/** The map `VpnStatus.fromMap` reads on the Dart side. */
fun VpnStatus.toMap(): Map<String, Any?> =
    mapOf(
        "state" to state.name.lowercase(),
        "transport" to transport,
        "rttMs" to rttMs?.toInt(),
        "txBytes" to txBytes.toLong(),
        "rxBytes" to rxBytes.toLong(),
        "reconnects" to reconnects.toLong(),
        "error" to error,
    )
