import Foundation

/// Native text in the language the app shows (Settings → Language), not the
/// system's. `flutter.app_language` is lib/state/locale_state.dart's choice
/// (`system` / `zh` / `en`).
///
/// Resolution matches Dart's `AppLocale.resolve`: an explicit `zh` or `en`
/// wins; otherwise the first preferred language that is Chinese or English
/// wins; anything else, including an empty list, is English.
enum AppLanguage {
  static let defaultsKey = "flutter.app_language"

  static func resolved(
    defaults: UserDefaults = .standard,
    preferredLanguages: [String] = Locale.preferredLanguages
  ) -> String {
    if let choice = defaults.string(forKey: defaultsKey), choice == "zh" || choice == "en" {
      return choice
    }
    for identifier in preferredLanguages {
      let tag = identifier.lowercased()
      let language = tag.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
      if language == "zh" { return "zh" }
      if language == "en" { return "en" }
    }
    return "en"
  }

  static var isEnglish: Bool { resolved() == "en" }

  /// The native string for the app language.
  static func words(_ english: String, _ chinese: String) -> String {
    isEnglish ? english : chinese
  }
}
