package com.khaled.widgetstudio.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.Action
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.khaled.widgetstudio.R
import com.khaled.widgetstudio.render.SpecRenderer
import com.khaled.widgetstudio.spec.DataSnapshot
import com.khaled.widgetstudio.spec.RenderContext
import com.khaled.widgetstudio.spec.TemplateLibrary
import com.khaled.widgetstudio.ui.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

/** The app-wide renderer and template library (created once per process). */
object WidgetEnvironment {
    @Volatile private var renderer: SpecRenderer? = null
    @Volatile private var library: TemplateLibrary? = null

    fun renderer(context: Context) = renderer ?: SpecRenderer(context.applicationContext).also { renderer = it }
    fun library(context: Context) = library ?: TemplateLibrary(context.applicationContext.assets).also { library = it }

    /** "en" when the app runs in English, else Arabic (the default). */
    fun language(context: Context): String =
        if (context.resources.configuration.locales[0].language == "en") "en" else "ar"
}

/** Which template each placed widget shows (A2 adds saved designs). */
class WidgetStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("widgets", Context.MODE_PRIVATE)

    fun templateId(appWidgetId: Int): String? = prefs.getString("template.$appWidgetId", null)
    fun setTemplate(appWidgetId: Int, id: String) = prefs.edit().putString("template.$appWidgetId", id).apply()
    fun remove(appWidgetId: Int) = prefs.edit().remove("template.$appWidgetId").apply()
}

/**
 * The home-screen widget (ADR-025): the chosen spec drawn into a bitmap at the widget's exact
 * size (re-rendered whenever the size changes), shown with Glance, with a transparent tap area
 * over each button layer. Real data arrives in A3; until then missing values show "--", never
 * sample numbers.
 */
class SpecGlanceWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val templateId = WidgetStore(context).templateId(appWidgetId)
        provideContent { Content(context, templateId, appWidgetId) }
    }

    @Composable
    private fun Content(context: Context, templateId: String?, appWidgetId: Int) {
        val spec = templateId?.let { WidgetEnvironment.library(context).template(it) }
        val size = LocalSize.current
        if (spec == null) {
            Box(
                modifier = GlanceModifier.fillMaxSize().appWidgetBackground().background(ColorProvider(R.color.widget_empty))
                    .clickable(actionStartActivity(configureIntent(context, appWidgetId))),
                contentAlignment = Alignment.Center,
            ) {
                Text(context.getString(R.string.widget_choose), style = TextStyle(color = ColorProvider(R.color.widget_empty_text), textAlign = TextAlign.Center))
            }
            return
        }
        val density = context.resources.displayMetrics.density
        val width = (size.width.value * density).toInt()
        val height = (size.height.value * density).toInt()
        val renderContext = RenderContext(
            now = Instant.now(), language = WidgetEnvironment.language(context), zone = ZoneId.systemDefault(),
            data = DataSnapshot(batteryLevel = batteryLevel(context)), freezesLiveText = true,
        )
        // Before Android 12 the launcher doesn't round widgets: clip the bitmap ourselves.
        val radius = if (Build.VERSION.SDK_INT < 31) 16 * density else 0f
        val result = WidgetEnvironment.renderer(context).render(spec, renderContext, width, height, cornerRadius = radius)
        var modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
        if (Build.VERSION.SDK_INT >= 31) modifier = modifier.cornerRadius(android.R.dimen.system_app_widget_background_radius)
        Box(modifier = modifier) {
            Image(
                provider = ImageProvider(result.bitmap), contentDescription = spec.name.resolved(renderContext.language),
                modifier = GlanceModifier.fillMaxSize(), contentScale = ContentScale.FillBounds,
            )
            for (button in result.buttons) {
                Box(modifier = GlanceModifier.padding(start = (button.rect.left / density).dp, top = (button.rect.top / density).dp)) {
                    Box(modifier = GlanceModifier.size((button.rect.width() / density).dp, (button.rect.height() / density).dp).clickable(action(context, button.action, button.arg))) {}
                }
            }
        }
    }

    /** Links open http(s) pages; everything else opens the app (counters, stopwatch and tiles come in A3). */
    private fun action(context: Context, action: String, arg: String?): Action {
        if (action == "open.url" && arg != null && (arg.startsWith("https://") || arg.startsWith("http://"))) {
            return actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse(arg)))
        }
        return actionStartActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun configureIntent(context: Context, appWidgetId: Int) = Intent(context, ConfigureActivity::class.java)
        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    private fun batteryLevel(context: Context): Double? {
        val manager = context.getSystemService(BatteryManager::class.java) ?: return null
        val percent = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        return if (percent in 0..100) percent / 100.0 else null
    }
}

class SpecWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = SpecGlanceWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        MinuteTicker.schedule(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        MinuteTicker.cancel(context)
    }

    // Also after a reboot, when the launcher asks for updates again.
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        MinuteTicker.schedule(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val store = WidgetStore(context)
        appWidgetIds.forEach(store::remove)
    }
}

/**
 * Clocks and dates re-render once a minute (ADR-025): a windowed alarm at the start of each
 * minute updates every placed widget. TextClock/Chronometer format digits with the phone's locale
 * (Arabic-Indic on ar-EG), which the dot font can't draw, so A1 keeps time in the bitmap.
 */
object MinuteTicker {
    private const val ACTION = "com.khaled.widgetstudio.TICK"

    fun schedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val next = (System.currentTimeMillis() / 60_000 + 1) * 60_000
        alarms.setWindow(AlarmManager.RTC, next, 5_000, pending(context))
    }

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java)?.cancel(pending(context))
    }

    private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, 0, Intent(context, TickReceiver::class.java).setAction(ACTION), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    fun hasWidgets(context: Context): Boolean =
        AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, SpecWidgetReceiver::class.java)).isNotEmpty()
}

class TickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!MinuteTicker.hasWidgets(context)) return
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            try {
                SpecGlanceWidget().updateAll(context)
            } finally {
                MinuteTicker.schedule(context)
                pending.finish()
            }
        }
    }
}
