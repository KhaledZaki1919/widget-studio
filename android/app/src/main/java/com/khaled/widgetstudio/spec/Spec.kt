package com.khaled.widgetstudio.spec

/**
 * The widget spec (brief §4), the same JSON the iOS app reads (WidgetKitCore/Spec). Every change
 * to the spec must update both models and both renderers (ADR-025).
 */
data class WidgetSpec(
    val schemaVersion: Int,
    val id: String,
    val name: LText,
    val family: Family,
    val theme: Theme,
    val refresh: String,
    val background: Background,
    val fields: List<FieldSpec>,
    val layers: List<Layer>,
    val category: String?,
    /** Elements that look live but aren't, with why (prompt v5's wiring list, ADR-027). */
    val decorative: List<DecorativeNote> = emptyList(),
) {
    fun field(key: String): FieldSpec? = fields.firstOrNull { it.key == key }
}

data class DecorativeNote(val element: String, val reason: String)

enum class Family(val width: Double, val height: Double) {
    SMALL(170.0, 170.0), MEDIUM(364.0, 170.0), LARGE(364.0, 382.0);

    companion object {
        fun of(raw: String): Family = when (raw) {
            "medium" -> MEDIUM
            "large" -> LARGE
            else -> SMALL
        }
    }
}

enum class Theme { LIGHT, DARK }

/** A visible text: one string, or English and Arabic. */
sealed class LText {
    data class Plain(val text: String) : LText()
    data class Localized(val en: String, val ar: String) : LText()

    fun resolved(language: String): String = when (this) {
        is Plain -> text
        is Localized -> if (language.startsWith("ar")) ar else en
    }

    val allValues: List<String>
        get() = when (this) {
            is Plain -> listOf(text)
            is Localized -> listOf(en, ar)
        }
}

data class Background(
    val type: String,
    val color: String?,
    val colors: List<String>?,
    val angle: Double?,
    val outerColor: String?,
    /** With `outerColor`: `circle` (default) or `capsule` (ADR-024). */
    val cardShape: String?,
)

data class FieldSpec(val key: String, val type: String, val label: LText, val default: LText?)

data class Frame(val x: Double, val y: Double, val w: Double, val h: Double) {
    fun mirrored(canvasWidth: Double) = Frame(canvasWidth - x - w, y, w, h)
}

data class FontSpec(val family: String, val size: Double, val weight: String?)

data class Layer(
    val frame: Frame,
    val opacity: Double?,
    val mirror: Boolean?,
    val condition: String?,
    val rotation: String?,
    val content: LayerContent,
) {
    /** This layer, every layer inside a stack, and every look of a state layer. */
    val flattened: List<Layer>
        get() = when (content) {
            is LayerContent.Stack -> listOf(this) + content.children.flatMap { it.flattened }
            is LayerContent.States -> listOf(this) + content.expanded.flatMap { variant -> variant.layers.flatMap { it.flattened } }
            else -> listOf(this)
        }

    /** This layer and the children of stacks: what is drawn at once, for the layer limits. */
    val flattenedStacks: List<Layer>
        get() = if (content is LayerContent.Stack) listOf(this) + content.children.flatMap { it.flattenedStacks } else listOf(this)
}

/** One look of a state layer (ADR-028); no [condition] = the default. */
data class StateVariant(val id: String, val title: LText?, val condition: String?, val layers: List<Layer>, val sample: Map<String, String>?)

data class Stroke(val color: String, val width: Double, val dash: List<Double>?)

data class ListItem(val title: LText, val detail: LText?, val icon: String?, val color: String?)

sealed class LayerContent {
    data class Text(
        val value: LText, val font: FontSpec, val color: String, val align: String?, val maxLines: Int?,
        val tracking: Double?, val liveKind: String?, val liveTarget: String?,
    ) : LayerContent()

    /** `filter` (none, mono, halftone) is applied once when the photo is saved, never in the widget. */
    data class Image(val source: String, val fit: String?, val mask: String?, val cornerRadius: Double?, val filter: String? = null) : LayerContent()

    data class Shape(val kind: String, val fill: String?, val stroke: Stroke?, val cornerRadius: Double?, val glass: Boolean?) : LayerContent()

    data class Icon(val symbol: String, val size: Double, val color: String) : LayerContent()

