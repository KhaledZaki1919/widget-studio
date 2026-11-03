package com.khaled.widgetstudio.spec

import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/** Data the bindings read (brief §4.5); every part optional, a missing value renders "--". */
data class DataSnapshot(
    val weather: Weather? = null,
    val stepsToday: Double? = null,
    val stepsStreak: Double? = null,
    val stepsMonth: Double? = null,
    val stepsMonthGrid: List<Double>? = null,
    val sleepLastNight: LText? = null,
    val sleepWeek: List<Double>? = null,
    val counter: Double? = null,
    val dhikr: String? = null,
    val stopwatchStart: Instant? = null,
    val focusToday: LText? = null,
    val focusWeek: List<Double>? = null,
    val prayer: Prayer? = null,
    val qiblaBearing: Double? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val altitude: Double? = null,
    val batteryLevel: Double? = null,
) {
    data class DayForecast(val date: LocalDate, val symbol: String, val high: Double, val low: Double)
    data class Weather(
        val temperature: Double, val high: Double, val low: Double, val condition: LText, val symbol: String,
        val city: LText, val forecast: List<DayForecast>,
    )
    data class Prayer(val times: Map<String, Instant>, val nextName: LText, val nextKey: String, val nextTime: Instant)

    companion object {
        /** The same plausible values as DataSnapshot.sample on iOS (Cairo; weeks start on Saturday, as in Egypt and the iOS snapshots). */
        fun sample(now: Instant, zone: ZoneId, firstDay: DayOfWeek = DayOfWeek.SATURDAY): DataSnapshot {
            val today = now.atZone(zone).toLocalDate()
            val symbols = listOf("sun.max.fill", "cloud.sun.fill", "cloud.fill", "sun.max.fill", "cloud.rain.fill", "sun.max.fill", "cloud.sun.fill")
            val weather = Weather(
                30.0, 33.0, 21.0, LText.Localized("Partly cloudy", "غائم جزئيًا"), "cloud.sun.fill", LText.Localized("Cairo", "القاهرة"),
                (0 until 7).map { DayForecast(today.plusDays(it.toLong()), symbols[it], (33 - it % 3).toDouble(), (21 - it % 2).toDouble()) },
            )
            val day = today.dayOfMonth
            val perDay = (1..31).map { d -> if (d > day) 0.0 else if (d == day) 2.0 else listOf(0.25, 1.0, 0.6, 0.9, 0.4, 1.0, 0.75)[(d * 5) % 7] }
            fun at(hour: Int, minute: Int): Instant = today.atTime(hour, minute).atZone(zone).toInstant()
            val times = linkedMapOf("fajr" to at(4, 32), "dhuhr" to at(11, 42), "asr" to at(14, 58), "maghrib" to at(17, 21), "isha" to at(18, 38))
            val names = listOf(
                "fajr" to LText.Localized("Fajr", "الفجر"), "dhuhr" to LText.Localized("Dhuhr", "الظهر"), "asr" to LText.Localized("Asr", "العصر"),
                "maghrib" to LText.Localized("Maghrib", "المغرب"), "isha" to LText.Localized("Isha", "العشاء"),
            )
            val next = names.firstOrNull { (times[it.first] ?: now) > now } ?: names[0]
            val nextTime = times.getValue(next.first).let { if (it > now) it else it.plus(1, ChronoUnit.DAYS) }
            return DataSnapshot(
                weather = weather, stepsToday = 5543.0, stepsStreak = 3.0, stepsMonth = 128430.0,
                stepsMonthGrid = MonthGrid.levels(perDay, today, firstDay),
                sleepLastNight = LText.Localized("7h 20m", "7س 20د"), sleepWeek = listOf(0.7, 0.85, 0.6, 0.9, 0.75, 0.5, 0.8),
                counter = 33.0, dhikr = "سبحان الله", stopwatchStart = now.minusSeconds(754),
                focusToday = LText.Localized("6h 20m", "6س 20د"), focusWeek = listOf(0.4, 0.8, 0.6, 1.0, 0.3, 0.0, 0.5),
                prayer = Prayer(times, next.second, next.first, nextTime), qiblaBearing = 136.0, latitude = 30.04, longitude = 31.24,
                altitude = 23.0, batteryLevel = 0.87,
            )
        }
    }
}

