package com.khaled.widgetstudio.render

import android.content.res.AssetManager
import android.graphics.Typeface
import android.os.Build
import com.khaled.widgetstudio.spec.FontSpec
import org.json.JSONObject

/**
 * Spec font families (FontRegistry.swift): `dot` (Doto), `arabic` (IBM Plex Sans Arabic), `hand`,
 * `serif-display`, `condensed`, and the system faces. Arabic text switches to an Arabic face.
 * The font files are the shared ones in ios/Fonts, copied into assets/fonts at build time.
 */
class Fonts(private val assets: AssetManager) {
    private val cache = mutableMapOf<String, Typeface>()

    fun typeface(spec: FontSpec, text: String): Typeface {
        val weight = spec.weight ?: "regular"
        return when (effectiveFamily(spec, text)) {
            "dot" -> file(dotFile(weight))
            "arabic" -> file(arabicFile(weight, spec.family))
            "hand" -> file("PatrickHand-Regular")
            "serif-display" -> file("DMSerifDisplay-Regular")
            "condensed" -> file("BebasNeue-Regular")
            "system-serif" -> system(Typeface.SERIF, weight)
            "system-mono" -> system(Typeface.MONOSPACE, weight)
            else -> system(Typeface.DEFAULT, weight)   // system and system-rounded (Android has no rounded system face)
        }
    }

    /** The system face used for "°" in dot text (Doto's degree sign looks wrong). */
    fun system(weight: String): Typeface = system(Typeface.DEFAULT, weight)

    /** Material Symbols Rounded, filled (Android-only, Apache 2.0) for icon layers. */
    val symbols: Typeface by lazy { Typeface.createFromAsset(assets, "fonts/MaterialSymbolsRounded-Filled.ttf") }

    private fun file(name: String): Typeface = cache.getOrPut(name) {
        runCatching { Typeface.createFromAsset(assets, "fonts/$name.ttf") }.getOrDefault(Typeface.DEFAULT)
    }

    private fun system(base: Typeface, weight: String): Typeface {
        val value = weightValue(weight)
        return if (Build.VERSION.SDK_INT >= 28) Typeface.create(base, value, false)
        else Typeface.create(base, if (value >= 600) Typeface.BOLD else Typeface.NORMAL)
    }

    companion object {
        fun effectiveFamily(spec: FontSpec, text: String) = if (containsArabic(text)) "arabic" else spec.family

        fun containsArabic(text: String) = text.any {
            val c = it.code
            c in 0x0600..0x06FF || c in 0x0750..0x077F || c in 0x08A0..0x08FF || c in 0xFB50..0xFDFF || c in 0xFE70..0xFEFF
        }

        fun weightValue(weight: String) = when (weight) {
            "ultraLight" -> 100
            "thin" -> 200
            "light" -> 300
            "medium" -> 500
            "semibold" -> 600
            "bold" -> 700
            "heavy" -> 800
            "black" -> 900
            else -> 400
        }

        fun dotFile(weight: String) = when (weight) {
            "semibold", "bold" -> "Doto-Bold"
            "heavy", "black" -> "Doto-Black"
            else -> "Doto-Regular"
        }

        fun arabicFile(weight: String, family: String): String {
            val bold = weight in listOf("semibold", "bold", "heavy", "black")
            return when (family) {
                "hand" -> if (bold) "ArefRuqaa-Bold" else "ArefRuqaa-Regular"
                "serif-display" -> if (bold) "Amiri-Bold" else "Amiri-Regular"
                "condensed" -> "Lalezar-Regular"
                else -> when (weight) {
                    "medium" -> "IBMPlexSansArabic-Medium"
                    "semibold" -> "IBMPlexSansArabic-SemiBold"
                    "bold", "heavy", "black" -> "IBMPlexSansArabic-Bold"
                    else -> "IBMPlexSansArabic-Regular"
                }
            }
        }
    }
}

/** SF Symbol → Material Symbols name, from Icons.swift (assets/spec/icons.json, written at build time). */
class Icons(assets: AssetManager) {
    private val map: Map<String, String> = runCatching {
        val json = JSONObject(assets.open("spec/icons.json").bufferedReader().readText())
        json.keys().asSequence().associateWith { json.getString(it) }
    }.getOrDefault(emptyMap())

    fun isAllowed(symbol: String) = map.containsKey(symbol)
    fun material(symbol: String): String = map[symbol] ?: "help"
}

/**
 * Keeps numbers and Latin words intact inside Arabic text (BidiText.swift): each Latin run is
 * wrapped in a left-to-right isolate, so "33° / 21°" keeps its order in an Arabic paragraph.
 */
object BidiText {
    private const val LRI = '⁦'
    private const val PDI = '⁩'
    private val numberMarks = setOf('°', '%', ':', '.', ',')

    private fun isLatin(c: Char) = c.code < 128 && c.isLetterOrDigit()
    private fun isLetter(c: Char) = c.code < 128 && c.isLetter()

    fun isolatingNumbers(text: String): String {
        if (!Fonts.containsArabic(text)) return text
        val result = StringBuilder()
        val run = StringBuilder()
        fun flush() {
            if (run.isEmpty()) return
            val trailing = StringBuilder()
            while (run.isNotEmpty() && run.last() in numberMarks && run.last() != '°' && run.last() != '%') {
                trailing.insert(0, run.last())
                run.setLength(run.length - 1)
            }
            result.append(LRI).append(run).append(PDI).append(trailing)
            run.setLength(0)
        }
        for ((index, c) in text.withIndex()) {
            when {
                isLatin(c) -> run.append(c)
                run.isNotEmpty() && c in numberMarks -> run.append(c)
                run.isNotEmpty() && c == ' ' && index + 1 < text.length && isLatin(text[index + 1]) &&
                    (run.any(::isLetter) || isLetter(text[index + 1])) -> run.append(c)
                else -> {
                    flush()
                    result.append(c)
                }
            }
        }
        flush()
        return result.toString()
    }
}
