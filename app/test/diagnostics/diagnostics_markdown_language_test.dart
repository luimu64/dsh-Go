import 'package:dsh_app/diagnostics/diagnostics_bundle.dart';
import 'package:dsh_app/diagnostics/diagnostics_channel.dart';
import 'package:dsh_app/diagnostics/diagnostics_markdown.dart';
import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/runtime/runtime_bridge.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

DiagnosticsSnapshot _snapshot({List<String> engineLog = const []}) => DiagnosticsSnapshot(
  at: DateTime(2026, 10, 31, 18, 2, 3),
  status: const RuntimeStatus(
    phase: RuntimePhase.running,
    abi: 'arm64-v8a',
    bundledVersion: 'r11-dsh0.2.1-rc.4-node24.22.1',
    installedVersion: 'r11-dsh0.2.1-rc.4-node24.22.1',
    dshVersion: '0.2.1-rc.4',
    nodeVersion: '24.22.1',
    baseUrl: 'http://127.0.0.1:4512',
    token: 'launch-token-secret-value',
    currentExecutionMode: 'proot',
  ),
  settings: const AppSettings(apiKey: 'sk-test', themeMode: ThemeMode.dark, phoneStorage: true),
  native: NativeDiagnostics(
    app: {'versionName': '1.0.6', 'versionCode': 10311700},
    device: {'manufacturer': 'vivo', 'brand': 'vivo', 'model': 'V2405A', 'android': '16', 'sdkInt': 36, 'memoryMb': 12288, 'freeStorageMb': 4096},
    manifest: {'runtimeVersion': 'r11', 'dshVersion': '0.2.1-rc.4', 'nodeVersion': '24.22.1'},
    evidence: {
      'appErrors': [
        {'at': 1, 'source': 'flutter', 'errorType': 'StateError'},
      ],
      'voiceStages': <Object?>[],
      'processExits': <Object?>[],
    },
  ),
  engineLog: engineLog,
);

final _han = RegExp(r'[\u3400-\u9fff]');

void main() {
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  test('the report stays Chinese by default', () {
    final text = diagnosticsMarkdown(_snapshot());
    expect(text, contains('# DSH Go 本机诊断'));
    expect(text, contains('## 环境'));
    expect(text, contains('设备资源：内存 12288 MB · 剩余存储 4096 MB'));
    expect(text, contains('API Key：已设置'));
    expect(text, contains('## 连接'));
    expect(text, contains('## 性能'));
    expect(text, isNot(contains('launch-token-secret-value')));
  });

  test('an English app gets an English report, with no Chinese left', () {
    AppLocale.use(AppLocale.en);
    final text = diagnosticsMarkdown(_snapshot());
    expect(text, contains('# DSH Go diagnostics'));
    expect(text, contains('## Environment'));
    expect(text, contains('- Device resources: Memory 12288 MB · Free storage 4096 MB'));
    expect(text, contains('API Key: set'));
    expect(text, contains('## Settings'));
    expect(text, contains('## Connection'));
    expect(text, contains('## Performance'));
    expect(text, contains('## App failure evidence (kept across restarts)'));
    expect(text, isNot(matches(_han)));
    expect(text, isNot(contains('launch-token-secret-value')));
  });

  test('the truncation notice follows the language too', () {
    AppLocale.use(AppLocale.en);
    final many = [for (var i = 0; i < 3000; i++) 'line $i: ${'x' * 40}'];
    final text = diagnosticsMarkdown(_snapshot(engineLog: many), maxBytes: 4096);
    expect(text, contains('truncated'));
    expect(text, isNot(matches(_han)));
  });

  test('English settings and phone lines read as English', () {
    AppLocale.use(AppLocale.en);
    final text = diagnosticsMarkdown(_snapshot());
    expect(text, contains('- Auto-start local engine'));
    expect(text, contains('· phone storage'));
    expect(text, contains('## Phone control (this device)'));
  });
}
