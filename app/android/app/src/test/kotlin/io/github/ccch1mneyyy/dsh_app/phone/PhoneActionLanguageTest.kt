package io.github.ccch1mneyyy.dsh_app.phone

import io.github.ccch1mneyyy.dsh_app.phone.a11y.MainScreenDriver
import io.github.ccch1mneyyy.dsh_app.phone.a11y.unconfirmedActionNote
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import java.util.Locale
import javax.xml.parsers.DocumentBuilderFactory

/**
 * The action, collect, route, safety and system results reach the model in the app language
 * through [PhoneUiText], while the Chinese literal at each call site stays the fallback that an
 * unresolvable key and a plain JVM construction see. Resources are the real ones: English comes
 * from `res/values/`, Chinese from `res/values-zh/`.
 */
class PhoneActionLanguageTest {
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

    private fun target(label: String = "打开", password: Boolean = false) =
        TargetInfo("s1", 1, "按钮", label, "example.app", "Example", password, false, password)

    private fun ownAppRefusal(language: String?): String {
        val gate = SafetyGate({ PhonePolicies() }, PhoneTasks(), { null },
            uiText = language?.let(::ui) ?: PhoneUiText.DEFAULT)
        return (gate.checkWrite(WriteKind.TAP, target(), SafetyRules.OWN_PACKAGE, null) as SafetyGate.Verdict.Refuse).message
    }

    @Test fun safetyRefusalsSpeakTheAppLanguageAndKeepChineseByDefault() {
        val english = ownAppRefusal("en")
        assertTrue(english, english.contains("DSH's own UI") || english.contains("DSH’s own UI"))
        for (chrome in listOf("这是", "界面", "不读取")) assertFalse("$chrome in: $english", english.contains(chrome))

        assertEquals("这是 DSH 自己的界面，不读取也不操作。", ownAppRefusal(null))
        assertEquals(ownAppRefusal("zh"), ownAppRefusal(null))

        val gate = SafetyGate({ PhonePolicies() }, PhoneTasks(), { null }, uiText = ui("en"))
        val secret = (gate.checkWrite(WriteKind.TAP, target(password = true), "example.app", "Example") as SafetyGate.Verdict.Refuse).message
        assertTrue(secret, secret.contains("Password"))
        assertFalse(secret, secret.contains("密码"))

        // The deny list names the app in the app language, and the app's own label is untouched.
        val denied = (gate.checkWrite(WriteKind.TAP, target(), "com.icbc", "工商银行") as SafetyGate.Verdict.Refuse).message
        assertTrue(denied, denied.contains("left alone by default"))
        assertTrue(denied, denied.contains("工商银行"))
    }

    @Test fun intentValidationErrorsSpeakTheAppLanguage() {
        val args = Args(mapOf("kind" to "alarm", "minute" to 30))
        val english = (IntentSpec.parse(args, java.time.ZoneId.of("UTC"), ui("en")) as Either.Left<String>).value
        assertTrue(english, english.contains("alarm needs hour"))
        val chinese = (IntentSpec.parse(args, java.time.ZoneId.of("UTC")) as Either.Left<String>).value
        assertTrue(chinese, chinese.contains("alarm 需要 hour"))

        val blocked = UrlPolicy.check("intent://evil", ui("en"))!!
        assertTrue(blocked, blocked.contains("isn't supported") || blocked.contains("isn’t supported"))
        assertEquals("不支持 intent: 链接", UrlPolicy.check("intent://evil"))
    }

    @Test fun taskStopTextSpeaksTheAppLanguageAndKeepsChineseByDefault() {
        val english = (PhoneTasks(ui = ui("en")).apply { stop("test") }.begin() as PhoneTasks.Begin.Refused).message
        assertTrue(english, english.startsWith("You stopped phone control for this turn"))
        assertFalse(english, english.contains("停止"))
        assertEquals(PhoneTasks.STOPPED_MESSAGE, (PhoneTasks().apply { stop("test") }.begin() as PhoneTasks.Begin.Refused).message)
        assertEquals(PhoneTasks.STOPPED_MESSAGE, PhoneTasks.stoppedMessage())
        assertTrue(PhoneTasks.cancelledMessage(ui("en")).startsWith("This phone action was cancelled"))
        assertTrue(PhoneTasks.noConfirmMessage(ui("en")).startsWith("This needs your confirmation"))
    }

