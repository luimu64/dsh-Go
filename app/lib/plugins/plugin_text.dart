// The language plugin-provided text is read in.
//
// Manifests, market entries and the bridge keep their titles, labels and
// descriptions as language maps ([LocalizedText]); the app resolves them, so
// the language is the app's own (设置 → 语言), never a default baked into a
// model. Widgets read it from the UI text they draw
// (`context.l10n.localeName`); code without a BuildContext reads
// [pluginTextLocale], and readers that keep resolved text ([SeatInventory])
// watch [pluginTextLocaleProvider] so a language change replaces it instead
// of leaving the old words on screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/locale_state.dart';

/// The app's UI language (`zh` or `en`), for code without a BuildContext.
String get pluginTextLocale => AppLocale.current.languageCode;

/// [pluginTextLocale], reactive. [effectiveAppLocaleProvider] is what the
/// app's root follows and what a system language change invalidates, so
/// watching it rebuilds everything that kept resolved plugin text.
final pluginTextLocaleProvider = Provider<String>((ref) => ref.watch(effectiveAppLocaleProvider).languageCode);
