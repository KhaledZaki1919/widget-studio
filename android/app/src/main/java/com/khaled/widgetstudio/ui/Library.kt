package com.khaled.widgetstudio.ui

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.khaled.widgetstudio.data.RefreshWorker
import com.khaled.widgetstudio.design.DesignStore
import com.khaled.widgetstudio.design.LayoutRepair
import com.khaled.widgetstudio.design.SavedDesign
import com.khaled.widgetstudio.spec.RenderContext
import com.khaled.widgetstudio.spec.TemplateLibrary
import com.khaled.widgetstudio.spec.WidgetSpec
import com.khaled.widgetstudio.widget.WidgetEnvironment
import com.khaled.widgetstudio.widget.Widgets
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WidgetEnvironment.renderer(this)   // loads the fonts and the icon whitelist
        RefreshWorker.schedule(this)
        com.khaled.widgetstudio.widget.WidgetPreviews.publish(this)
        setContent { StudioTheme { AppRoot(opening(intent)) } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val open = opening(intent)
        setContent { StudioTheme { AppRoot(open) } }
    }

    /** What an intent asks to show; shared text or a .json file goes to the import screen. */
    private fun opening(intent: Intent?): String? {
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: streamText(intent.getParcelableExtra(Intent.EXTRA_STREAM))
                if (text != null) { PendingImport.text = text; return OPEN_IMPORT }
            }
            Intent.ACTION_VIEW -> streamText(intent.data)?.let { PendingImport.text = it; return OPEN_IMPORT }
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE", "android.intent.action.VIEW_PERMISSION_USAGE" -> {
                val anchor = if (WidgetEnvironment.language(this) == "ar") "ar" else "en"
                startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://khaledzaki1919.github.io/widget-studio/privacy.html#$anchor")))
                finish()
                return null
            }
        }
        return intent?.getStringExtra(EXTRA_OPEN)
    }

    @Suppress("DEPRECATION")
    private fun streamText(uri: android.net.Uri?): String? = uri?.let {
        runCatching { contentResolver.openInputStream(it)?.use { stream -> com.khaled.widgetstudio.ai.ExternalAI.read(stream) } }.getOrNull()
    }

    companion object {
        const val EXTRA_OPEN = "open"
        const val OPEN_SETTINGS = "settings"
        const val OPEN_QIBLA = "qibla"
        const val OPEN_IMPORT = "import"

        fun intent(context: Context, open: String?) = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_OPEN, open).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }
}

/** Full-screen flows over the tabs. */
sealed class Overlay {
    data class Editor(val state: EditorState, val layout: LayoutRepair? = null, val onRegenerate: (() -> Unit)? = null) : Overlay()
    data object Qibla : Overlay()
    data object Create : Overlay()
    data object Onboarding : Overlay()
}

enum class Tab { LIBRARY, MY_WIDGETS, SETTINGS }

