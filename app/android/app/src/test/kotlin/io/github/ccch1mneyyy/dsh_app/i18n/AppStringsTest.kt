package io.github.ccch1mneyyy.dsh_app.i18n

import org.junit.Assert.assertEquals
import org.junit.Test

/** The shared rule behind native text and Dart's `AppLocale.resolve`. */
class AppStringsTest {
    @Test
    fun explicitChoiceWinsOverSystemLanguages() {
        assertEquals("en", AppStrings.resolveLanguage("en", listOf("zh-Hans", "en-US")))
        assertEquals("zh", AppStrings.resolveLanguage("zh", listOf("en-US", "zh-Hans")))
    }

    @Test
    fun systemChoiceUsesFirstChineseOrEnglishLanguage() {
        assertEquals("zh", AppStrings.resolveLanguage(null, listOf("zh-Hans", "en-US")))
        assertEquals("en", AppStrings.resolveLanguage(null, listOf("en-US", "zh-Hans")))
        assertEquals("zh", AppStrings.resolveLanguage(null, listOf("ja-JP", "zh-Hant-TW")))
        assertEquals("en", AppStrings.resolveLanguage(null, listOf("ja-JP", "en-GB")))
    }

    @Test
    fun unsupportedOrEmptySystemLanguagesFallBackToEnglish() {
        assertEquals("en", AppStrings.resolveLanguage(null, emptyList()))
        assertEquals("en", AppStrings.resolveLanguage(null, listOf("ja-JP", "fr-FR")))
        assertEquals("zh", AppStrings.resolveLanguage("system", listOf("zh-Hans")))
    }

    @Test
    fun tagsAreMatchedByLanguageSubtag() {
        assertEquals("zh", AppStrings.resolveLanguage(null, listOf("zh_CN")))
        assertEquals("zh", AppStrings.resolveLanguage(null, listOf("ZH-hant")))
        assertEquals("en", AppStrings.resolveLanguage(null, listOf("EN_us")))
        assertEquals("en", AppStrings.resolveLanguage(null, listOf("en")))
    }
}