    data class AnalogClock(
        val style: String?, val faceColor: String?, val tickColor: String?, val hourColor: String?,
        val minuteColor: String?, val accentColor: String?, val timezone: String?,
    ) : LayerContent()

    data class DotGrid(
        val rows: Int, val cols: Int, val dotSize: Double, val gap: Double, val onColor: String,
        val offColor: String, val values: String, val highlightColor: String?,
    ) : LayerContent()

    data class DotBars(
        val bars: Int, val maxDots: Int, val values: String, val color: String, val offColor: String?,
        val labels: LText?, val highlightColor: String?,
    ) : LayerContent()

    data class Ring(val progress: String, val color: String, val trackColor: String?, val lineWidth: Double) : LayerContent()

    data class ForecastRow(val days: Int, val color: String) : LayerContent()

    data class Button(val action: String, val arg: String?) : LayerContent()

    data class CalendarMonth(
        val font: FontSpec, val color: String, val titleFormat: String?, val titleCase: String?, val titleFont: FontSpec?,
        val titleColor: String?, val titleAlign: String?, val weekdays: String?, val weekdayFont: FontSpec?,
        val weekdayColor: String?, val weekStart: String?, val weekendDays: List<String>?, val weekendColor: String?,
        val todayStyle: String?, val todayColor: String?, val todayTextColor: String?, val otherDays: String?,
    ) : LayerContent() {
        val effectiveTitleFont get() = titleFont ?: FontSpec(font.family, font.size * 1.6, "bold")
        val effectiveWeekdayFont get() = weekdayFont ?: FontSpec(font.family, font.size, "semibold")
    }

    data class ListL(
        val items: List<ListItem>, val font: FontSpec, val color: String, val detailColor: String?, val marker: String?,
        val markerColor: String?, val dividerColor: String?,
    ) : LayerContent()

    /** [vertical] fills from the bottom up: a volume or brightness slider (ADR-027). */
    data class ProgressBar(val progress: String, val color: String, val trackColor: String?, val segments: Int?, val cornerRadius: Double?, val vertical: Boolean? = null) :
        LayerContent()

    data class Stack(
        val axis: String, val spacing: Double?, val padding: Double?, val alignItems: String?, val justify: String?,
        val columns: Int?, val children: List<Layer>,
    ) : LayerContent()

    data class Spacer(val minLength: Double?) : LayerContent()

    /**
     * One look per state, chosen by real data (States.swift, ADR-028): [set] is a built-in set of the
     * catalog, [variants] writes them out. The first variant whose `when` holds is drawn.
     */
    data class States(
        val set: String?, val value: String?, val color: String, val accent: String, val dim: String, val box: List<Double>?, val variants: List<StateVariant>?,
    ) : LayerContent() {
        val expanded: List<StateVariant>
            get() = variants ?: set?.let { StateSets.variants(it, value ?: "", color, accent, dim) } ?: emptyList()

        /** The coordinate space of the variants. */
        fun boxSize(frame: Frame): Pair<Double, Double> {
            val own = box ?: set?.let { Capabilities.stateSet(it)?.box }
            return if (own != null && own.size == 2 && own[0] > 0 && own[1] > 0) own[0] to own[1] else maxOf(frame.w, 1.0) to maxOf(frame.h, 1.0)
        }

        /** Names this layer's states in a render's forced states (the editor's preview). */
        val key: String get() = set ?: variants?.firstOrNull()?.id ?: "states"
    }

    data class Unknown(val type: String) : LayerContent()
}

/** Theme color tokens (TEMPLATES.md "Style tokens", ADR-011), same values as SpecTokens.swift. */
object SpecTokens {
    val names = listOf("bg", "fg", "muted", "accent", "outer", "line", "dim", "onAccent")

    fun hex(name: String, theme: Theme): String? {
        val light = theme == Theme.LIGHT
        return when (name) {
            "bg" -> if (light) "#FFFFFF" else "#0E0E0E"
            "fg" -> if (light) "#0E0E0E" else "#FFFFFF"
            "muted" -> if (light) "#8A8A8A" else "#7A7A7A"
            "accent" -> "#E2231A"
            "outer" -> if (light) "#E6E9EC" else "#000000"
            "line" -> if (light) "#0E0E0E1F" else "#FFFFFF26"
            "dim" -> if (light) "#0E0E0E1A" else "#FFFFFF26"
            "onAccent" -> "#FFFFFF"
            else -> null
        }
    }
}