/** Per-day values laid out as a month for dotGrid (MonthGrid.swift): -1 pads before day 1 and after the last day. */
object MonthGrid {
    const val HIGHLIGHT = 2.0

    fun levels(perDay: List<Double>, date: LocalDate, firstDay: DayOfWeek): List<Double> {
        val first = date.withDayOfMonth(1)
        val leading = (first.dayOfWeek.value - firstDay.value + 7) % 7
        val cells = MutableList(leading) { -1.0 }
        for (i in 0 until date.lengthOfMonth()) cells += if (i < perDay.size) perDay[i].coerceIn(0.0, HIGHLIGHT) else 0.0
        repeat((7 - cells.size % 7) % 7) { cells += -1.0 }
        return cells
    }
}

/** Everything one render needs (RenderContext.swift). */
data class RenderContext(
    val now: Instant,
    val language: String = "ar",
    val zone: ZoneId = ZoneId.systemDefault(),
    val fieldValues: Map<String, LText> = emptyMap(),
    val data: DataSnapshot = DataSnapshot(),
    val userImage: android.graphics.Bitmap? = null,
    /** Live texts (relative, timer) as fixed text measured from [now]: snapshots and previews. */
    val freezesLiveText: Boolean = true,
    /** 24-hour (true) or 12-hour (false); null keeps "HH". */
    val uses24Hour: Boolean? = null,
    val theme: Theme? = null,
    val tokenOverrides: Map<String, String> = emptyMap(),
    /** Tinted/Clear home screens: Android has no accented mode, kept for parity with iOS. */
    val accented: Boolean = false,
) {
    val isArabic get() = language.startsWith("ar")
    /** Words in the render language, digits Latin (ar-EG with Latin numbers). */
    val locale: Locale get() = if (isArabic) Locale.forLanguageTag("ar-EG-u-nu-latn") else Locale.US
    val timePattern get() = if (uses24Hour == false) "h:mm" else "HH:mm"
}

/** `{{name}}` tokens (Bindings.swift). */
object Bindings {
    sealed class Token {
        data class Literal(val text: String) : Token()
        data class Binding(val name: String) : Token()
    }

    fun tokenize(text: String): List<Token> {
        val tokens = mutableListOf<Token>()
        var rest = text
        while (true) {
            val open = rest.indexOf("{{")
            if (open < 0) break
            val close = rest.indexOf("}}", open + 2)
            if (close < 0) break
            if (open > 0) tokens += Token.Literal(rest.substring(0, open))
            tokens += Token.Binding(rest.substring(open + 2, close))
            rest = rest.substring(close + 2)
        }
        if (rest.isNotEmpty()) tokens += Token.Literal(rest)
        return tokens
    }

    fun soleBinding(text: String): String? = tokenize(text.trim()).singleOrNull()?.let { (it as? Token.Binding)?.name }
}

/** A parsed `when` condition: `{{b}}`, `!{{b}}` or `{{b}} == value` (ADR-011). */
data class SpecCondition(val binding: String, val negated: Boolean, val equals: String?) {
    companion object {
        fun parse(text: String): SpecCondition? {
            var rest = text.trim()
            var negated = false
            if (rest.startsWith("!")) {
                negated = true
                rest = rest.drop(1).trim()
            }
            if (!rest.startsWith("{{")) return null
            val close = rest.indexOf("}}").takeIf { it > 0 } ?: return null
            val binding = rest.substring(2, close).trim()
            val tail = rest.substring(close + 2).trim()
            if (binding.isEmpty()) return null
            if (tail.isEmpty()) return SpecCondition(binding, negated, null)
            if (!negated && tail.startsWith("==")) {
                val value = tail.drop(2).trim()
                return if (value.isEmpty()) null else SpecCondition(binding, false, value)
            }
            return null
        }
    }
}

/** Turns bindings into values for one render (BindingResolver.swift). Digits are always Latin. */
class BindingResolver(val spec: WidgetSpec, val context: RenderContext) {
    sealed class Value {
        data class Text(val text: String) : Value()
        data class Number(val value: Double, val display: String) : Value()
        data class Levels(val levels: List<Double>) : Value()
        data class Date(val instant: Instant) : Value()
    }

