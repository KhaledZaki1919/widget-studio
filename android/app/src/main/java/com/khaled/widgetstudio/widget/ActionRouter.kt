package com.khaled.widgetstudio.widget

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.widget.Toast
import androidx.glance.GlanceId
import androidx.glance.action.Action
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import com.khaled.widgetstudio.data.MediaHub
import com.khaled.widgetstudio.data.settle
import com.khaled.widgetstudio.spec.Capabilities
import com.khaled.widgetstudio.spec.Capability
import com.khaled.widgetstudio.ui.MainActivity

/**
 * Every tap in a widget (ADR-027), by the catalog: actions that happen in place run a callback,
 * panels and apps start an activity, and what Android forbids shows the catalog's hint. An action
 * that needs a permission the user hasn't granted opens the screen that grants it.
 * `CapabilityCatalogTest` fails when a catalog action has no branch here.
 */
object ActionRouter {
    val idKey = ActionParameters.Key<String>("action")
    val argKey = ActionParameters.Key<String>("arg")

    /** Run in place by [Perform]. */
    val inPlace = setOf(
        "counter.increment", "counter.reset", "counter.next", "stopwatch.toggle", "timer.toggle", "timer.add", "timer.reset",
        "media.playPause", "media.next", "media.previous", "volume.up", "volume.down", "volume.mute", "volume.ringUp", "volume.ringDown",
        "brightness.up", "brightness.down", "system.toggle.torch", "system.toggle.silent", "system.toggle.rotation", "system.toggle.dnd",
    )

    /** Start an activity ([activity]). */
    val opens = setOf(
        "open.app", "open.url", "open.deeplink", "app.launch", "call.dial", "message.open", "shortcut.run", "camera.open", "qr.scan",
        "calendar.open", "compass.open", "weather.open", "media.open",
    )

    fun glance(context: Context, id: String, arg: String?): Action {
        val capability = Capabilities.action(id)
        if (capability == null || capability.supportAndroid == "unsupported") return hint(id, arg)
        if (id == "open.app") return actionStartActivity(MainActivity.intent(context, null))
        // Tiles from before ADR-027 name an iOS Shortcut: the torch still toggles right here.
        if (id == "shortcut.run" && WidgetActions.tileKind(arg ?: "") == WidgetActions.Tile.TORCH) {
            return actionRunCallback<Perform>(actionParametersOf(idKey to "system.toggle.torch", argKey to ""))
        }
        missingPermission(context, id)?.let { return actionStartActivity(it) }
        if (id in inPlace) return actionRunCallback<Perform>(actionParametersOf(idKey to id, argKey to (arg ?: "")))
        if (capability.supportAndroid == "panel" && id.startsWith("system.toggle")) return actionStartActivity(panel(context, capability))
        val intent = activity(context, id, arg) ?: return hint(id, arg)
        return actionStartActivity(intent)
    }

    private fun hint(id: String, arg: String?): Action = actionRunCallback<ShowHint>(actionParametersOf(idKey to id, argKey to (arg ?: "")))

