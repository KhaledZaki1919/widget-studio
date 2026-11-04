package com.khaled.widgetstudio.spec

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Writes a [WidgetSpec] as spec JSON (the inverse of [SpecParser]); absent values are left out. */
object SpecWriter {
    fun write(spec: WidgetSpec): JsonObject = buildJsonObject {
        put("schemaVersion", spec.schemaVersion)
        put("id", spec.id)
        spec.category?.let { put("category", it) }
        put("name", ltext(spec.name))
        put("family", spec.family.name.lowercase())
        put("theme", spec.theme.name.lowercase())
        put("refresh", spec.refresh)
        put("background", background(spec.background))
        if (spec.fields.isNotEmpty()) put("fields", JsonArray(spec.fields.map(::field)))
        put("layers", JsonArray(spec.layers.map { layer(it, child = false) }))
    }

    fun ltext(text: LText): JsonElement = when (text) {
        is LText.Plain -> JsonPrimitive(text.text)
        is LText.Localized -> buildJsonObject {
            put("en", text.en)
            put("ar", text.ar)
        }
    }

    private fun background(b: Background) = buildJsonObject {
        put("type", b.type)
        b.color?.let { put("color", it) }
        b.colors?.let { put("colors", JsonArray(it.map(::JsonPrimitive))) }
        b.angle?.let { put("angle", it) }
        b.outerColor?.let { put("outerColor", it) }
        b.cardShape?.let { put("cardShape", it) }
    }

    private fun field(f: FieldSpec) = buildJsonObject {
        put("key", f.key)
        put("type", f.type)
        put("label", ltext(f.label))
        f.default?.let { put("default", ltext(it)) }
    }

    private fun font(f: FontSpec) = buildJsonObject {
        put("family", f.family)
        put("size", f.size)
        f.weight?.let { put("weight", it) }
    }