    @Test fun readBackAndUnconfirmedNotesSpeakTheAppLanguage() {
        val english = MainScreenDriver.readBackMismatch("13579", target(), ui = ui("en"))
        assertTrue(english, english.startsWith("Typed, but the read-back differs"))
        assertFalse(english, english.contains("回读"))

        val chinese = MainScreenDriver.readBackMismatch("13579", target())
        assertTrue(chinese, chinese.startsWith("已输入，但回读不一致"))
        assertEquals(chinese, MainScreenDriver.readBackMismatch("13579", target(), ui = ui("zh")))

        val note = unconfirmedActionNote(comparable = false, changed = false, keyboard = null, ui = ui("en"))
        assertTrue(note, note.contains("unconfirmed"))
        assertEquals(unconfirmedActionNote(false, false, null), unconfirmedActionNote(false, false, null, PhoneUiText.DEFAULT))
    }

    @Test fun theTypedValueItselfIsNeverTranslated() {
        // The person's text and the app's label travel through the format arguments untouched.
        val english = MainScreenDriver.readBackMismatch("咖啡 123", target(label = "昵称"), ui = ui("en"))
        assertTrue(english, english.contains("咖啡 123"))
        assertTrue(english, english.startsWith("Typed, but the read-back differs"))
    }

    @Test fun everyPhoneKeyTheOwnedCodeResolvesExistsInBothLanguagesWithTheSamePlaceholders() {
        val en = strings("en")
        val zh = strings("zh")
        val key = Regex("(?:ui|uiText|localizedUi)\\.get\\(\"(phone_[a-z0-9_]+)\"")
        val owned = listOf(
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/a11y/MainScreenDriver.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneControl.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneTaskSessions.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneTasks.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/SafetyGate.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/SystemApi.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/SystemActions.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneCore.kt",
        )
        val used = owned.flatMap { path -> key.findAll(File(main, path).readText()).map { it.groupValues[1] } }.toSet()
        assertTrue(used.size > 100)
        for (name in used) {
            assertTrue("$name missing from values", en.containsKey(name))
            assertTrue("$name missing from values-zh", zh.containsKey(name))
            assertEquals("$name placeholders", placeholders(en.getValue(name)), placeholders(zh.getValue(name)))
        }
    }

    @Test fun theOwnedFilesCarryNoChineseOnlyDisplayTextLeft() {
        val owned = listOf(
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/a11y/MainScreenDriver.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneControl.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneTaskSessions.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneTasks.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/SafetyGate.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/SystemApi.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/SystemActions.kt",
            "kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneCore.kt",
        )
        val han = Regex("[\\u4e00-\\u9fff]")
        for (path in owned) {
            File(main, path).readLines().forEachIndexed { index, line ->
                val text = line.trim()
                if (text.startsWith("//") || text.startsWith("*") || text.startsWith("/*")) return@forEachIndexed
                if (!han.containsMatchIn(line)) return@forEachIndexed
                // A Chinese literal is allowed only as the fallback of a resolver call, in the
                // stop constants, or where a Chinese token is matched on purpose.
                val fallback = text.startsWith("\"") || text.startsWith("? ->")
                val resolved = line.contains("ui.get(") || line.contains("uiText.get(") || line.contains("localizedUi.get(")
                val constant = line.contains("const val ") || line.contains("\"phone_") || line.contains("STOPPED_MESSAGE") ||
                    line.contains("CANCELLED_MESSAGE") || line.contains("NO_CONFIRM_MESSAGE") || line.contains("RUN_ENDED_MESSAGE")
                val matched = line.contains("\"«银行卡\"") || line.contains("\"«身份证\"") || line.contains("\"按钮\"") ||
                    line.contains("StopSource.") || line.contains("stopAll(\"") || line.contains("tasks.stop(\"") ||
                    line.contains("stopIfCurrent(") || line.contains("denied.message")
                assertTrue("$path:${index + 1} Chinese display text without a resolver: $text",
                    resolved || fallback || constant || matched)
            }
        }
    }

    private fun placeholders(text: String) = Regex("%\\d+\\$[sd]").findAll(text).map { it.value }.toSortedSet()
}
