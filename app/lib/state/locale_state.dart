import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// 设置 → 语言.
enum AppLanguage {
  system,
  zh,
  en;

  /// The fixed locale, or null to follow the system languages.
  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.zh => AppLocale.zhCN,
    AppLanguage.en => AppLocale.en,
  };

  static AppLanguage parse(String? v) =>
      AppLanguage.values.firstWhere((l) => l.name == v, orElse: () => AppLanguage.system);
}

Locale _resolveAppLanguage(AppLanguage language) {
  // Fixed choices also work in background services without a widget binding.
  final fixed = language.locale;
  return fixed ?? AppLocale.resolve(null, WidgetsBinding.instance.platformDispatcher.locales);
}

class AppLanguageController extends Notifier<AppLanguage> {
  /// SharedPreferences key. The Android side reads it too (`flutter.app_language`,
  /// AppStrings.kt), so notifications follow the app, not the system.
  static const prefsKey = 'app_language';

  /// What the app starts with: [load] fills it in before runApp so the first
  /// frame is already in the chosen language. Tests pin zh
  /// (test/flutter_test_config.dart).
  static AppLanguage initial = AppLanguage.system;

  /// Reads the stored choice into [initial].
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      initial = AppLanguage.parse(prefs.getString(prefsKey));
    } catch (_) {
      // Unreadable prefs: follow the system, not a previous load's choice.
      initial = AppLanguage.system;
    }
    AppLocale.use(_resolveAppLanguage(initial));
  }

  @override
  AppLanguage build() => initial;

  Future<void> set(AppLanguage language) async {
    if (language == state) return;
    AppLocale.use(_resolveAppLanguage(language));
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, language.name);
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageController, AppLanguage>(AppLanguageController.new);

/// Reactive language for content, requests, and caches as well as widget text.
/// DshApp invalidates this when the operating system's language list changes.
final effectiveAppLocaleProvider = Provider<Locale>((ref) {
  final choice = ref.watch(appLanguageProvider);
  return _resolveAppLanguage(choice);
});
