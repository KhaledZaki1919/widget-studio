package com.khaled.widgetstudio.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.khaled.widgetstudio.R
import com.khaled.widgetstudio.spec.DataSnapshot
import com.khaled.widgetstudio.spec.RenderContext
import com.khaled.widgetstudio.spec.TemplateLibrary
import com.khaled.widgetstudio.spec.WidgetSpec
import com.khaled.widgetstudio.widget.WidgetEnvironment
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId

/** The app's colors: the Mono red accent on black or white. */
@Composable
fun StudioTheme(content: @Composable () -> Unit) {
    val accent = Color(0xFFE2231A)
    val scheme = if (isSystemInDarkTheme()) darkColorScheme(primary = accent) else lightColorScheme(primary = accent)
    MaterialTheme(colorScheme = scheme, content = content)
}

/** A template drawn by the real renderer with sample data, like the iOS gallery previews. */
@Composable
fun TemplatePreview(spec: WidgetSpec, language: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val bitmap by produceState<ImageBitmap?>(null, spec.id, language) {
        value = withContext(Dispatchers.Default) {
            val now = Instant.now()
            val zone = ZoneId.systemDefault()
            val renderContext = RenderContext(now = now, language = language, zone = zone, data = DataSnapshot.sample(now, zone))
            val width = (spec.family.width * density).toInt()
            val height = (spec.family.height * density).toInt()
            WidgetEnvironment.renderer(context).render(spec, renderContext, width, height, cornerRadius = 22 * density).bitmap.asImageBitmap()
        }
    }
    Box(modifier.aspectRatio((spec.family.width / spec.family.height).toFloat())) {
        bitmap?.let { Image(it, contentDescription = spec.name.resolved(language), modifier = Modifier.fillMaxSize()) }
    }
}

/** Every template by category, previewed in Arabic or English (A1); tap opens nothing yet (A2: editor). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(onPick: ((WidgetSpec) -> Unit)? = null, title: String = stringResource(R.string.library_title)) {
    val context = LocalContext.current
    val library = remember { WidgetEnvironment.library(context) }
    var language by rememberSaveable { mutableStateOf(WidgetEnvironment.language(context)) }
    Scaffold(topBar = { TopAppBar(title = { Text(title) }) }) { padding ->
        LazyVerticalGrid(
            columns = GridCells.Adaptive(160.dp),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 8.dp, bottom = padding.calculateBottomPadding() + 24.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column {
                    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                        listOf("ar" to "العربية", "en" to "English").forEachIndexed { index, (code, label) ->
                            SegmentedButton(selected = language == code, onClick = { language = code }, shape = SegmentedButtonDefaults.itemShape(index, 2)) { Text(label) }
                        }
                    }
                    if (onPick == null) {
                        Spacer(Modifier.height(12.dp))
                        Text(stringResource(R.string.library_add_hint), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            for ((category, name) in TemplateLibrary.categories) {
                val specs = library.all.filter { it.category == category }
                if (specs.isEmpty()) continue
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Text(name.resolved(WidgetEnvironment.language(context)), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 12.dp))
                }
                items(specs, key = { it.id }, span = { spec -> GridItemSpan(if (spec.family.width > 200) maxLineSpan else 1) }) { spec ->
                    Card(
                        shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(),
                        modifier = Modifier.then(if (onPick != null) Modifier.clickable { onPick(spec) } else Modifier),
                    ) {
                        Column(Modifier.padding(10.dp)) {
                            TemplatePreview(spec, language, Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)))
                            Text(spec.name.resolved(WidgetEnvironment.language(context)), style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 8.dp))
                        }
                    }
                }
            }
        }
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { StudioTheme { LibraryScreen() } }
    }
}
