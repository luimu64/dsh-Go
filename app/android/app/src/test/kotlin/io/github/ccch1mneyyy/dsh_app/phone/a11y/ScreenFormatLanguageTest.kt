package io.github.ccch1mneyyy.dsh_app.phone.a11y

import io.github.ccch1mneyyy.dsh_app.phone.PhoneUiText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import java.util.Locale
import javax.xml.parsers.DocumentBuilderFactory

/**
 * The screen format is presented in the app language through a [PhoneUiText] resolved at the
 * render boundary, while element identities, fingerprints and every app/screen label stay
 * exactly as captured. Resources are the real ones: the English wording comes from
 * `res/values/i18n_strings.xml`, not a test-local list.
 */
class ScreenFormatLanguageTest {
    private val main = File("src/main")
    private val res = File(main, "res")

    private fun strings(language: String): Map<String, String> {
        val dir = File(res, if (language == "zh") "values-zh" else "values")
        val factory = DocumentBuilderFactory.newInstance()
        val out = linkedMapOf<String, String>()
        for (file in dir.listFiles().orEmpty().filter { it.isFile && it.extension == "xml" }.sortedBy { it.name }) {
            val root = factory.newDocumentBuilder().parse(file).documentElement
            val nodes = root.getElementsByTagName("string")
            for (index in 0 until nodes.length) {
                val element = nodes.item(index) as Element
                out[element.getAttribute("name")] = element.textContent
            }
            // A plural is one resource name; its quantities share the placeholders.
            val plurals = root.getElementsByTagName("plurals")
            for (index in 0 until plurals.length) {
                val plural = plurals.item(index) as Element
                val items = plural.getElementsByTagName("item")
                if (items.length > 0) out[plural.getAttribute("name")] = (items.item(0) as Element).textContent
            }
        }
        return out
    }

    /** The same resolution the app does: a resource string in the app language. */
    private fun ui(language: String): PhoneUiText {
        val catalog = strings(language)
        return PhoneUiText { key, args ->
            catalog[key]?.let { if (args.isEmpty()) it else String.format(Locale.ROOT, it, *args.toTypedArray()) }
        }
    }

    private fun frame() = Box(0, 0, 400, 800)

    private fun screen(): ScreenInput {
        val bounds = frame()
        val nodes = listOf(
            UiNode(text = "设置", heading = true, bounds = Box(0, 20, 400, 60)),
            UiNode(className = "android.widget.Button", text = "继续", clickable = true, bounds = Box(0, 100, 200, 140)),
            UiNode(className = "android.widget.EditText", hint = "密码", password = true, editable = true,
                bounds = Box(0, 160, 400, 200)),
            UiNode(className = "android.widget.CheckBox", text = "记住我", clickable = true, checkable = true,
                bounds = Box(0, 220, 400, 260)),
            UiNode(text = "账号与安全", bounds = Box(0, 300, 400, 340)),
            UiNode(text = "退出登录", clickable = true, bounds = Box(0, 700, 400, 740)),
        )
        return ScreenInput("s7", "示例", "example.app", 400, 800, false,
            listOf(UiWindow(1, WindowKind.APP, "example.app", null, bounds, UiNode(bounds = bounds, children = nodes))))
    }

