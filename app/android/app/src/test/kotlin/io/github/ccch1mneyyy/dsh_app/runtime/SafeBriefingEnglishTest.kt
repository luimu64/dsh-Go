package io.github.ccch1mneyyy.dsh_app.runtime

import java.io.File
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

/**
 * The rescue briefing is read by an agent, so it follows the App language the user chose
 * ([RuntimeController] seeds [SafeMode.Briefing.english] from `AppStrings`). The Chinese text must
 * stay the default, and both versions must give the rescue agent the same paths and commands.
 */
class SafeBriefingEnglishTest {
    private val failure = RunFailure(
        kind = FailureKind.STARTUP_FAILED,
        exitCode = 1,
        at = 1_760_000_000_000L,
        safeMode = false,
        summary = "plugin boom",
        requiredRows = listOf("agent-loop"),
        suspects = listOf("dsh-plugin-x"),
        recent = listOf("dsh-plugin-y"),
        diagnostics = "/root/.dsh/logs/startup-1.log",
        upSeconds = null,
    )

    private fun briefing(english: Boolean) = SafeMode.Briefing(
        failure = failure,
        reason = SafePolicy.REASON_AUTO,
        moved = listOf("/root/.dsh/cordis.patch.yml → /root/.dsh/cordis.patch.yml.off-1"),
        lkgAt = 1_760_000_000_000L,
        lkgBundles = listOf("dsh-go"),
        lkgVersions = mapOf("dsh-go" to "1.2.3"),
        failureLog = emptyList(),
        timeZone = TimeZone.getTimeZone("UTC"),
        english = english,
    )

    /** The real entry point: [SafeMode.prepare] is what writes the file the rescue agent reads. */
    private fun prepared(english: Boolean): Pair<String, String> {
        val root = kotlin.io.path.createTempDirectory("safe-briefing").toFile()
        try {
            SafeMode.prepare(root, briefing(english))
            val dir = File(root, "var/lib/dsh-app/safe-mode")
            return File(dir, "agents/AGENTS.md").readText() to File(dir, "last-failure.log").readText()
        } finally {
            root.deleteRecursively()
        }
    }

    @Test fun prepareWritesTheWholeBriefingInEnglish() {
        val (text, log) = prepared(english = true)
        assertFalse("the English briefing must not contain Han characters", Regex("[\\u4e00-\\u9fff]").containsMatchIn(text))
        assertTrue(text.startsWith("<!-- dsh-app:safe-mode"))
        assertTrue(text.contains("# You are running in safe mode"))
        assertTrue(text.contains("## What happened"))
        assertTrue(text.contains("## Original and rescue data"))
        assertTrue(text.contains("## Where the main configuration is"))
        assertTrue(text.contains("## How to investigate"))
        assertTrue(text.contains("## How to repair (do the reversible steps first)"))
        assertTrue(text.contains("## How to verify"))
        assertTrue(text.contains("## Do not"))
        // The failure kinds and evidence are translated, not dropped.
        assertTrue(text.contains("; type: startup failed (it exited before printing a sign-in address); exit code: 1"))
        assertTrue(text.contains("`dsh-plugin-x` (appears in the crash output)"))
        assertTrue(text.contains("`agent-loop`"))
        assertTrue(text.contains("`/root/.dsh/logs/startup-1.log` (may contain secrets"))
        assertEquals("(no output was recorded around the failure)\n", log)
    }

    @Test fun chineseStaysTheDefault() {
        val (text, log) = prepared(english = false)
        assertTrue(text.startsWith("<!-- dsh-app:safe-mode — DSH App 每次进入安全模式时重写本文件，改了也会被覆盖 -->\n"))
        assertTrue(text.contains("# 你现在运行在「安全模式」"))
        assertTrue(text.contains("## 怎么修（先做可逆的）"))
        assertTrue(text.contains("- 可疑插件：`dsh-plugin-x`（崩溃信息里出现）、`dsh-plugin-y`（上次正常运行后新启用或升级过）"))
        assertTrue(text.contains("；类型：启动失败（还没打印登录地址就退出了）；退出码：1"))
        assertEquals("（没有记录到失败时的输出）\n", log)
        // A caller that does not pass the language gets exactly the Chinese text.
        val default = SafeMode.Briefing(
            failure = failure, reason = SafePolicy.REASON_AUTO,
            moved = listOf("/root/.dsh/cordis.patch.yml → /root/.dsh/cordis.patch.yml.off-1"),
            lkgAt = 1_760_000_000_000L, lkgBundles = listOf("dsh-go"),
            lkgVersions = mapOf("dsh-go" to "1.2.3"), failureLog = emptyList(),
            timeZone = TimeZone.getTimeZone("UTC"),
        )
        assertEquals(text, SafeMode.renderBriefing(default))
    }