    private val zoned: ZonedDateTime = context.now.atZone(context.zone)

    fun render(template: String): String = Bindings.tokenize(template).joinToString("") { token ->
        when (token) {
            is Bindings.Token.Literal -> token.text
            is Bindings.Token.Binding -> value(token.name)?.let(::display) ?: MISSING
        }
    }

    fun display(value: Value): String = when (value) {
        is Value.Text -> value.text
        is Value.Number -> value.display
        is Value.Levels -> value.levels.joinToString(",") { "%.2f".format(Locale.US, it) }
        is Value.Date -> DateTimeFormatter.ofPattern(context.timePattern, Locale.US).format(value.instant.atZone(context.zone))
    }

    fun soleValue(text: String): Value? = Bindings.soleBinding(text)?.let(::value)

    fun number(text: String): Double? = text.trim().toDoubleOrNull() ?: (soleValue(text) as? Value.Number)?.value

    fun levels(text: String): List<Double> {
        (soleValue(text) as? Value.Levels)?.let { return it.levels }
        val parts = text.split(",").map { it.trim().toDoubleOrNull() }
        if (parts.isNotEmpty() && parts.size <= 31 && parts.all { it != null && it in 0.0..1.0 }) return parts.filterNotNull()
        val digits = text.filter { it != ' ' }
        if (digits.isNotEmpty() && digits.length <= 600 && digits.all { it == '0' || it == '1' }) return digits.map { if (it == '1') 1.0 else 0.0 }
        return emptyList()
    }

    fun date(text: String): Instant? = (soleValue(text) as? Value.Date)?.instant

    fun fieldValue(key: String): String? = (context.fieldValues[key] ?: spec.field(key)?.default)?.resolved(context.language)

    fun isSatisfied(text: String): Boolean {
        val condition = SpecCondition.parse(text) ?: return true
        val value = value(condition.binding)
        return when {
            condition.equals != null -> value?.let(::display) == condition.equals
            condition.negated -> !isTruthy(value)
            else -> isTruthy(value)
        }
    }

    private fun isTruthy(value: Value?): Boolean = when (value) {
        is Value.Text -> value.text.isNotEmpty() && value.text != "0"
        is Value.Number -> value.value != 0.0
        is Value.Levels -> value.levels.isNotEmpty()
        is Value.Date -> true
        null -> false
    }

    fun value(raw: String): Value? {
        val name = raw.trim()
        when {
            name.startsWith("field.") -> {
                val key = name.removePrefix("field.")
                val field = spec.field(key) ?: return null
                val value = fieldValue(key) ?: return null
                return when (field.type) {
                    "date" -> parseDate(value)?.let { Value.Date(it) }
                    "number" -> value.toDoubleOrNull()?.let { Value.Number(it, value) }
                    else -> Value.Text(value)
                }
            }
            name.startsWith("days.") -> {
                val target = fieldValue(name.removePrefix("days."))?.let(::parseDate) ?: return null
                val days = ChronoUnit.DAYS.between(zoned.toLocalDate(), target.atZone(context.zone).toLocalDate())
                return number(maxOf(days, 0).toDouble(), 0)
            }
            name.startsWith("tz.") && name.endsWith(".time") -> {
                val zone = fieldValue(name.drop(3).dropLast(5))?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: return null
                return Value.Text(DateTimeFormatter.ofPattern(context.timePattern, Locale.US).format(context.now.atZone(zone)))
            }
        }
        return builtin(name)
    }

    fun parseDate(value: String): Instant? {
        runCatching { return Instant.parse(value) }
        runCatching { return ZonedDateTime.parse(value).toInstant() }
        for (pattern in listOf("yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm")) {
            runCatching { return LocalDateTime.parse(value, DateTimeFormatter.ofPattern(pattern)).atZone(context.zone).toInstant() }
        }
        runCatching { return LocalDate.parse(value).atStartOfDay(context.zone).toInstant() }
        return null
    }