    @Test fun englishIsRenderedWithoutTouchingChineseContentOrIdentity() {
        val chinese = ScreenFormat.format(screen())
        val english = ScreenFormat.format(screen(), ui("en"))

        // Header, zones and roles speak English.
        assertTrue(english.text, english.text.startsWith("Screen s7 · 示例 · portrait · keyboard closed · 6 items"))
        assertTrue(english.text, english.text.contains("Top"))
        assertTrue(english.text, english.text.contains("heading 设置"))
        assertTrue(english.text, english.text.contains("button 继续"))
        assertTrue(english.text, english.text.contains("text field (password; DSH won’t fill it)"))
        assertTrue(english.text, english.text.contains("checkbox 记住我 · not checked"))
        // No Chinese chrome left; the app's own words stay exactly as captured.
        for (chrome in listOf("屏幕", "竖屏", "键盘", "共 ", "顶部", "按钮", "勾选框", "已选", "空", "输入框")) {
            assertFalse("$chrome in: ${english.text}", english.text.contains(chrome))
        }
        assertTrue(english.text, english.text.contains("账号与安全"))
        assertTrue(english.text, english.text.contains("退出登录"))

        // Identity is untouched: same fingerprints, keys and element roles in both languages.
        assertEquals(chinese.elements.map { it.fingerprint }, english.elements.map { it.fingerprint })
        assertEquals(chinese.elements.map { it.key }, english.elements.map { it.key })
        assertEquals(chinese.elements.map { it.role }, english.elements.map { it.role })
        assertEquals(chinese.keys, english.keys)
        assertEquals(chinese.hidden, english.hidden)
        assertEquals(chinese.poorTree, english.poorTree)
    }

    @Test fun theChineseDefaultIsUnchanged() {
        val chinese = ScreenFormat.format(screen())
        assertTrue(chinese.text, chinese.text.startsWith("屏幕 s7 · 示例 · 竖屏 · 键盘收起 · 共 6 项"))
        assertTrue(chinese.text, chinese.text.contains("勾选框 记住我 · 空"))
        assertTrue(chinese.text, chinese.text.contains("输入框(密码，不可代填)"))
        assertEquals(chinese.text, ScreenFormat.format(screen()).text)
    }

    @Test fun poorTreeGuidanceFollowsTheAppLanguage() {
        val bounds = frame()
        fun thin(unreadable: Boolean) = ScreenInput("s1", "Game", "game.app", 400, 800, false,
            listOf(UiWindow(1, WindowKind.APP, "game.app", null, bounds, UiNode(bounds = bounds,
                children = listOf(UiNode(text = "开始", bounds = Box(0, 300, 200, 340)))))), unreadable = unreadable)
        assertTrue(ScreenFormat.format(thin(false)).text.contains(ScreenFormat.POOR_TREE_NOTE))
        val english = ScreenFormat.format(thin(false), ui("en")).text
        assertTrue(english, english.contains("very little text"))
        assertFalse(english, english.contains("提示"))
        // An unreadable window must not be called a poor tree in either language.
        assertFalse(ScreenFormat.format(thin(true), ui("en")).text.contains("very little text"))
        assertFalse(ScreenFormat.format(thin(true)).text.contains(ScreenFormat.POOR_TREE_NOTE))
    }

    @Test fun everyPhoneResourceTheCodeResolvesExistsInBothLanguages() {
        val en = strings("en")
        val zh = strings("zh")
        val key = Regex("\\.(?:get|text)\\(\"(phone_[a-z0-9_]+)\"")
        val used = File(main, "kotlin/io/github/ccch1mneyyy/dsh_app/phone").walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .flatMap { file -> key.findAll(file.readText()).map { it.groupValues[1] } }
            .toSet() + STATE_KEYS
        assertTrue(used.isNotEmpty())
        for (name in used) {
            assertTrue("$name missing from values", en.containsKey(name))
            assertTrue("$name missing from values-zh", zh.containsKey(name))
            assertEquals("$name placeholders", placeholders(en.getValue(name)), placeholders(zh.getValue(name)))
        }
    }

    private fun placeholders(text: String) = Regex("%\\d+\\$[sd]").findAll(text).map { it.value }.toSortedSet()

    private companion object {
        /** Built dynamically from the formatter's stable state tokens, so the scan can't see them. */
        val STATE_KEYS = listOf("selected", "empty", "focused", "disabled", "on", "off", "unchecked",
            "checked", "scroll_h_both", "scroll_right", "scroll_left", "scroll_v_both", "scroll_down",
            "scroll_up").map { "phone_screen_state_$it" }
    }
}