@Composable
fun AppRoot(open: String?) {
    val context = LocalContext.current
    val live = remember { WidgetEnvironment.live(context) }
    var tab by rememberSaveable { mutableStateOf(if (open == MainActivity.OPEN_SETTINGS) Tab.SETTINGS else Tab.LIBRARY) }
    var overlay by remember { mutableStateOf<Overlay?>(if (!live.settings.onboardingDone) Overlay.Onboarding else if (open == MainActivity.OPEN_QIBLA) Overlay.Qibla else if (open == MainActivity.OPEN_IMPORT) Overlay.Create else null) }
    LaunchedEffect(Unit) {
        live.refresh()
        Widgets.updateAll(context)
    }
    val language = appLanguage()
    fun edit(design: SavedDesign, isNew: Boolean, photo: Bitmap? = null) {
        overlay = Overlay.Editor(EditorState(design, isNew, photo))
    }
    when (val current = overlay) {
        is Overlay.Editor -> EditorScreen(current.state, onClose = { overlay = null }, onSaved = { overlay = null; tab = Tab.MY_WIDGETS }, layout = current.layout, onRegenerate = current.onRegenerate)
        Overlay.Qibla -> QiblaScreen(onClose = { overlay = null })
        Overlay.Create -> CreateScreen(
            onClose = { overlay = null },
            onResult = { design, photo, layout, regenerate -> overlay = Overlay.Editor(EditorState(design, true, photo), layout, regenerate) },
            onCreatedAll = { overlay = null; tab = Tab.MY_WIDGETS },
        )
        Overlay.Onboarding -> OnboardingScreen(onFinish = { live.settings.onboardingDone = true; overlay = null })
        null -> Scaffold(bottomBar = {
            NavigationBar {
                NavigationBarItem(selected = tab == Tab.LIBRARY, onClick = { tab = Tab.LIBRARY }, icon = { MaterialSymbol("grid_view") }, label = { Text(tr("Library", "المكتبة")) })
                NavigationBarItem(selected = tab == Tab.MY_WIDGETS, onClick = { tab = Tab.MY_WIDGETS }, icon = { MaterialSymbol("widgets") }, label = { Text(tr("My widgets", "ودجاتي")) })
                NavigationBarItem(selected = tab == Tab.SETTINGS, onClick = { tab = Tab.SETTINGS }, icon = { MaterialSymbol("settings") }, label = { Text(tr("Settings", "الإعدادات")) })
            }
        }) { padding ->
            Box(Modifier.padding(bottom = padding.calculateBottomPadding())) {
                when (tab) {
                    Tab.LIBRARY -> LibraryScreen(onPick = { spec -> edit(SavedDesign.new(spec, language), true) }, onCreate = { overlay = Overlay.Create })
                    Tab.MY_WIDGETS -> MyWidgetsScreen(onEdit = { edit(it, false) }, onBrowse = { tab = Tab.LIBRARY }, onCreate = { overlay = Overlay.Create })
                    Tab.SETTINGS -> SettingsScreen(onQibla = { overlay = Overlay.Qibla }, onIntroduction = { overlay = Overlay.Onboarding })
                }
            }
        }
    }
}

/** A raw Material Symbols glyph (not limited to the spec's icon whitelist). */
@Composable
fun MaterialSymbol(name: String, size: Int = 24) {
    val context = LocalContext.current
    val family = remember { FontFamily(androidx.compose.ui.text.font.Font("fonts/MaterialSymbolsRounded-Filled.ttf", context.assets)) }
    Text(name, fontFamily = family, fontSize = size.sp, textAlign = TextAlign.Center)
}

/** A template previewed with real data where there is some, like the iOS gallery. */
@Composable
fun TemplatePreview(spec: WidgetSpec, language: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    SpecPreview(spec, spec.id + language, modifier) {
        val now = Instant.now()
        val live = WidgetEnvironment.live(context)
        RenderContext(now = now, language = language, zone = ZoneId.systemDefault(), data = live.previewSnapshot(now), uses24Hour = live.settings.clockFormat.uses24Hour(context))
    }
}

