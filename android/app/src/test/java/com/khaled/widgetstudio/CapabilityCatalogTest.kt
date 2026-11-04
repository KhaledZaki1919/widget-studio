package com.khaled.widgetstudio

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import com.khaled.widgetstudio.data.DeviceState
import com.khaled.widgetstudio.design.AutoWire
import com.khaled.widgetstudio.design.BindingCatalog
import com.khaled.widgetstudio.design.SpecValidator
import com.khaled.widgetstudio.render.Icons
import com.khaled.widgetstudio.spec.BindingResolver
import com.khaled.widgetstudio.spec.Capabilities
import com.khaled.widgetstudio.spec.DataSnapshot
import com.khaled.widgetstudio.spec.RenderContext
import com.khaled.widgetstudio.spec.SpecParser
import com.khaled.widgetstudio.spec.TemplateLibrary
import com.khaled.widgetstudio.spec.WiringScore
import com.khaled.widgetstudio.widget.ActionRouter
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.time.Instant
import java.time.ZoneId

/** The catalog is the single source of truth (ADR-027): these fail when something drifts or has no implementation. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CapabilityCatalogTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()

    @Before
    fun load() {
        Icons(app.assets)
        Capabilities.load(app.assets)
    }

    @Test
    fun theCatalogLoads() {
        assertTrue("capabilities.json did not load", Capabilities.bindings.size > 80 && Capabilities.actions.size > 30)
        assertEquals(Capabilities.bindings.filter { !it.parametric }.map { it.id }.toSet(), BindingCatalog.catalog.keys)
    }

    @Test
    fun everyActionHasABranch() {
        val router = ActionRouter.inPlace + ActionRouter.opens
        for (action in Capabilities.actions) {
            when (action.supportAndroid) {
                "unsupported" -> Unit
                "panel" -> assertTrue("${action.id}: panel without a target", action.panel != null || action.id in router)
                else -> assertTrue("${action.id} is native on Android but ActionRouter has no branch", action.id in router)
            }
        }
        for (id in router) assertNotNull("ActionRouter handles unknown action $id", Capabilities.action(id))
    }

    @Test
    fun everyNativeBindingHasAProvider() {
        val core = listOf("time.", "date.", "tz.", "weather.", "steps.", "sleep.", "counter.", "stopwatch.", "focus.", "timer.", "prayer.", "qibla.", "location.", "field.", "days.", "media.", "battery.level")
        for (binding in Capabilities.bindings) {
            if (binding.supportAndroid == "unsupported") continue
            assertTrue("${binding.id} has no provider", binding.id in DeviceState.provided || core.any { binding.id.startsWith(it) })
        }
        for (id in DeviceState.provided) assertNotNull("DeviceState fills unknown binding $id", Capabilities.binding(id))
    }

    @Test
    fun theExportedPromptAndSchemaListEveryId() {
        val prompt = app.assets.open("spec/ai/system_prompt.md").bufferedReader().readText()
        val schema = app.assets.open("spec/ai/schema.recreate.json").bufferedReader().readText()
        for (binding in Capabilities.bindings) if (binding.ai) assertTrue("prompt misses ${binding.id}", prompt.contains("{{${binding.id}}}"))
        for (action in Capabilities.actions) {
            if (!action.ai) continue
            assertTrue("prompt misses ${action.id}", prompt.contains("`${action.id}`"))
            assertTrue("schema misses ${action.id}", schema.contains("\"${action.id}\""))
        }
    }

    @Test
    fun previewsResolveEveryBinding() {
        val now = Instant.parse("2026-11-04T10:00:00Z")
        val zone = ZoneId.of("Africa/Cairo")
        val spec = TemplateLibrary(app.assets).all.first()
        val resolver = BindingResolver(spec, RenderContext(now = now, zone = zone, data = DataSnapshot.sample(now, zone)))
        for (binding in Capabilities.bindings) {
            if (binding.parametric || binding.type == "image" || binding.id == "counter.progress") continue
            assertNotNull("${binding.id} resolves to nothing", resolver.value(binding.id))
        }
    }

    @Test
    fun sharedAutoWireVectorsPass() {
        val file = File("../../ios/WidgetKitCore/Tests/WidgetKitCoreTests/Fixtures/AutoWire/vectors.json")
        val vectors = Json.parseToJsonElement(file.readText()).jsonArray
        assertTrue(vectors.size >= 8)
        for (entry in vectors) {
            val vector = entry.jsonObject
            val name = vector.getValue("name").jsonPrimitive.content
            val spec = SpecParser.spec(vector.getValue("spec").jsonObject)
            val inventory = (vector["inventory"] as? JsonArray)?.map { it.jsonPrimitive.content } ?: emptyList()
            val outcome = AutoWire.apply(spec, inventory)
            val ids = WiringScore.ids(outcome.spec)
            for (id in vector.getValue("wired").jsonArray) assertTrue("$name: ${id.jsonPrimitive.content} missing; got $ids; log ${outcome.changes}", id.jsonPrimitive.content in ids)
            for (id in (vector["notWired"] as? JsonArray) ?: emptyList()) assertTrue("$name: ${id.jsonPrimitive.content} must not be wired; log ${outcome.changes}", id.jsonPrimitive.content !in ids)
            assertEquals(name, emptyList<String>(), SpecValidator(ai = true, checksTextOverlaps = false).validate(outcome.spec))
            assertEquals("$name: not idempotent", outcome.spec, AutoWire.apply(outcome.spec, inventory).spec)
        }
    }
}
