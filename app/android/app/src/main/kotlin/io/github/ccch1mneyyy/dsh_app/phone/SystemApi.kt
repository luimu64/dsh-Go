package io.github.ccch1mneyyy.dsh_app.phone

import java.net.URLEncoder
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeParseException

/** A launchable app. */
data class PhoneAppIdentity(val packageName: String, val uid: Int) {
    init { require(packageName.isNotBlank() && uid >= 0) }
}

data class AppEntry(val label: String, val identity: PhoneAppIdentity) {
    val packageName: String get() = identity.packageName
}

/** The handler being requested, not proof of the foreground app or a completed operation. */
sealed interface SystemTarget {
    data class Known(val app: AppEntry) : SystemTarget
    data object UserChoice : SystemTarget
    /** PM could not name the handler; the Intent is sent as it is, after a one-time confirmation. */
    data object Unknown : SystemTarget
}

/** Android keeps the Intent private; Core checks its prepared target and explicit package for approval. */
interface SystemLaunch {
    val target: SystemTarget
    /** The fixed Intent's explicit package, when known; this does not certify a UID. */
    val packageName: String? get() = null
}

/** target is present only once a platform start was attempted, including a throwing start. */
class SysResult(val ok: Boolean, val message: String, val target: SystemTarget? = null,
    /** A returned platform start still needs the person to check its actual effect. */
    val requiresReview: Boolean = false) {
    val appLabel: String? get() = (target as? SystemTarget.Known)?.app?.label
}

/** System actions consumed by Core, implemented by Android and faked at the same boundary in tests. */
interface SystemApi {
    fun apps(): List<AppEntry>
    fun isInstalled(pkg: String): Boolean
    fun prepareLaunch(app: AppEntry): Either<String, SystemLaunch>
    fun prepareUrl(url: String): Either<String, SystemLaunch>
    fun prepareIntent(spec: IntentSpec, selectedApp: AppEntry?): Either<String, SystemLaunch>
    fun launch(plan: SystemLaunch, dispatch: PhoneTasks.SystemDispatch): SysResult
    fun notify(title: String, text: String): SysResult
    fun clipboardSet(text: String): SysResult
    fun clipboardGet(): SysResult
}

/** PM adapter data. No package-name heuristic can identify every platform/OEM resolver. */
internal data class SystemHandler(val packageName: String, val component: String, val uid: Int)
internal sealed interface SystemResolution {
    data class Known(val handler: SystemHandler) : SystemResolution
    data object Choice : SystemResolution
}

/** Classifies PM facts during Android preparation. Null means the target identity is unknown. */
internal object SystemHandlers {
    /** ActivityInfo.enabled may still be the manifest flag for a runtime-enabled launcher alias. */
    fun componentEnabled(manifestEnabled: Boolean, readSetting: () -> Int): Boolean = try {
        when (readSetting()) {
            0 -> manifestEnabled // PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
            1 -> true // PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else -> false // Explicitly disabled or unknown: never fall back to the manifest.
        }
    } catch (_: Exception) { false }

    fun valid(candidates: List<SystemHandler>, packageName: String?): Boolean =
        candidates.isNotEmpty() && candidates.all {
            it.packageName.isNotBlank() && it.component.isNotBlank() && it.uid >= 0 &&
                (packageName == null || it.packageName == packageName)
        } && candidates.groupBy { it.packageName to it.component }.values.all { group ->
            group.map { it.uid }.distinct().size == 1
        }

    fun resolve(candidates: List<SystemHandler>, resolved: SystemHandler?, packageName: String?, allowChoice: Boolean): SystemResolution? {
        if (!valid(candidates, packageName) || resolved == null || resolved.packageName.isBlank() ||
            resolved.component.isBlank() || resolved.uid < 0) return null
        if (resolved in candidates) return SystemResolution.Known(resolved)
        // A conflicting UID for the same component is not a reason to launch a chooser.
        if (candidates.any { it.packageName == resolved.packageName && it.component == resolved.component }) return null
        return if (allowChoice) SystemResolution.Choice else null
    }
}

/** The fixed `intent` kinds (no arbitrary Intents: they could carry any component or extra). */
sealed interface IntentSpec {
    data class Alarm(val hour: Int, val minute: Int, val message: String?, val days: List<Int>) : IntentSpec
    data class Timer(val seconds: Int, val message: String?) : IntentSpec
    data class Calendar(
        val title: String,
        val beginMs: Long,
        val endMs: Long,
        val allDay: Boolean,
        val location: String?,
        val description: String?,
    ) : IntentSpec
    data class Dial(val number: String) : IntentSpec
    data class SmsDraft(val number: String?, val text: String) : IntentSpec
    data class Share(val text: String, val app: String?) : IntentSpec
    data class Navigate(val destination: String?, val lat: Double?, val lng: Double?, val mode: String, val map: String?) : IntentSpec
    data class Settings(val page: String, val app: String?) : IntentSpec

