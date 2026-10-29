package partizan.client

import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import partizan.core.VpnStatus
import partizan.core.status

/**
 * The Quick Settings tile: brings the active profile up or the tunnel down (A10). A long
 * press opens the app (`QS_TILE_PREFERENCES` on [MainActivity]).
 */
class PartizanTileService : TileService() {
    /**
     * While the tile is shown it redraws on every status itself: `requestListeningState`
     * does nothing for a tile that is already listening, so the change would not show.
     */
    private val observer: (VpnStatus) -> Unit = { status -> render(status) }

    override fun onStartListening() {
        super.onStartListening()
        StatusHub.bind(this)
        StatusHub.observe(observer)
        render(status())
    }

    override fun onStopListening() {
        StatusHub.forget(observer)
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        StatusHub.bind(this)
        when (Surfaces.action(this, status())) {
            QuickAction.STOP, QuickAction.START -> startForegroundService(PartizanVpnService.toggleIntent(this))
            QuickAction.OPEN_SERVERS -> openApp(MainActivity.TARGET_SERVERS)
            QuickAction.OPEN_FOR_PERMISSION -> openApp(MainActivity.TARGET_CONNECT)
        }
    }

    private fun render(status: VpnStatus) {
        val tile = qsTile ?: return
        tile.state = if (Surfaces.tunnelUp(status.state)) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = getString(R.string.app_name)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = Launch.read(this)?.name ?: getString(R.string.no_server)
        }
        tile.contentDescription = Surfaces.stateText(this, status.state)
        tile.updateTile()
    }

    private fun openApp(target: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(Surfaces.open(this, target))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(Surfaces.openIntent(this, target))
        }
    }
}
