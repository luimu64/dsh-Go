// The language her prompts, bundled words and prompt-adjacent notes are in.
// Chinese stays the default (and the stored language of user-authored text);
// English is selected only while the app itself is showing English.
//
// This file stays dependency-free: engine-side tests import their Dart sources
// directly, without Flutter's localization package. `AppLocale.use`
// (l10n.dart) installs the resolver once; it reads the live UI language, so
// every getter below follows a switch without further wiring.

/// `zh` or `en`; the app installs the real answer from its UI language.
String Function() companionLanguageSource = () => 'zh';

/// `zh` or `en`, from the language the app is showing.
String get companionLanguage => companionLanguageSource() == 'en' ? 'en' : 'zh';

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