    companion object {
        /** Parses `intent` arguments; [Either.Left] is the message for the model. */
        fun parse(a: Args, zone: ZoneId, ui: PhoneUiText = PhoneUiText.DEFAULT): Either<String, IntentSpec> {
            val kind = a.str("kind") ?: return Either.Left(ui.get("phone_intent_needs_kind",
                "intent 需要 kind：%1\$s", PhoneToolCatalog.INTENT_KINDS.joinToString(" / ")))
            return when (kind) {
                "alarm" -> {
                    val hour = a.int("hour") ?: return Either.Left(
                        ui.get("phone_intent_alarm_needs_time", "alarm 需要 hour（0–23）和 minute（0–59）"))
                    val minute = a.int("minute") ?: 0
                    if (hour !in 0..23 || minute !in 0..59) return Either.Left(
                        ui.get("phone_intent_alarm_bad_time", "alarm 的时间不对：hour 0–23，minute 0–59"))
                    val days = a.intList("days") ?: emptyList()
                    if (days.any { it !in 1..7 }) return Either.Left(
                        ui.get("phone_intent_days", "days 用 1–7 表示周一到周日"))
                    Either.Right(Alarm(hour, minute, a.str("message"), days.distinct().sorted()))
                }
                "timer" -> {
                    val s = a.int("seconds") ?: return Either.Left(
                        ui.get("phone_intent_timer_needs", "timer 需要 seconds（1–86400）"))
                    if (s !in 1..86400) return Either.Left(
                        ui.get("phone_intent_timer_range", "timer 的 seconds 要在 1–86400 之间"))
                    Either.Right(Timer(s, a.str("message")))
                }
                "calendar" -> {
                    val title = a.str("title") ?: return Either.Left(
                        ui.get("phone_intent_calendar_needs", "calendar 需要 title 和 begin"))
                    val beginText = a.str("begin") ?: return Either.Left(
                        ui.get("phone_intent_calendar_begin", "calendar 需要 begin，例如 2026-10-24T19:00"))
                    val begin = parseTime(beginText, zone) ?: return Either.Left(ui.get("phone_intent_begin_unreadable",
                        "begin 看不懂：写成 2026-10-24T19:00，或全天日程写 2026-10-24"))
                    val allDay = a.bool("all_day") ?: begin.dateOnly
                    val end = a.str("end")?.let {
                        parseTime(it, zone) ?: return Either.Left(
                            ui.get("phone_intent_end_unreadable", "end 看不懂：写成 2026-10-24T20:00"))
                    }
                    val endMs = end?.ms ?: (begin.ms + if (allDay) 86_400_000L else 3_600_000L)
                    if (endMs < begin.ms) return Either.Left(ui.get("phone_intent_end_before", "end 早于 begin"))
                    Either.Right(Calendar(title, begin.ms, endMs, allDay, a.str("location"), a.str("description")))
                }
                "dial" -> {
                    val n = a.str("number") ?: return Either.Left(ui.get("phone_intent_dial_needs", "dial 需要 number"))
                    phoneNumber(n)?.let { Either.Right(Dial(it)) } ?: Either.Left(ui.get("phone_intent_number_invalid",
                        "号码只能含数字、+、-、空格和括号（不支持 * 和 # 这类服务码）"))
                }
                "sms_draft" -> {
                    val text = a.str("text") ?: return Either.Left(ui.get("phone_intent_sms_needs", "sms_draft 需要 text"))
                    val n = a.str("number")
                    val num = n?.let {
                        phoneNumber(it) ?: return Either.Left(
                            ui.get("phone_intent_number_only", "号码只能含数字、+、-、空格和括号"))
                    }
                    Either.Right(SmsDraft(num, text))
                }
                "share" -> {
                    val text = a.str("text") ?: return Either.Left(ui.get("phone_intent_share_needs", "share 需要 text"))
                    Either.Right(Share(text, a.str("app")))
                }
                "navigate" -> {
                    val dest = a.str("destination")
                    val lat = a.double("lat")
                    val lng = a.double("lng")
                    if ((lat == null) != (lng == null)) return Either.Left(
                        ui.get("phone_intent_latlng_pair", "lat 和 lng 要一起给"))
                    if (lat != null && (lat !in -90.0..90.0 || lng!! !in -180.0..180.0)) return Either.Left(
                        ui.get("phone_intent_coord_range", "坐标超出范围"))
                    if (dest == null && lat == null) return Either.Left(
                        ui.get("phone_intent_navigate_needs", "navigate 需要 destination，或者 lat + lng"))
                    val mode = a.str("mode") ?: "drive"
                    if (mode !in PhoneToolCatalog.NAV_MODES) return Either.Left(ui.get("phone_intent_mode",
                        "mode 只能是 %1\$s", PhoneToolCatalog.NAV_MODES.joinToString(" / ")))
                    val map = a.str("map")
                    if (map != null && map != "amap" && map != "baidu") return Either.Left(
                        ui.get("phone_intent_map", "map 只能是 amap 或 baidu"))
                    Either.Right(Navigate(dest, lat, lng, mode, map))
                }
                "settings" -> {
                    val page = a.str("page") ?: return Either.Left(ui.get("phone_intent_settings_needs",
                        "settings 需要 page：%1\$s", PhoneToolCatalog.SETTINGS_PAGES.joinToString(" / ")))
                    if (page !in PhoneToolCatalog.SETTINGS_PAGES) {
                        return Either.Left(ui.get("phone_intent_settings_unknown",
                            "没有这个设置页。可用：%1\$s（无障碍、开发者选项、权限等页面不提供）",
                            PhoneToolCatalog.SETTINGS_PAGES.joinToString(" / ")))
                    }
                    if (page == "app_notifications" && a.str("app") == null) return Either.Left(
                        ui.get("phone_intent_app_notifications", "app_notifications 需要 app（包名或应用名）"))
                    Either.Right(Settings(page, a.str("app")))
                }
                else -> Either.Left(ui.get("phone_intent_unknown_kind",
                    "不支持的 kind「%1\$s」，只能是 %2\$s", kind, PhoneToolCatalog.INTENT_KINDS.joinToString(" / ")))
            }
        }

        class Time(val ms: Long, val dateOnly: Boolean)

        /** `2026-10-24T19:00`, `2026-10-24 19:00[:ss]`, with an optional offset, or a bare date. */
        fun parseTime(text: String, zone: ZoneId): Time? {
            val t = text.trim().replace(' ', 'T')
            try {
                return Time(OffsetDateTime.parse(t).toInstant().toEpochMilli(), false)
            } catch (_: DateTimeParseException) {
            }
            try {
                return Time(LocalDateTime.parse(t).atZone(zone).toInstant().toEpochMilli(), false)
            } catch (_: DateTimeParseException) {
            }
            try {
                return Time(LocalDate.parse(t).atStartOfDay(zone).toInstant().toEpochMilli(), true)
            } catch (_: DateTimeParseException) {
            }
            return null
        }

        private val NUMBER = Regex("^\\+?[0-9][0-9 ()\\-]{1,30}$")

        fun phoneNumber(raw: String): String? {
            val n = raw.trim()
            return if (NUMBER.matches(n)) n.replace(" ", "") else null
        }
    }
}

