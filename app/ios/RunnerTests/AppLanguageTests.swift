import XCTest

/// The same rule as Dart's AppLocale.resolve, shared by native prompts and
/// overlays so native text never follows the system when the app chose a language.
final class AppLanguageTests: XCTestCase {
  private var suite = ""
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    suite = "AppLanguageTests." + UUID().uuidString
    defaults = UserDefaults(suiteName: suite)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suite)
    super.tearDown()
  }

  func testExplicitChoiceWinsOverSystemLanguages() {
    defaults.set("en", forKey: AppLanguage.defaultsKey)
    XCTAssertEqual(AppLanguage.resolved(defaults: defaults, preferredLanguages: ["zh-Hans", "en-US"]), "en")
    defaults.set("zh", forKey: AppLanguage.defaultsKey)
    XCTAssertEqual(AppLanguage.resolved(defaults: defaults, preferredLanguages: ["en-US", "zh-Hans"]), "zh")
  }

  func testSystemChoiceUsesFirstChineseOrEnglishLanguage() {
    defaults.removeObject(forKey: AppLanguage.defaultsKey)
    XCTAssertEqual(AppLanguage.resolved(defaults: defaults, preferredLanguages: ["zh-Hans", "en-US"]), "zh")
    XCTAssertEqual(AppLanguage.resolved(defaults: defaults, preferredLanguages: ["en-US", "zh-Hans"]), "en")
    XCTAssertEqual(AppLanguage.resolved(defaults: defaults, preferredLanguages: ["ja-JP", "zh-Hant-TW"]), "zh")
    XCTAssertEqual(AppLanguage.resolved(defaults: defaults, preferredLanguages: ["ja-JP", "en-GB"]), "en")
  }

  func testUnsupportedOrEmptySystemLanguagesFallBackToEnglish() {
    defaults.removeObject(forKey: AppLanguage.defaultsKey)
    XCTAssertEqual(AppLanguage.resolved(defaults: defaults, preferredLanguages: []), "en")
    XCTAssertEqual(AppLanguage.resolved(defaults: defaults, preferredLanguages: ["ja-JP", "fr-FR"]), "en")
  }
}
