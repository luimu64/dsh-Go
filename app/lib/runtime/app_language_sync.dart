import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

/// Forwards later Settings → Language choices (and 跟随系统 language changes)
/// to the running on-device engine. The engine rewrites model-facing text in
/// place; it is never restarted and running tool calls keep their identity.
///
/// Binding has to come from app startup because a later change has no other
/// native signal on every platform. Call [start] once, after the Flutter binding
/// and shared preferences are ready (DshApp.initState is already late enough).
/// A stopped engine needs no push: its next start reads the same preference.
abstract final class AppLanguageSync {
  static const _channel = MethodChannel('dsh/runtime');
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    AppLocale.changes.addListener(_push);
  }

  static Future<void> _push() async {
    try {
      await _channel.invokeMethod<void>('setAppLanguage', {'language': AppLocale.isEnglish ? 'en' : 'zh'});
    } on MissingPluginException {
      // Tests and desktop builds have no runtime channel.
    } on PlatformException {
      // The engine may not be running; the next start reads the preference.
    }
  }
}
