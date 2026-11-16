package io.github.ccch1mneyyy.dsh_app.phone

import io.github.ccch1mneyyy.dsh_app.phone.a11y.Box
import io.github.ccch1mneyyy.dsh_app.phone.a11y.FormattedScreen
import io.github.ccch1mneyyy.dsh_app.phone.a11y.ScreenDigest
import io.github.ccch1mneyyy.dsh_app.phone.a11y.ScreenFormat
import io.github.ccch1mneyyy.dsh_app.phone.a11y.ScreenInput
import io.github.ccch1mneyyy.dsh_app.phone.a11y.ScreenVerdict
import io.github.ccch1mneyyy.dsh_app.phone.a11y.UiNode
import io.github.ccch1mneyyy.dsh_app.phone.a11y.UiWindow
import io.github.ccch1mneyyy.dsh_app.phone.a11y.WindowKind
import io.github.ccch1mneyyy.dsh_app.phone.background.Reasons
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import java.util.Locale
import javax.xml.parsers.DocumentBuilderFactory

/**
 * The last model-facing phone text an action or a screen hands back is presented through
 * [PhoneUiText] exactly like the rest of the phone code: the English wording comes from the real
 * `res/values/i18n_strings.xml`, and the Chinese literal in the code stays the fallback for a
 * miss.
 */
class PhoneModelTextLanguageTest {
    private val main = File("src/main")
    private val res = File(main, "res")

    private fun strings(directory: String): Map<String, String> {
        val dir = File(res, directory)
        val factory = DocumentBuilderFactory.newInstance()
        val out = linkedMapOf<String, String>()
        for (file in dir.listFiles().orEmpty().filter { it.isFile && it.extension == "xml" }.sortedBy { it.name }) {
            val root = factory.newDocumentBuilder().parse(file).documentElement
            val nodes = root.getElementsByTagName("string")
            for (index in 0 until nodes.length) {
                val element = nodes.item(index) as Element
                out[element.getAttribute("name")] = element.textContent
            }
            val plurals = root.getElementsByTagName("plurals")
            for (index in 0 until plurals.length) {
                val plural = plurals.item(index) as Element
                val items = plural.getElementsByTagName("item")
                if (items.length > 0) out[plural.getAttribute("name")] = (items.item(0) as Element).textContent
            }
        }
        return out
    }

    /** The same resolution the app does at the render boundary: a resource string, in the app language. */
    private fun ui(language: String): PhoneUiText {
        val catalog = strings(if (language == "zh") "values-zh" else "values")
        return PhoneUiText { key, args ->
            catalog[key]?.let { if (args.isEmpty()) it else String.format(Locale.ROOT, it, *args.toTypedArray()) }
        }
    }

    // ---- a real interruption receipt ----

    private fun refusedJournal(ui: PhoneUiText): PhoneTaskJournal {
        var stored: String? = null
        val first = PhoneTaskJournal({ stored }, { next -> stored = next; true }, PROCESS_A) { 1L }
        assertTrue(first.mark(first.record((PhoneTasks().begin() as PhoneTasks.Begin.Go).owner)))
        return PhoneTaskJournal({ stored }, { next -> stored = next; true }, PROCESS_B, ui) { 1L }
    }

    @Test fun theTaskJournalRefusesInTheAppLanguage() {
        assertEquals(strings("values")["phone_journal_interrupted"], refusedJournal(ui("en")).refusal())
        assertEquals(PhoneTaskJournal.INTERRUPTION_MESSAGE, refusedJournal(PhoneUiText.DEFAULT).refusal())
    }

    // ---- screen verdicts ----

    @Test fun theScreenVerdictSpeaksInTheAppLanguage() {
        val english = ui("en")
        assertEquals("The screen didn’t visibly change.", ScreenVerdict.note(true, false, null, false, english))
        assertEquals("Nothing changed, so this may already be the end of the list.",
            ScreenVerdict.note(true, false, null, true, english))
        assertEquals("The keyboard is hidden.",
            ScreenVerdict.note(true, false, ScreenVerdict.KEYBOARD_HIDDEN, false, english))
        assertEquals("The keyboard is showing.",
            ScreenVerdict.note(true, false, ScreenVerdict.KEYBOARD_SHOWN, false, english))
        val unverifiable = ScreenVerdict.note(false, false, null, true, english)
        assertTrue(unverifiable, unverifiable.startsWith("(The action was submitted but the result can’t be verified"))
        // The keyboard sentence produced by the observation code is translated where it is shown.
        val both = ScreenVerdict.note(false, false, ScreenVerdict.KEYBOARD_HIDDEN, false, english)
        assertTrue(both, both.startsWith("The keyboard is hidden."))
        assertFalse(both, both.contains("键盘"))

        assertEquals(ScreenVerdict.UNCHANGED, ScreenVerdict.note(true, false, null, false))
        assertEquals(ScreenVerdict.SCROLL_END, ScreenVerdict.note(true, false, null, true))
        assertEquals(ScreenVerdict.KEYBOARD_HIDDEN, ScreenVerdict.note(true, false, ScreenVerdict.KEYBOARD_HIDDEN, false))
        assertEquals(ScreenVerdict.UNVERIFIABLE, ScreenVerdict.note(false, false, null, false))
    }

