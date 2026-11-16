package io.github.ccch1mneyyy.dsh_app.i18n

import android.content.Context
import android.content.res.Configuration
import androidx.annotation.PluralsRes
import androidx.annotation.StringRes
import java.util.Locale

/**
 * Native text in the language the app shows (设置 → 语言), not the system's.
 *
 * The Flutter side stores the choice in SharedPreferences as `app_language`
 * (`system` / `zh` / `en`, lib/state/locale_state.dart); here it is
 * `flutter.app_language` in `FlutterSharedPreferences`. `values/` holds
 * English, `values-zh/` Chinese.
 *
 * The language is resolved with the same rule as `AppLocale.resolve` in Dart:
 * an explicit `zh` or `en` wins, otherwise the first of the system's preferred
 * languages that is Chinese or English wins, and anything else (including an
 * empty list) is English. Resource resolution is not used as the source of
 * truth because it need not agree with that scan, and it ignores the app's
 * explicit choice.
 */
object AppStrings {
    /** The app's name as the phone shows it (`android:label` in AndroidManifest.xml), in every
     *  language: notification titles and their fallbacks. */
    const val APP_NAME = "DSH Go"

    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY = "flutter.app_language"

    private data class Cached(val language: String, val source: Configuration, val context: Context)

    @Volatile private var cache: Cached? = null

    /** `zh`, `en`, or null to follow the system. */
    fun language(ctx: Context): String? =
        (ctx.applicationContext ?: ctx)
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)
            ?.takeIf { it == "zh" || it == "en" }

    /** The language native text comes out in: `zh` or `en`. */
    fun resolvedLanguage(ctx: Context): String {
        val app = ctx.applicationContext ?: ctx
        val locales = app.resources.configuration.locales
        return resolveLanguage(language(app), (0 until locales.size()).map { locales[it].toLanguageTag() })
    }

    /** True when native text comes out in English. */
    fun isEnglish(ctx: Context): Boolean = resolvedLanguage(ctx) == "en"

    /**
     * The pure rule behind [resolvedLanguage], shared with Dart's AppLocale.
     * A null or unrecognised [choice] follows [systemLanguages].
     */
    fun resolveLanguage(choice: String?, systemLanguages: List<String>): String {
        if (choice == "zh" || choice == "en") return choice
        for (tag in systemLanguages) {
            when (tag.substringBefore('-').substringBefore('_').lowercase(Locale.ROOT)) {
                "zh" -> return "zh"
                "en" -> return "en"
            }
        }
        return "en"
    }

    /** A context whose resources are in the resolved app language. */
    fun context(ctx: Context): Context {
        val app = ctx.applicationContext ?: ctx
        val language = resolvedLanguage(app)
        val source = Configuration(app.resources.configuration)
        cache?.let { if (it.language == language && it.source == source) return it.context }
        val locale = if (language == "zh") Locale.SIMPLIFIED_CHINESE else Locale.ENGLISH
        val config = Configuration(source).apply { setLocale(locale) }
        return app.createConfigurationContext(config).also { cache = Cached(language, source, it) }
    }

    fun get(ctx: Context, @StringRes id: Int): String = context(ctx).getString(id)

    fun get(ctx: Context, @StringRes id: Int, vararg args: Any): String = context(ctx).getString(id, *args)

    fun plural(ctx: Context, @PluralsRes id: Int, count: Int, vararg args: Any): String =
        context(ctx).resources.getQuantityString(id, count, *args)
}
