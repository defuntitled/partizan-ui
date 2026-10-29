package partizan.client

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.service.quicksettings.TileService
import android.widget.RemoteViews
import partizan.core.VpnState
import partizan.core.VpnStatus

/**
 * The tile and the home screen widget (A10): both mirror the core's [VpnState], as the app
 * and the notification do, and act through [QuickAction].
 */
object Surfaces {
    fun tunnelUp(state: VpnState) =
        state == VpnState.CONNECTING || state == VpnState.CONNECTED || state == VpnState.RECONNECTING

    fun action(context: Context, status: VpnStatus): QuickAction =
        QuickAction.decide(
            tunnelUp(status.state),
            Launch.read(context) != null,
            VpnService.prepare(context) == null,
        )

    /** Redraws both after a status change or a new active profile. */
    fun update(context: Context, status: VpnStatus) {
        TileService.requestListeningState(
            context,
            ComponentName(context, PartizanTileService::class.java),
        )
        val widgets = AppWidgetManager.getInstance(context)
        val ids = widgets.getAppWidgetIds(ComponentName(context, PartizanWidget::class.java))
        if (ids.isNotEmpty()) widgets.updateAppWidget(ids, widget(context, status))
    }

    fun widget(context: Context, status: VpnStatus): RemoteViews {
        val launch = Launch.read(context)
        val views = RemoteViews(context.packageName, R.layout.widget)
        views.setTextViewText(
            R.id.widget_server,
            launch?.name ?: context.getString(R.string.no_server),
        )
        views.setTextViewText(R.id.widget_state, stateText(context, status.state))
        views.setTextViewText(
            R.id.widget_button,
            context.getString(if (tunnelUp(status.state)) R.string.disconnect else R.string.connect),
        )
        views.setOnClickPendingIntent(R.id.widget_button, tap(context, action(context, status)))
        views.setOnClickPendingIntent(R.id.widget_root, open(context, null))
        return views
    }

    /** What a tap does, decided when the widget is drawn; the service re-checks. */
    private fun tap(context: Context, action: QuickAction): PendingIntent =
        when (action) {
            QuickAction.STOP, QuickAction.START ->
                PendingIntent.getForegroundService(
                    context,
                    REQUEST_TOGGLE,
                    PartizanVpnService.toggleIntent(context),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
            QuickAction.OPEN_SERVERS -> open(context, MainActivity.TARGET_SERVERS)
            QuickAction.OPEN_FOR_PERMISSION -> open(context, MainActivity.TARGET_CONNECT)
        }

    fun open(context: Context, target: String?): PendingIntent =
        PendingIntent.getActivity(
            context,
            target.hashCode(),
            openIntent(context, target),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    fun openIntent(context: Context, target: String?): Intent =
        Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .apply { if (target != null) putExtra(MainActivity.EXTRA_TARGET, target) }

    fun stateText(context: Context, state: VpnState): String =
        context.getString(
            when (state) {
                VpnState.IDLE -> R.string.state_idle
                VpnState.CONNECTING -> R.string.state_connecting
                VpnState.CONNECTED -> R.string.state_connected
                VpnState.RECONNECTING -> R.string.state_reconnecting
                VpnState.REVOKED -> R.string.state_revoked
                VpnState.ERROR -> R.string.state_error
            },
        )

    private const val REQUEST_TOGGLE = 10
}