/** Deep-link builders for `intent kind=navigate` (高德 URI API / 百度 / geo:). */
object NavUris {
    const val AMAP = "com.autonavi.minimap"
    const val BAIDU = "com.baidu.BaiduMap"

    fun enc(s: String): String = URLEncoder.encode(s, "UTF-8").replace("+", "%20")

    fun amap(n: IntentSpec.Navigate): String = buildString {
        append("amapuri://route/plan/?sourceApplication=DSH")
        n.destination?.let { append("&dname=").append(enc(it)) }
        if (n.lat != null && n.lng != null) append("&dlat=").append(n.lat).append("&dlon=").append(n.lng)
        append("&dev=0&t=").append(
            when (n.mode) {
                "transit" -> 1
                "walk" -> 2
                "ride" -> 3
                else -> 0
            },
        )
    }

    fun baidu(n: IntentSpec.Navigate): String {
        val dest = if (n.lat != null && n.lng != null) {
            "latlng:${n.lat},${n.lng}" + (n.destination?.let { "|name:$it" } ?: "")
        } else {
            n.destination ?: ""
        }
        val mode = when (n.mode) {
            "transit" -> "transit"
            "walk" -> "walking"
            "ride" -> "riding"
            else -> "driving"
        }
        return "baidumap://map/direction?destination=${enc(dest)}&coord_type=gcj02&mode=$mode&src=${enc(SafetyRules.OWN_PACKAGE)}"
    }

    fun geo(n: IntentSpec.Navigate): String = if (n.lat != null && n.lng != null) {
        "geo:${n.lat},${n.lng}?q=${n.lat},${n.lng}" + (n.destination?.let { "(${enc(it)})" } ?: "")
    } else {
        "geo:0,0?q=${enc(n.destination ?: "")}"
    }
}

/** Which URLs `open` may hand to the system: no `intent:` (arbitrary components), no local files. */
object UrlPolicy {
    private val SCHEME = Regex("^([A-Za-z][A-Za-z0-9+.\\-]*):")
    private val BLOCKED = setOf("intent", "file", "content", "javascript", "data", "android-app", "about", "chrome", "jar", "vnd.youtube.launch")