    // ---- screen digest ----

    private fun screen(vararg labels: String, id: String, ui: PhoneUiText = PhoneUiText.DEFAULT): FormattedScreen {
        val frame = Box(0, 0, 400, 800)
        val nodes = labels.mapIndexed { index, text ->
            UiNode(className = "android.widget.Button", text = text,
                bounds = Box(0, 100 + index * 60, 400, 150 + index * 60), clickable = true)
        }
        val window = UiWindow(1, WindowKind.APP, "example.app", "示例", frame,
            UiNode(bounds = frame, children = nodes))
        return ScreenFormat.format(ScreenInput(id, "示例", "example.app", 400, 800, false, listOf(window)), ui)
    }

    @Test fun theScreenDigestSpeaksInTheAppLanguage() {
        val english = ui("en")
        val before = screen("甲", "乙", "丙", "丁", id = "s7", ui = english)
        val identical = screen("甲", "乙", "丙", "丁", id = "s8", ui = english)
        val same = ScreenDigest.text("s7", before, "s8", identical, ui = english)
        assertTrue(same, same.contains("(Same as s7; the numbering is unchanged.)"))
        assertTrue(same, same.contains("Screen s8"))
        assertFalse(same, same.contains("相同"))

        val changed = screen("甲", "乙2", "丙", "丁", id = "s8", ui = english)
        val partial = ScreenDigest.text("s7", before, "s8", changed, observationChanged = true, ui = english)
        assertTrue(partial, partial.contains("乙2"))
        assertTrue(partial, partial.contains("(Only changes are listed: the other 3 items are the same as s7"))
        // An English screen's own note lines are still recognised as notes.
        assertFalse(partial, partial.contains("甲"))

        val chineseBefore = screen("甲", "乙", "丙", "丁", id = "s7")
        val chineseSame = screen("甲", "乙", "丙", "丁", id = "s8")
        assertTrue(ScreenDigest.text("s7", chineseBefore, "s8", chineseSame)
            .contains("（与 s7 相同，编号不变）"))
        val chineseChanged = screen("甲", "乙2", "丙", "丁", id = "s8")
        assertTrue(ScreenDigest.text("s7", chineseBefore, "s8", chineseChanged, observationChanged = true)
            .contains("（只列变化：其余 3 项与 s7 相同，编号不变）"))
    }

    // ---- privileged protocol refusals ----

    @Test fun thePrivilegedRefusalsSpeakInTheAppLanguage() {
        val english = ui("en")
        assertEquals(strings("values")["phone_reason_locked"], Reasons.of("locked", english))
        assertEquals("设备已锁定，后台屏操作已停止", Reasons.of("locked"))
        assertEquals("The background screen action’s parameters are invalid.",
            Reasons.of("invalidArguments", english))
        // A known code with a competing app named as detail, in the language of the caller.
        assertTrue(Reasons.of("launchDenied", "com.example.app", ui = english)
            .endsWith(" (com.example.app)"))
        assertEquals("后台屏动作参数无效", Reasons.of("invalidArguments"))
        assertEquals("系统拒绝了后台屏操作（com.example.app）", Reasons.of("systemOperationDenied", "com.example.app"))
        // textAccepted composes a sentence and never echoes the typed text.
        val accepted = Reasons.of("textReadbackMismatch", null, textAccepted = true, ui = english)
        assertTrue(accepted, accepted.startsWith("The field accepted the text request, but the read-back"))
        assertFalse(accepted, accepted.contains("回读"))
        assertEquals("输入框已接受文字请求，但回读与预期不一致。请先重新观察，不要自动重复输入或提交。",
            Reasons.of("textReadbackMismatch", null, textAccepted = true))
    }

    // ---- resource parity for the whole phone catalog ----

    @Test fun everyCatalogKeyExistsInBothLanguagesWithMatchingPlaceholders() {
        val source = File(main, "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneStrings.kt").readText()
        val keys = Regex("\"([a-z0-9_]+)\"\\s*->\\s*R\\.string\\.([a-z0-9_]+)").findAll(source)
            .map { it.groupValues[1] to it.groupValues[2] }.toList()
        assertTrue(keys.size > 400)
        val en = strings("values")
        val zh = strings("values-zh")
        for ((key, id) in keys) {
            assertEquals("$key resolves the same resource name", key, id)
            assertTrue("$key missing from values", en.containsKey(key))
            assertTrue("$key missing from values-zh", zh.containsKey(key))
            assertEquals("$key placeholders", placeholders(en.getValue(key)), placeholders(zh.getValue(key)))
            assertFalse("$key is still Chinese in values: ${en.getValue(key)}",
                Regex("[\\u4e00-\\u9fff]").containsMatchIn(en.getValue(key)))
        }
    }

    private fun placeholders(text: String) =
        Regex("%\\d+\\$[sd]").findAll(text).map { it.value }.toSortedSet()

    private companion object {
        const val PROCESS_A = "00000000-0000-4000-8000-0000000000a1"
        const val PROCESS_B = "00000000-0000-4000-8000-0000000000b2"
    }
}