    private fun builtin(name: String): Value? {
        val data = context.data
        val language = context.language
        return when (name) {
            "time.h" -> Value.Text(format("h"))
            "time.hh" -> Value.Text(format(if (context.uses24Hour == false) "h" else "HH"))
            "time.mm" -> Value.Text(format("mm"))
            "time.ampm" -> Value.Text(localized("a"))
            "date.d" -> Value.Text(format("d"))
            "date.EEEE" -> Value.Text(localized("EEEE"))
            "date.MMM" -> Value.Text(localized("MMM"))
            "tz.offset" -> Value.Text(offset())
            "weather.temp" -> data.weather?.let { number(it.temperature, 0) }
            "weather.hi" -> data.weather?.let { number(it.high, 0) }
            "weather.lo" -> data.weather?.let { number(it.low, 0) }
            "weather.cond" -> data.weather?.let { Value.Text(it.condition.resolved(language)) }
            "weather.symbol" -> data.weather?.let { Value.Text(it.symbol) }
            "weather.city" -> data.weather?.let { w -> Value.Text(spec.fields.firstOrNull { it.type == "city" }?.let { fieldValue(it.key) } ?: w.city.resolved(language)) }
            "steps.today" -> data.stepsToday?.let { number(it, 0, grouped = true) }
            "steps.streak" -> data.stepsStreak?.let { number(it, 0) }
            "steps.monthGrid" -> data.stepsMonthGrid?.let { Value.Levels(it) }
            "steps.month" -> data.stepsMonth?.let { number(it, 0, grouped = true) }
            "sleep.lastNight" -> data.sleepLastNight?.let { Value.Text(it.resolved(language)) }
            "sleep.week" -> data.sleepWeek?.let { Value.Levels(it) }
            "counter.value" -> data.counter?.let { number(it, 0) }
            "counter.dhikr" -> data.dhikr?.let { Value.Text(it) }
            "counter.progress" -> {
                val count = data.counter ?: return null
                val target = fieldValue("target")?.toDoubleOrNull()?.takeIf { it > 0 } ?: return null
                number(minOf(count / target, 1.0), 2)
            }
            "stopwatch.running" -> Value.Text(if (data.stopwatchStart == null) "0" else "1")
            "stopwatch.start" -> data.stopwatchStart?.let { Value.Date(it) }
            "focus.today" -> data.focusToday?.let { Value.Text(it.resolved(language)) }
            "focus.week" -> data.focusWeek?.let { Value.Levels(it) }
            "prayer.next.name" -> data.prayer?.let { Value.Text(it.nextName.resolved(language)) }
            "prayer.next.time" -> data.prayer?.let { Value.Date(it.nextTime) }
            "prayer.next.key" -> data.prayer?.let { Value.Text(it.nextKey) }
            "qibla.bearing" -> data.qiblaBearing?.let { number(it, 0) }
            "location.lat" -> data.latitude?.let { number(it, 2) }
            "location.lon" -> data.longitude?.let { number(it, 2) }
            "location.alt" -> data.altitude?.let { number(it, 0) }
            "battery.level" -> data.batteryLevel?.let { Value.Number(it, Math.round(it * 100).toString()) }
            else -> if (name.startsWith("prayer.")) data.prayer?.times?.get(name.removePrefix("prayer."))?.let { Value.Date(it) } else null
        }
    }

    private fun number(value: Double, digits: Int, grouped: Boolean = false): Value {
        val symbols = DecimalFormatSymbols(Locale.US)
        val pattern = (if (grouped) "#,##0" else "0") + if (digits > 0) "." + "0".repeat(digits) else ""
        return Value.Number(value, DecimalFormat(pattern, symbols).format(value))
    }

    private fun format(pattern: String): String = DateTimeFormatter.ofPattern(pattern, Locale.US).format(zoned)

    private fun localized(pattern: String): String = DateTimeFormatter.ofPattern(pattern, context.locale).format(zoned)

    private fun offset(): String {
        val seconds = zoned.offset.totalSeconds
        if (seconds == 0) return "GMT"
        val sign = if (seconds > 0) "+" else "-"
        val hours = Math.abs(seconds) / 3600
        val minutes = Math.abs(seconds) % 3600 / 60
        return if (minutes == 0) "GMT$sign$hours" else "GMT$sign$hours:%02d".format(minutes)
    }

    companion object {
        const val MISSING = "--"
    }
}
