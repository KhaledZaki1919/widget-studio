package com.khaled.widgetstudio.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.lifecycle.lifecycleScope
import com.khaled.widgetstudio.R
import com.khaled.widgetstudio.ui.LibraryScreen
import com.khaled.widgetstudio.ui.StudioTheme
import kotlinx.coroutines.launch

/**
 * Shown when a Widget Studio widget is added (and when it is reconfigured): pick any template;
 * the widget updates at once. A2 adds saved designs to this list.
 */
class ConfigureActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val appWidgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // Backing out leaves the widget unplaced.
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        enableEdgeToEdge()
        setContent {
            StudioTheme {
                LibraryScreen(title = getString(R.string.configure_title), onPick = { spec ->
                    WidgetStore(this).setTemplate(appWidgetId, spec.id)
                    lifecycleScope.launch {
                        val glanceId = GlanceAppWidgetManager(this@ConfigureActivity).getGlanceIdBy(appWidgetId)
                        SpecGlanceWidget().update(this@ConfigureActivity, glanceId)
                        MinuteTicker.schedule(this@ConfigureActivity)
                        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
                        finish()
                    }
                })
            }
        }
    }
}