    fun layer(layer: Layer, child: Boolean): JsonObject {
        val fields = linkedMapOf<String, JsonElement>()
        fun set(key: String, value: Any?) {
            when (value) {
                null -> Unit
                is JsonElement -> fields[key] = value
                is String -> fields[key] = JsonPrimitive(value)
                is Number -> fields[key] = JsonPrimitive(value)
                is Boolean -> fields[key] = JsonPrimitive(value)
            }
        }
        set("type", typeName(layer.content))
        if (child) {
            if (layer.frame.w > 0) set("width", layer.frame.w)
            if (layer.frame.h > 0) set("height", layer.frame.h)
        } else {
            set("frame", buildJsonObject {
                put("x", layer.frame.x)
                put("y", layer.frame.y)
                put("w", layer.frame.w)
                put("h", layer.frame.h)
            })
        }
        set("opacity", layer.opacity)
        set("mirror", layer.mirror)
        set("when", layer.condition)
        set("rotation", layer.rotation)
        when (val c = layer.content) {
            is LayerContent.Text -> {
                set("value", ltext(c.value)); set("font", font(c.font)); set("color", c.color); set("align", c.align)
                set("maxLines", c.maxLines); set("tracking", c.tracking)
                if (c.liveKind != null) set("live", buildJsonObject { put("kind", c.liveKind); c.liveTarget?.let { put("target", it) } })
            }
            is LayerContent.Image -> { set("source", c.source); set("fit", c.fit); set("mask", c.mask); set("cornerRadius", c.cornerRadius); set("filter", c.filter) }
            is LayerContent.Shape -> {
                set("kind", c.kind); set("fill", c.fill); set("cornerRadius", c.cornerRadius); set("glass", c.glass)
                c.stroke?.let { s -> set("stroke", buildJsonObject { put("color", s.color); put("width", s.width); s.dash?.let { put("dash", JsonArray(it.map(::JsonPrimitive))) } }) }
            }
            is LayerContent.Icon -> { set("symbol", c.symbol); set("size", c.size); set("color", c.color) }
            is LayerContent.AnalogClock -> {
                set("style", c.style); set("faceColor", c.faceColor); set("tickColor", c.tickColor); set("hourColor", c.hourColor)
                set("minuteColor", c.minuteColor); set("accentColor", c.accentColor); set("timezone", c.timezone)
            }
            is LayerContent.DotGrid -> {
                set("rows", c.rows); set("cols", c.cols); set("dotSize", c.dotSize); set("gap", c.gap); set("onColor", c.onColor)
                set("offColor", c.offColor); set("values", c.values); set("highlightColor", c.highlightColor)
            }
            is LayerContent.DotBars -> {
                set("bars", c.bars); set("maxDots", c.maxDots); set("values", c.values); set("color", c.color); set("offColor", c.offColor)
                c.labels?.let { set("labels", ltext(it)) }; set("highlightColor", c.highlightColor)
            }
            is LayerContent.Ring -> { set("progress", c.progress); set("color", c.color); set("trackColor", c.trackColor); set("lineWidth", c.lineWidth) }
            is LayerContent.ForecastRow -> { set("days", c.days); set("color", c.color) }
            is LayerContent.Button -> { set("action", c.action); set("arg", c.arg) }
            is LayerContent.CalendarMonth -> {
                set("font", font(c.font)); set("color", c.color); set("titleFormat", c.titleFormat); set("titleCase", c.titleCase)
                c.titleFont?.let { set("titleFont", font(it)) }; set("titleColor", c.titleColor); set("titleAlign", c.titleAlign)
                set("weekdays", c.weekdays); c.weekdayFont?.let { set("weekdayFont", font(it)) }; set("weekdayColor", c.weekdayColor)
                set("weekStart", c.weekStart); c.weekendDays?.let { set("weekendDays", JsonArray(it.map(::JsonPrimitive))) }
                set("weekendColor", c.weekendColor); set("todayStyle", c.todayStyle); set("todayColor", c.todayColor)
                set("todayTextColor", c.todayTextColor); set("otherDays", c.otherDays)
            }
            is LayerContent.ListL -> {
                set("items", JsonArray(c.items.map { item ->
                    buildJsonObject {
                        put("title", ltext(item.title)); item.detail?.let { put("detail", ltext(it)) }
                        item.icon?.let { put("icon", it) }; item.color?.let { put("color", it) }
                    }
                }))
                set("font", font(c.font)); set("color", c.color); set("detailColor", c.detailColor); set("marker", c.marker)
                set("markerColor", c.markerColor); set("dividerColor", c.dividerColor)
            }
            is LayerContent.ProgressBar -> { set("progress", c.progress); set("color", c.color); set("trackColor", c.trackColor); set("segments", c.segments); set("cornerRadius", c.cornerRadius); set("vertical", c.vertical) }
            is LayerContent.Stack -> {
                set("axis", c.axis); set("spacing", c.spacing); set("padding", c.padding); set("alignItems", c.alignItems)
                set("justify", c.justify); set("columns", c.columns); set("children", JsonArray(c.children.map { layer(it, child = true) }))
            }
            is LayerContent.Spacer -> set("minLength", c.minLength)
            is LayerContent.Unknown -> Unit
        }
        return JsonObject(fields)
    }

    fun typeName(content: LayerContent) = when (content) {
        is LayerContent.Text -> "text"
        is LayerContent.Image -> "image"
        is LayerContent.Shape -> "shape"
        is LayerContent.Icon -> "icon"
        is LayerContent.AnalogClock -> "analogClock"
        is LayerContent.DotGrid -> "dotGrid"
        is LayerContent.DotBars -> "dotBars"
        is LayerContent.Ring -> "ring"
        is LayerContent.ForecastRow -> "forecastRow"
        is LayerContent.Button -> "button"
        is LayerContent.CalendarMonth -> "calendarMonth"
        is LayerContent.ListL -> "list"
        is LayerContent.ProgressBar -> "progressBar"
        is LayerContent.Stack -> "stack"
        is LayerContent.Spacer -> "spacer"
        is LayerContent.Unknown -> content.type
    }
}