    @Test fun pathsAndCommandsAreIdenticalInBothLanguages() {
        val chinese = prepared(english = false).first
        val english = prepared(english = true).first
        // Translation may reword prose around a path, so compare the paths that carry meaning:
        // where the rescue home, the original data, the tools, the profile and the guarded
        // files live. A blanket sweep of every slash-run also catches `$PWD/dsh-recovery.tar`
        // and grep patterns, which legitimately differ in wording.
        val critical = listOf(
            SafeMode.TOOL,
            SafeMode.PROFILE,
            SafeMode.ORIGINAL_HOME,
            "/root/.dsh/profiles/web/package.json",
            "/root/.dsh/profiles/web/cordis.patch.yml",
            "/root/.dsh/profiles/web/.plugin-manager/logs",
            "/root/.dsh/logs",
            "/root/.dsh/cordis.patch.yml",
            "/root/.dsh/.env",
            "/root/.env",
            "/root/.dsh/sessions",
            "/root/.dsh/storages",
            "/root/.dsh/.credentials.yaml",
            "/opt/dsh",
            "/opt/node",
            "/tmp/dsh-web.pid",
            "last-failure.log",
            "/dsh-app/diagnostics.md",
        )
        for (path in critical) {
            assertTrue("Chinese briefing is missing `$path`", chinese.contains(path))
            assertTrue("English briefing is missing `$path`", english.contains(path))
        }

        val commands = listOf(
            "${SafeMode.TOOL} list",
            "${SafeMode.TOOL} blame",
            "${SafeMode.TOOL} trial",
            "${SafeMode.TOOL} disable",
            "${SafeMode.TOOL} enable",
            "${SafeMode.TOOL} export",
            "DSH_HOME=${SafeMode.ORIGINAL_HOME} dsh plugin --profile web remove",
            "grep -l",
            "pkill node",
            "/tmp/dsh-web.pid",
            "free -m",
            "cp /root/.dsh/profiles/web/cordis.patch.yml",
            "mv /root/.dsh/profiles/web",
            "date +%Y%m%d%H%M",
        )
        for (command in commands) {
            assertTrue("Chinese briefing is missing `$command`", chinese.contains(command))
            assertTrue("English briefing is missing `$command`", english.contains(command))
        }
        assertEquals(chinese.split("## ").size, english.split("## ").size)
        assertEquals(chinese.lines().count { it.startsWith("- ") }, english.lines().count { it.startsWith("- ") })
    }

    /** The same app-language rule for the three background change notes the model reads. */
    @Test fun backgroundVisualNotesFollowTheAppLanguage() {
        val res = File("src/main/res")
        fun catalog(directory: String): Map<String, String> {
            val out = linkedMapOf<String, String>()
            for (file in File(res, directory).listFiles().orEmpty().filter { it.isFile && it.extension == "xml" }) {
                val root = javax.xml.parsers.DocumentBuilderFactory.newInstance()
                    .newDocumentBuilder().parse(file).documentElement
                val nodes = root.getElementsByTagName("string")
                for (index in 0 until nodes.length) {
                    val element = nodes.item(index) as org.w3c.dom.Element
                    out[element.getAttribute("name")] = element.textContent
                }
            }
            return out
        }
        fun ui(directory: String): io.github.ccch1mneyyy.dsh_app.phone.PhoneUiText {
            val strings = catalog(directory)
            return io.github.ccch1mneyyy.dsh_app.phone.PhoneUiText { key, _ -> strings[key] }
        }
        val english = ui("values")
        val chinese = ui("values-zh")
        assertEquals("; compared with the latest observation, the screen clearly changed (this does not mean the action succeeded)",
            io.github.ccch1mneyyy.dsh_app.phone.background.backgroundVisualNote(english, "changed"))
        for (value in listOf("changed", "unchanged", "unavailable")) {
            assertTrue(
                "English note for $value is missing",
                io.github.ccch1mneyyy.dsh_app.phone.background.backgroundVisualNote(english, value)
                    .startsWith("; "),
            )
            assertFalse(
                "English note for $value still speaks Chinese",
                Regex("[\\u4e00-\\u9fff]").containsMatchIn(
                    io.github.ccch1mneyyy.dsh_app.phone.background.backgroundVisualNote(english, value),
                ),
            )
            assertEquals(
                io.github.ccch1mneyyy.dsh_app.phone.background.backgroundVisualNote(chinese, value),
                io.github.ccch1mneyyy.dsh_app.phone.background.backgroundVisualNote(value),
            )
        }
        assertEquals("", io.github.ccch1mneyyy.dsh_app.phone.background.backgroundVisualNote(english, "other"))
    }
}
