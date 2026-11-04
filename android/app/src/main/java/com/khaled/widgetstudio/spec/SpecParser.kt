package com.khaled.widgetstudio.spec

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Reads spec JSON into [WidgetSpec], with the same defaults as the Swift decoder. */
object SpecParser {
    private val json = Json { ignoreUnknownKeys = true }

    class SpecException(message: String) : Exception(message)

    fun parse(text: String): WidgetSpec = spec(json.parseToJsonElement(text).jsonObject)

    fun spec(o: JsonObject): WidgetSpec = WidgetSpec(
        schemaVersion = o.int("schemaVersion") ?: throw SpecException("missing schemaVersion"),
        id = o.str("id") ?: throw SpecException("missing id"),
        name = o.ltext("name") ?: throw SpecException("missing name"),
        family = Family.of(o.str("family") ?: "small"),
        theme = if (o.str("theme") == "light") Theme.LIGHT else Theme.DARK,
        refresh = o.str("refresh") ?: "none",
        background = background(o.obj("background") ?: throw SpecException("missing background")),
        fields = o.arr("fields")?.map { field(it.jsonObject) } ?: emptyList(),
        layers = o.arr("layers")?.map { layer(it.jsonObject, child = false) } ?: throw SpecException("missing layers"),
        category = o.str("category"),
        decorative = o.arr("decorative")?.mapNotNull { item ->
            val note = item as? JsonObject ?: return@mapNotNull null
            DecorativeNote(note.str("element") ?: return@mapNotNull null, note.str("reason") ?: "")
        } ?: emptyList(),
    )

    private fun background(o: JsonObject) = Background(
        type = o.str("type") ?: "solid",
        color = o.str("color"),
        colors = o.arr("colors")?.map { it.jsonPrimitive.content },
        angle = o.num("angle"),
        outerColor = o.str("outerColor"),
        cardShape = o.str("cardShape"),
    )

    private fun field(o: JsonObject) = FieldSpec(
        key = o.str("key") ?: "",
        type = o.str("type") ?: "text",
        label = o.ltext("label") ?: LText.Plain(""),
        default = o.ltext("default"),
    )

    private fun font(o: JsonObject?): FontSpec? = o?.let { FontSpec(it.str("family") ?: "system", it.num("size") ?: 14.0, it.str("weight")) }

    fun layer(o: JsonObject, child: Boolean): Layer {
        // Children of a stack give only width/height (0 or absent = natural size, M6.1).
        val frame = o.obj("frame")?.let { Frame(it.num("x") ?: 0.0, it.num("y") ?: 0.0, it.num("w") ?: 0.0, it.num("h") ?: 0.0) }
            ?: Frame(0.0, 0.0, o.num("width") ?: 0.0, o.num("height") ?: 0.0)
        val rotation = o["rotation"]?.let { (it as? JsonPrimitive)?.let { p -> p.doubleOrNull?.let(::formatNumber) ?: p.content } }
        return Layer(frame, o.num("opacity"), o.bool("mirror"), o.str("when"), rotation, content(o))
    }

    private fun formatNumber(value: Double): String = if (value == Math.rint(value)) value.toLong().toString() else value.toString()

