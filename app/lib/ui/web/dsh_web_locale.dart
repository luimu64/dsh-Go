// A per-WebView language override for the patched DSH locale client.
// Never write the host's shared settings: another browser or phone connected
// to that host may deliberately use a different language.
//
// The global handles injection before plugin activation; the event handles
// injection after activation and live changes. Replaying on page finish avoids
// depending on a document-start race. Older hosts without the patch retain
// their own web language until their runtime is updated.
import 'dart:convert';

import 'package:flutter/widgets.dart';

/// The app language id understood by the patched web locale client.
String dshWebLocaleId(Locale locale) => locale.languageCode.toLowerCase() == 'zh' ? 'zh' : 'en';

/// Updates this page only, without reloads, storage writes or shared-host state.
String dshWebLocaleBridgeScript(Locale locale) {
  final language = jsonEncode(dshWebLocaleId(locale));
  return '''
(() => {
  const language = $language;
  globalThis.__DSH_APP_LOCALE__ = language;
  globalThis.dispatchEvent(new CustomEvent('dsh-go:locale', {detail: language}));
})();
''';
}
