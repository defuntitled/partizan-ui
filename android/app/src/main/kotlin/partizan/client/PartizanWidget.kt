package partizan.client

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import partizan.core.status

/** The home screen widget: state, active server, a button (A10). */
class PartizanWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        StatusHub.bind(context)
        manager.updateAppWidget(ids, Surfaces.widget(context, status()))
    }
}
