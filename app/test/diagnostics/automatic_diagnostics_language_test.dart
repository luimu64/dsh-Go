import 'dart:convert';

import 'package:dsh_app/diagnostics/automatic_diagnostics.dart';
import 'package:dsh_app/diagnostics/diagnostics_bundle.dart';
import 'package:dsh_app/diagnostics/diagnostics_channel.dart';
import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/runtime/runtime_bridge.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

final _han = RegExp(r'[\u3400-\u9fff]');

DiagnosticsSnapshot _sample() => DiagnosticsSnapshot(
  at: DateTime(2026, 11, 14),
  status: const RuntimeStatus(phase: RuntimePhase.running),
  settings: const AppSettings(),
  native: NativeDiagnostics(
    app: {'versionName': '1'},
    evidence: {
      'appErrors': [
        {'at': 100, 'source': 'flutter', 'errorType': 'StateError'},
      ],
      'voiceStages': <Object?>[],
      'processExits': <Object?>[],
    },
  ),
);

Future<String> _prompt() async {
  final sent = <String>[];
  final store = <String, Object?>{};
  final automatic = AutomaticDiagnostics(
    collect: () async => _sample(),
    load: () async => store,
    store: (value) async => store
      ..clear()
      ..addAll(jsonDecode(jsonEncode(value)) as Map<String, Object?>),
  )..configure(Object(), (prompt, current, created) async {
      sent.add(prompt);
      await created('report', () async {});
    });
  await automatic.check();
  expect(automatic.phase, AutomaticDiagnosticsPhase.complete);
  automatic.dispose();
  return sent.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  test('the analysis instruction is Chinese by default', () async {
    final prompt = await _prompt();
    expect(prompt, startsWith('请仅根据以下结构化 dsh-Go 故障事实进行分析'));
    expect(prompt, contains('未授权进一步采集'));
  });

  test('an English app sends the English instruction, not the Chinese one appended', () async {
    AppLocale.use(AppLocale.en);
    final prompt = await _prompt();
    expect(prompt, startsWith('Analyse only the structured dsh-Go failure facts below'));
    expect(prompt, contains('no further collection is authorized'));
    expect(prompt, isNot(matches(_han)));
  });
}