    private fun content(o: JsonObject): LayerContent = when (val type = o.str("type")) {
        "text" -> {
            val live = o.obj("live")
            LayerContent.Text(
                o.ltext("value") ?: LText.Plain(""), font(o.obj("font")) ?: FontSpec("system", 14.0, null), o.str("color") ?: "#FFFFFF",
                o.str("align"), o.int("maxLines"), o.num("tracking"), live?.str("kind"), live?.str("target"),
            )
        }
        "image" -> LayerContent.Image(o.str("source") ?: "user_image", o.str("fit"), o.str("mask"), o.num("cornerRadius"), o.str("filter"))
        "shape" -> LayerContent.Shape(
            o.str("kind") ?: "rect", o.str("fill"),
            o.obj("stroke")?.let { Stroke(it.str("color") ?: "#FFFFFF", it.num("width") ?: 1.0, it.arr("dash")?.mapNotNull { d -> d.jsonPrimitive.doubleOrNull }) },
            o.num("cornerRadius"), o.bool("glass"),
        )
        "icon" -> LayerContent.Icon(o.str("symbol") ?: "questionmark", o.num("size") ?: 20.0, o.str("color") ?: "#FFFFFF")
        "analogClock" -> LayerContent.AnalogClock(
            o.str("style"), o.str("faceColor"), o.str("tickColor"), o.str("hourColor"), o.str("minuteColor"), o.str("accentColor"), o.str("timezone"),
        )
        "dotGrid" -> LayerContent.DotGrid(
            o.int("rows") ?: 1, o.int("cols") ?: 1, o.num("dotSize") ?: 4.0, o.num("gap") ?: 2.0, o.str("onColor") ?: "#FFFFFF",
            o.str("offColor") ?: "#FFFFFF26", o.str("values") ?: "", o.str("highlightColor"),
        )
        "dotBars" -> LayerContent.DotBars(
            o.int("bars") ?: 7, o.int("maxDots") ?: 8, o.str("values") ?: "", o.str("color") ?: "#FFFFFF", o.str("offColor"),
            o.ltext("labels"), o.str("highlightColor"),
        )
        "ring" -> LayerContent.Ring(o.str("progress") ?: "0", o.str("color") ?: "#FFFFFF", o.str("trackColor"), o.num("lineWidth") ?: 6.0)
        "forecastRow" -> LayerContent.ForecastRow(o.int("days") ?: 5, o.str("color") ?: "#FFFFFF")
        "button" -> LayerContent.Button(o.str("action") ?: "open.app", o.str("arg"))
        "calendarMonth" -> LayerContent.CalendarMonth(
            font(o.obj("font")) ?: FontSpec("system", 11.0, null), o.str("color") ?: "#FFFFFF", o.str("titleFormat"), o.str("titleCase"),
            font(o.obj("titleFont")), o.str("titleColor"), o.str("titleAlign"), o.str("weekdays"), font(o.obj("weekdayFont")),
            o.str("weekdayColor"), o.str("weekStart"), o.arr("weekendDays")?.map { it.jsonPrimitive.content }, o.str("weekendColor"),
            o.str("todayStyle"), o.str("todayColor"), o.str("todayTextColor"), o.str("otherDays"),
        )
        "list" -> LayerContent.ListL(
            o.arr("items")?.map { item ->
                val i = item.jsonObject
                ListItem(i.ltext("title") ?: LText.Plain(""), i.ltext("detail"), i.str("icon"), i.str("color"))
            } ?: emptyList(),
            font(o.obj("font")) ?: FontSpec("system", 13.0, null), o.str("color") ?: "#FFFFFF", o.str("detailColor"), o.str("marker"),
            o.str("markerColor"), o.str("dividerColor"),
        )
        "progressBar" -> LayerContent.ProgressBar(o.str("progress") ?: "0", o.str("color") ?: "#FFFFFF", o.str("trackColor"), o.int("segments"), o.num("cornerRadius"), o.bool("vertical"))
        "stack" -> LayerContent.Stack(
            o.str("axis") ?: "vertical", o.num("spacing"), o.num("padding"), o.str("alignItems"), o.str("justify"), o.int("columns"),
            o.arr("children")?.map { layer(it.jsonObject, child = true) } ?: emptyList(),
        )
        "spacer" -> LayerContent.Spacer(o.num("minLength"))
        else -> LayerContent.Unknown(type ?: "")
    }

    // MARK: JSON helpers (null values count as absent, like the Swift decoder after removingNulls)

    private fun JsonObject.prim(key: String): JsonPrimitive? = (this[key] as? JsonPrimitive)?.takeIf { it.toString() != "null" }
    private fun JsonObject.str(key: String): String? = prim(key)?.takeIf { it.isString }?.content
    private fun JsonObject.num(key: String): Double? = prim(key)?.doubleOrNull
    private fun JsonObject.int(key: String): Int? = prim(key)?.intOrNull ?: prim(key)?.doubleOrNull?.toInt()
    private fun JsonObject.bool(key: String): Boolean? = prim(key)?.booleanOrNull
    private fun JsonObject.obj(key: String): JsonObject? = this[key] as? JsonObject
    private fun JsonObject.arr(key: String): JsonArray? = this[key] as? JsonArray

    private fun JsonObject.ltext(key: String): LText? = when (val value: JsonElement? = this[key]) {
        is JsonPrimitive -> if (value.isString) LText.Plain(value.content) else null
        is JsonObject -> {
            val en = value.str("en")
            val ar = value.str("ar")
            if (en != null && ar != null) LText.Localized(en, ar) else null
        }
        else -> null
    }
}
