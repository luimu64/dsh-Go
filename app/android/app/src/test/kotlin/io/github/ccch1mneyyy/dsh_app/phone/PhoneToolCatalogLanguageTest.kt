package io.github.ccch1mneyyy.dsh_app.phone

import io.github.ccch1mneyyy.dsh_app.i18n.AppStrings
import org.junit.Assert.*
import org.junit.Test

/**
 * The model-facing catalog follows the app language: every tool and parameter description has an
 * English variant, and both languages serve the same tool ids, enums and schema shape.
 */
class PhoneToolCatalogLanguageTest {
    private val chinese = PhoneToolCatalog.listJson(PhoneToolCatalog.LANGUAGE_ZH)
    private val english = PhoneToolCatalog.listJson(PhoneToolCatalog.LANGUAGE_EN)

    /** Han characters plus CJK punctuation and fullwidth forms: none may reach the English text. */
    private val cjk = Regex("[\\u3000-\\u303F\\u3400-\\u4DBF\\u4E00-\\u9FFF\\uF900-\\uFAFF\\uFF00-\\uFFEF]")

    /** Every `description` value in the catalog, keyed by its path, including nested arrays. */
    private fun descriptions(json: List<Map<String, Any?>>): Map<String, String> {
        val out = linkedMapOf<String, String>()
        fun walk(value: Any?, path: String) {
            when (value) {
                is Map<*, *> -> for ((key, child) in value) {
                    if (key == "description" && child is String) out[path] = child
                    walk(child, "$path/$key")
                }
                is List<*> -> for (i in value.indices) walk(value[i], "$path[$i]")
            }
        }
        walk(json, "")
        return out
    }

    /** What the schema must keep across languages: ids, required lists, property order and types. */
    private fun shape(json: List<Map<String, Any?>>): List<Pair<Any?, Any?>> = json.map { tool ->
        val schema = tool["inputSchema"] as Map<*, *>
        @Suppress("UNCHECKED_CAST")
        val properties = schema["properties"] as Map<String, Map<String, Any?>>
        tool["name"] to listOf(
            tool["required"],
            properties.keys.toList(),
            properties.map { (name, spec) -> name to spec.filterKeys { it != "description" } },
            schema["additionalProperties"],
        )
    }

    @Test
    fun englishKeepsEveryToolIdEnumAndSchemaShape() {
        assertEquals(chinese.map { it["name"] }, english.map { it["name"] })
        assertEquals(PhoneToolCatalog.names, english.map { it["name"] })
        assertEquals(shape(chinese), shape(english))
        assertEquals(descriptions(chinese).keys, descriptions(english).keys)
    }

    @Test
    fun englishDescriptionsAreFullyTranslatedWithoutChinese() {
        val zh = descriptions(chinese)
        val en = descriptions(english)
        for ((path, text) in en) {
            assertFalse("Chinese text left in English description $path: $text", cjk.containsMatchIn(text))
            assertTrue("English description $path is empty", text.isNotBlank())
            assertNotEquals("English description $path still carries the Chinese text", zh.getValue(path), text)
        }
        // Spot-check that the translated text keeps the protocol facts the Chinese text carries.
        val intent = english.single { it["name"] == PhoneToolCatalog.INTENT }
        val fields = (intent["inputSchema"] as Map<*, *>)["properties"] as Map<*, *>
        val days = fields["days"] as Map<*, *>
        assertTrue((days["description"] as String).contains("1=Monday … 7=Sunday"))
        val tapXY = (english.single { it["name"] == PhoneToolCatalog.TAP_XY }["inputSchema"] as Map<*, *>)["properties"] as Map<*, *>
        assertTrue(((tapXY["duration_ms"] as Map<*, *>)["description"] as String).contains("100–2000"))
        assertTrue(((tapXY["duration_ms"] as Map<*, *>)["description"] as String).contains("400"))
        val screen = (english.single { it["name"] == PhoneToolCatalog.SCREEN }["inputSchema"] as Map<*, *>)["properties"] as Map<*, *>
        assertTrue(((screen["background"] as Map<*, *>)["description"] as String).contains("background"))
    }

    @Test
    fun chineseStaysTheSourceTextAndTheDefault() {
        assertEquals(chinese, PhoneToolCatalog.tools.map { it.toJson() })
        assertEquals(chinese, PhoneToolCatalog.listJson())
        assertEquals(chinese, PhoneToolCatalog.listJson("system"))
        assertTrue(PhoneToolCatalog.catalog(PhoneToolCatalog.LANGUAGE_ZH) === PhoneToolCatalog.tools)
        assertEquals(15, chinese.size)
        for (tool in PhoneToolCatalog.catalog(PhoneToolCatalog.LANGUAGE_ZH)) {
            assertTrue("Chinese tool ${tool.name} lost its Chinese description", cjk.containsMatchIn(tool.description))
        }
    }

    @Test
    fun appLanguageChoiceSelectsTheServedCatalog() {
        val englishChoice = AppStrings.resolveLanguage("en", listOf("zh-Hans"))
        val chineseChoice = AppStrings.resolveLanguage("zh", listOf("en-US"))
        assertFalse(descriptions(PhoneToolCatalog.listJson(englishChoice)).values.any { cjk.containsMatchIn(it) })
        assertTrue(descriptions(PhoneToolCatalog.listJson(chineseChoice)).values.any { cjk.containsMatchIn(it) })
        // A system without Chinese or English falls back to English, like the Dart AppLocale.
        assertFalse(descriptions(PhoneToolCatalog.listJson(AppStrings.resolveLanguage(null, emptyList())))
            .values.any { cjk.containsMatchIn(it) })
    }

    @Test
    fun mcpToolsListServesTheSelectedLanguage() {
        for (language in listOf(PhoneToolCatalog.LANGUAGE_ZH, PhoneToolCatalog.LANGUAGE_EN)) {
            val server = McpServer(PhoneToolCatalog.listJson(language), { _, _, _ -> error("tools/list must not dispatch a tool") })
            val response = checkNotNull(server.handle(Json.write(mapOf("jsonrpc" to "2.0", "id" to 1, "method" to "tools/list"))))
            val listed = ((Json.parse(response) as Map<*, *>)["result"] as Map<*, *>)["tools"] as List<*>
            assertEquals(PhoneToolCatalog.listJson(language), listed)
            val hasChinese = listed.any { cjk.containsMatchIn(((it as Map<*, *>)["description"] as String)) }
            assertEquals(language == PhoneToolCatalog.LANGUAGE_ZH, hasChinese)
        }
    }
}