    fun check(url: String, ui: PhoneUiText = PhoneUiText.DEFAULT): String? {
        if (url.length > 4000) return ui.get("phone_url_too_long", "链接太长")
        if (url.any { it.isWhitespace() || it < ' ' }) return ui.get(
            "phone_url_whitespace", "链接里不能有空白字符（需要的话先做 URL 编码）")
        val scheme = SCHEME.find(url)?.groupValues?.get(1)?.lowercase() ?: return ui.get(
            "phone_url_needs_scheme", "链接要带协议，例如 https:// 或 amapuri://")
        if (scheme in BLOCKED) return ui.get("phone_url_scheme_blocked", "不支持 %1\$s: 链接", scheme)
        return null
    }
}

/** Finds an app by package or name. */
object AppMatch {
    sealed interface Result {
        class Found(val app: AppEntry) : Result
        class Ambiguous(val candidates: List<AppEntry>) : Result
        object NotFound : Result
    }

    private fun norm(s: String) = s.lowercase().replace(" ", "")

    fun resolve(apps: List<AppEntry>, query: String): Result {
        val q = query.trim()
        if (q.isEmpty()) return Result.NotFound
        apps.firstOrNull { it.packageName == q }?.let { return Result.Found(it) }
        val nq = norm(q)
        val exact = apps.filter { norm(it.label) == nq }
        if (exact.size == 1) return Result.Found(exact[0])
        if (exact.size > 1) return Result.Ambiguous(exact)
        val partial = apps.filter { norm(it.label).contains(nq) || (nq.length >= 2 && nq.contains(norm(it.label)) && norm(it.label).length >= 2) }
        return when (partial.size) {
            0 -> Result.NotFound
            1 -> Result.Found(partial[0])
            else -> Result.Ambiguous(partial.take(8))
        }
    }

    fun filter(apps: List<AppEntry>, query: String?): List<AppEntry> {
        val q = query?.trim()?.takeIf { it.isNotEmpty() }?.let { norm(it) } ?: return apps
        return apps.filter { norm(it.label).contains(q) || it.packageName.lowercase().contains(q) }
    }
}

sealed interface Either<out L, out R> {
    class Left<L>(val value: L) : Either<L, Nothing>
    class Right<R>(val value: R) : Either<Nothing, R>
}

/** Lenient typed access to tool arguments (models send "7" for 7 and 7.0 for 7). */
class Args(private val map: Map<String, Any?>) {
    fun has(key: String) = map[key] != null
    /** Presence differs from the existing non-null has(): explicit null must not request AUTO. */
    fun provided(key: String) = map.containsKey(key)
    /** Disclosure choices require an actual JSON boolean, not a coerced string or number. */
    fun strictBool(key: String) = map[key] as? Boolean
    /** Focus input preserves the actual JSON string; existing type coercion is unchanged. */
    fun strictText(key: String) = map[key] as? String
    fun strictInt(key: String): Int? = when (val value = map[key]) {
        is Int -> value
        is Long -> value.toInt().takeIf { it.toLong() == value }
        else -> null
    }
    fun onlyKeys(vararg keys: String) = map.keys.all { it in keys }

    fun str(key: String): String? = when (val v = map[key]) {
        is String -> v.trim().takeIf { it.isNotEmpty() }
        is Number, is Boolean -> v.toString()
        else -> null
    }

    /** The raw string, untrimmed (text to type). */
    fun text(key: String): String? = when (val v = map[key]) {
        is String -> v
        is Number -> v.toString()
        else -> null
    }

    fun int(key: String): Int? = when (val v = map[key]) {
        is Long -> v.toInt().takeIf { it.toLong() == v }
        is Int -> v
        is Double -> if (v == Math.rint(v) && Math.abs(v) < Int.MAX_VALUE) v.toInt() else null
        is String -> v.trim().removePrefix("[").removeSuffix("]").toIntOrNull()
        else -> null
    }

    fun double(key: String): Double? = when (val v = map[key]) {
        is Number -> v.toDouble()
        is String -> v.trim().toDoubleOrNull()
        else -> null
    }

    fun bool(key: String): Boolean? = when (val v = map[key]) {
        is Boolean -> v
        is String -> when (v.trim().lowercase()) {
            "true", "1", "yes" -> true
            "false", "0", "no" -> false
            else -> null
        }
        is Number -> v.toInt() != 0
        else -> null
    }

    fun intList(key: String): List<Int>? {
        val v = map[key] ?: return null
        val list = v as? List<*> ?: return listOfNotNull(Args(mapOf("x" to v)).int("x"))
        return list.mapNotNull { Args(mapOf("x" to it)).int("x") }
    }
}