/** Every template by category; a tap opens it in the editor as a new design. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(onPick: (WidgetSpec) -> Unit, onCreate: () -> Unit) {
    val context = LocalContext.current
    val library = remember { WidgetEnvironment.library(context) }
    val appLang = appLanguage()
    var language by rememberSaveable { mutableStateOf(appLang) }
    Scaffold(topBar = { TopAppBar(title = { Text(tr("Library", "المكتبة")) }) }) { padding ->
        LazyVerticalGrid(
            columns = GridCells.Adaptive(160.dp),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 8.dp, bottom = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(onClick = onCreate, modifier = Modifier.fillMaxWidth()) { Text(tr("Create from image", "صمّم من صورة")) }
                    Segmented(listOf("ar" to "العربية", "en" to "English"), language, { language = it })
                    Footnote(tr("To add a widget: long-press the home screen → Widgets → Widget Studio, then choose a design. Resize it as you like.", "لإضافة ويدجت: اضغط مطولًا على الشاشة الرئيسية ← الأدوات ← ستوديو الويدجت، ثم اختر تصميمًا. غيّر حجمه كما تريد."))
                }
            }
            for ((category, name) in TemplateLibrary.categories) {
                val specs = library.all.filter { it.category == category }
                if (specs.isEmpty()) continue
                item(span = { GridItemSpan(maxLineSpan) }) { Text(name.resolved(appLang), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 12.dp)) }
                items(specs, key = { it.id }, span = { spec -> GridItemSpan(if (spec.family.width > 200) maxLineSpan else 1) }) { spec ->
                    Card(shape = RoundedCornerShape(16.dp), modifier = Modifier.clickable { onPick(spec) }) {
                        Column(Modifier.padding(10.dp)) {
                            TemplatePreview(spec, language, Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)))
                            Text(spec.name.resolved(appLang), style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 8.dp))
                        }
                    }
                }
            }
        }
    }
}

/** Saved designs: edit, rename, duplicate, delete. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyWidgetsScreen(onEdit: (SavedDesign) -> Unit, onBrowse: () -> Unit, onCreate: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = remember { DesignStore.get(context) }
    val designs by store.designs.collectAsState()
    val language = appLanguage()
    val copySuffix = tr(" copy", " (نسخة)")
    var renaming by remember { mutableStateOf<SavedDesign?>(null) }
    var deleting by remember { mutableStateOf<SavedDesign?>(null) }
    Scaffold(topBar = { TopAppBar(title = { Text(tr("My widgets", "ودجاتي")) }) }) { padding ->
        if (designs.isEmpty()) {
            Column(Modifier.fillMaxSize().padding(padding).padding(32.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                MaterialSymbol("widgets", 56)
                Spacer(Modifier.height(12.dp))
                Text(tr("No designs yet", "لا توجد تصاميم بعد"), style = MaterialTheme.typography.titleMedium)
                Text(tr("Customize a template or create one from an image. Saved designs appear here and in the widget's design list.", "خصّص قالبًا أو صمّم من صورة. تظهر التصاميم المحفوظة هنا وفي قائمة تصاميم الويدجت."),
                    textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 12.dp))
                Button(onClick = onBrowse) { Text(tr("Browse templates", "تصفح القوالب")) }
                OutlinedButton(onClick = onCreate, modifier = Modifier.padding(top = 8.dp)) { Text(tr("Create from image", "صمّم من صورة")) }
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(160.dp),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 8.dp, bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(designs, key = { it.id }, span = { GridItemSpan(if (it.spec.family.width > 200) maxLineSpan else 1) }) { design ->
                    var menu by remember { mutableStateOf(false) }
                    Card(shape = RoundedCornerShape(16.dp), modifier = Modifier.clickable { onEdit(design) }) {
                        Column(Modifier.padding(10.dp)) {
                            DesignPreview(design, language, store.image(design), Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(design.name, style = MaterialTheme.typography.labelLarge, modifier = Modifier.weight(1f), maxLines = 1)
                                Box {
                                    TextButton(onClick = { menu = true }, modifier = Modifier.width(48.dp)) { Text("⋯") }
                                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                                        DropdownMenuItem(text = { Text(tr("Edit", "تعديل")) }, onClick = { menu = false; onEdit(design) })
                                        DropdownMenuItem(text = { Text(tr("Rename", "إعادة التسمية")) }, onClick = { menu = false; renaming = design })
                                        DropdownMenuItem(text = { Text(tr("Duplicate", "تكرار")) }, onClick = { menu = false; store.duplicate(design, copySuffix) })
                                        DropdownMenuItem(text = { Text(tr("Delete", "حذف"), color = MaterialTheme.colorScheme.error) }, onClick = { menu = false; deleting = design })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    renaming?.let { design ->
        var name by remember(design.id) { mutableStateOf(design.name) }
        AlertDialog(
            onDismissRequest = { renaming = null }, title = { Text(tr("Rename", "إعادة التسمية")) },
            text = { OutlinedTextField(name, { name = it.take(SavedDesign.MAX_NAME_LENGTH) }, singleLine = true) },
            confirmButton = {
                TextButton(enabled = name.isNotBlank(), onClick = {
                    store.save(design.copy(name = name.trim()))
                    renaming = null
                    scope.launch { Widgets.updateAll(context) }
                }) { Text(tr("Save", "حفظ")) }
            },
            dismissButton = { TextButton(onClick = { renaming = null }) { Text(tr("Cancel", "إلغاء")) } },
        )
    }
    deleting?.let { design ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text(tr("Delete “${design.name}”?", "حذف «${design.name}»؟")) },
            text = { Text(tr("Widgets showing it will ask you to choose another design.", "الودجات التي تعرضه ستطلب منك اختيار تصميم آخر.")) },
            confirmButton = {
                TextButton(onClick = {
                    store.delete(design.id)
                    deleting = null
                    scope.launch { Widgets.updateAll(context) }
                }) { Text(tr("Delete", "حذف"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deleting = null }) { Text(tr("Cancel", "إلغاء")) } },
        )
    }
}