    /** The settings screen to open first when a tap needs access that isn't granted. */
    fun missingPermission(context: Context, id: String): Intent? {
        val policy = context.getSystemService(NotificationManager::class.java)
        val intent = when {
            id in setOf("media.playPause", "media.next", "media.previous") && !MediaHub.isEnabled(context) -> Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            id in setOf("system.toggle.silent", "system.toggle.dnd") && policy?.isNotificationPolicyAccessGranted != true -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            id in setOf("system.toggle.rotation", "brightness.up", "brightness.down") && !Settings.System.canWrite(context) ->
                Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:${context.packageName}"))
            else -> null
        }
        return intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    fun panel(context: Context, capability: Capability): Intent {
        val modern = Build.VERSION.SDK_INT >= 29
        val intent = when (capability.panel) {
            "wifi" -> Intent(if (modern) Settings.Panel.ACTION_WIFI else Settings.ACTION_WIFI_SETTINGS)
            "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            "airplane" -> Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS)
            "mobileData" -> Intent(if (modern) Settings.Panel.ACTION_INTERNET_CONNECTIVITY else Settings.ACTION_DATA_ROAMING_SETTINGS)
            "display" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
            "batterySaver" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
            else -> MainActivity.intent(context, null)
        }
        return intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    /** The screen an opening action starts; null when its value isn't set (a hint says so). */
    fun activity(context: Context, id: String, arg: String?): Intent? {
        val value = arg?.trim().orEmpty()
        val intent = when (id) {
            "open.url" -> value.takeIf { it.startsWith("https://") || it.startsWith("http://") }?.let { Intent(Intent.ACTION_VIEW, Uri.parse(it)) }
            "open.deeplink" -> value.takeIf { it.contains(":") && !it.startsWith("file:") && !it.startsWith("javascript:") }?.let { Intent(Intent.ACTION_VIEW, Uri.parse(it)) }
            "app.launch" -> value.takeIf { it.isNotEmpty() }?.let { context.packageManager.getLaunchIntentForPackage(it) }
            "call.dial" -> value.takeIf { it.isNotEmpty() }?.let { Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(it))) }
            "message.open" -> value.takeIf { it.isNotEmpty() }?.let { Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:" + Uri.encode(it))) }
            "shortcut.run" -> shortcut(context, value)
            "camera.open", "qr.scan" -> Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
            "calendar.open" -> Intent(Intent.ACTION_VIEW, Uri.parse("content://com.android.calendar/time/${System.currentTimeMillis()}"))
            "compass.open" -> MainActivity.intent(context, MainActivity.OPEN_QIBLA)
            "weather.open" -> Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=weather"))
            "media.open" -> MediaHub.controller(context)?.packageName?.let { context.packageManager.getLaunchIntentForPackage(it) }
            else -> null
        }
        return intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    /** A tile named like an iOS Shortcut does the same thing here (the old tiles keep working). */
    private fun shortcut(context: Context, name: String): Intent? = when (val kind = WidgetActions.tileKind(name)) {
        WidgetActions.Tile.CUSTOM, WidgetActions.Tile.TORCH -> null
        else -> WidgetActions.tileIntent(context, kind)
    }

    /** Steps a stream one notch, keeping the system's own limits. */
    private fun adjust(context: Context, stream: Int, direction: Int) {
        context.getSystemService(AudioManager::class.java)?.adjustStreamVolume(stream, direction, 0)
    }

    private fun stepBrightness(context: Context, delta: Int) {
        val resolver = context.contentResolver
        val current = Settings.System.getInt(resolver, Settings.System.SCREEN_BRIGHTNESS, 128)
        Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
        Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS, (current + delta).coerceIn(5, 255))
    }

    /** Runs an in-place action. */
    suspend fun perform(context: Context, id: String, arg: String) {
        val live = WidgetEnvironment.live(context)
        when (id) {
            "counter.increment" -> live.counter = live.counter.increment(live.settings.dhikrs)
            "counter.reset" -> live.counter = live.counter.reset(live.settings.dhikrs)
            "counter.next" -> live.counter = live.counter.next(live.settings.dhikrs)
            "stopwatch.toggle" -> {
                live.stopwatchStart = if (live.stopwatchStart == null) System.currentTimeMillis() else null
                MinuteTicker.schedule(context)
            }
            "timer.toggle" -> live.timer = live.timer.toggle(arg.toIntOrNull())
            "timer.add" -> live.timer = live.timer.add(arg.toIntOrNull() ?: 5)
            "timer.reset" -> live.timer = live.timer.reset()
            "media.playPause", "media.next", "media.previous" -> if (!MediaHub.perform(context, id)) MediaHub.mediaKey(context, id)
            "volume.up" -> adjust(context, AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE)
            "volume.down" -> adjust(context, AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER)
            "volume.mute" -> adjust(context, AudioManager.STREAM_MUSIC, AudioManager.ADJUST_TOGGLE_MUTE)
            "volume.ringUp" -> adjust(context, AudioManager.STREAM_RING, AudioManager.ADJUST_RAISE)
            "volume.ringDown" -> adjust(context, AudioManager.STREAM_RING, AudioManager.ADJUST_LOWER)
            "brightness.up" -> stepBrightness(context, 25)
            "brightness.down" -> stepBrightness(context, -25)
            "system.toggle.torch" -> Torch.toggle(context)
            "system.toggle.silent" -> context.getSystemService(AudioManager::class.java)?.let { audio ->
                audio.ringerMode = if (audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) AudioManager.RINGER_MODE_SILENT else AudioManager.RINGER_MODE_NORMAL
            }
            "system.toggle.rotation" -> {
                val resolver = context.contentResolver
                val on = Settings.System.getInt(resolver, Settings.System.ACCELEROMETER_ROTATION, 1) != 0
                Settings.System.putInt(resolver, Settings.System.ACCELEROMETER_ROTATION, if (on) 0 else 1)
            }
            "system.toggle.dnd" -> context.getSystemService(NotificationManager::class.java)?.let { manager ->
                val quiet = manager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
                manager.setInterruptionFilter(if (quiet) NotificationManager.INTERRUPTION_FILTER_ALL else NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        }
        settle()
        Widgets.updateAll(context)
    }

    fun showHint(context: Context, id: String) {
        val language = WidgetEnvironment.language(context)
        val text = Capabilities.action(id)?.takeIf { it.supportAndroid == "unsupported" || it.hint != null }?.hintText(language)
            ?: Capabilities.action(id)?.let { capability ->
                val name = capability.title.resolved(language)
                if (language == "ar") "اضبط قيمة «$name» من المحرر أولًا." else "Set the value for $name in the editor first."
            }
        if (text != null) Handler(Looper.getMainLooper()).post { Toast.makeText(context.applicationContext, text, Toast.LENGTH_LONG).show() }
    }
}

/** Every in-place widget tap. */
class Perform : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val id = parameters[ActionRouter.idKey] ?: return
        ActionRouter.perform(context, id, parameters[ActionRouter.argKey] ?: "")
    }
}

/** A tap Android doesn't allow, or an action with no value yet: a clear message, never nothing. */
class ShowHint : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        parameters[ActionRouter.idKey]?.let { ActionRouter.showHint(context, it) }
    }
}

/** The torch toggles directly (CameraManager); its state is remembered between taps. */
object Torch {
    fun toggle(context: Context): Boolean {
        val manager = context.getSystemService(CameraManager::class.java) ?: return false
        val camera = manager.cameraIdList.firstOrNull { id ->
            manager.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        } ?: return false
        val prefs = context.getSharedPreferences("live", Context.MODE_PRIVATE)
        val on = !prefs.getBoolean("torch", false)
        return runCatching { manager.setTorchMode(camera, on) }.isSuccess.also { if (it) prefs.edit().putBoolean("torch", on).apply() }
    }
}
