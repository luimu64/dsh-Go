// The language her prompts, bundled words and prompt-adjacent notes are in.
// Chinese stays the default (and the stored language of user-authored text);
// English is selected only while the app itself is showing English.

import '../l10n/l10n.dart';

/// `zh` or `en`, from the language the app is showing.
String get companionLanguage => AppLocale.isEnglish ? 'en' : 'zh';

/// Whether her prompts are in English right now.
bool get companionEnglish => companionLanguage == 'en';

/// [zh] while the app is Chinese, [en] while it is English.
String companionPick(String zh, String en) => companionEnglish ? en : zh;

/// Normalises an explicit language snapshot taken at a request boundary.
String companionLanguageOf(String? language) => language == 'en' ? 'en' : 'zh';

/// Whether [language] asks for English. A null language means "whatever the
/// app is showing now", which is why pure prompt helpers can be called without
/// threading it through every layer.
bool companionIsEnglish(String? language) => language == null ? companionEnglish : language == 'en';
