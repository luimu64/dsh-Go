// The diagnostics snapshot as one compact Markdown file. The app writes it
// inside the engine's rootfs (`$DSH_HOME/dsh-app/diagnostics.md`) so the
// agent there can read it by itself when the person reports a problem. It is
// also what a person reads in the export, so it follows the app language.

import 'dart:convert';

import '../l10n/l10n.dart';
import '../state/app_info.dart';
import 'diagnostics_bundle.dart';
import 'diagnostics_channel.dart';
import 'redact.dart';

/// Most lines kept from each log tail (the model reads this file, not a zip).
const diagnosticsEngineLines = 80;
const diagnosticsFailureLines = 60;
const diagnosticsErrorLines = 10;
const diagnosticsSystemImeEvents = 12;

/// Hard cap: a diagnostics file that costs more context than this is no
/// longer worth reading. The zip export stays available for everything else.
const diagnosticsMarkdownBytes = 16 * 1024;

/// [zh] or its English [en] equivalent, following the app language.
String _t(String zh, String en) => AppLocale.isEnglish ? en : zh;

/// Renders [s]. Pure: tests build a snapshot and compare, secrets go through
/// [redactDiagnostics] on the way out. The UTF-8 budget includes the notice.
String diagnosticsMarkdown(DiagnosticsSnapshot s, {int maxBytes = diagnosticsMarkdownBytes}) {
  final b = StringBuffer()
    ..writeln(_t('# DSH Go 本机诊断', '# DSH Go diagnostics'))  // l10n:keep zh half of the bilingual pair
    ..writeln()
    ..writeln(
      _t(
        '> App 写在引擎里的环境快照，给排查问题用；已脱敏。生成时间：${_time(s.at)}。',  // l10n:keep zh half of the bilingual pair
        '> An environment snapshot the app writes into the engine for troubleshooting; redacted. '
            'Generated: ${_time(s.at)}.',
      ),
    )
    ..writeln();
  _systemIme(b, s);
  _environment(b, s);
  _evidence(b, s);
  _connection(b, s);
  _phone(b, s);
  _performance(b, s);
  _errors(b, s);
  _log(b, _t('引擎日志（尾部）', 'Engine log (tail)'), s.engineLog, diagnosticsEngineLines);  // l10n:keep zh half of the bilingual pair
  _log(b, _t('失败前后的日志（尾部）', 'Log around the failure (tail)'), s.failureLog, diagnosticsFailureLines);  // l10n:keep zh half of the bilingual pair
  final text = redactDiagnostics(b.toString());
  final bytes = utf8.encode(text);
  if (bytes.length <= maxBytes) return text;
  final notice = _t(
    '\n…（诊断文件过长，已截断；完整内容用 设置 → 诊断 的导出包）\n',  // l10n:keep zh half of the bilingual pair
    '\n... (diagnostics file too long, truncated; use the export bundle in Settings → Diagnostics for '
        'the full content)\n',
  );
  final noticeBytes = utf8.encode(notice);
  final contentBudget = maxBytes - noticeBytes.length;
  if (contentBudget < 0) return _utf8Prefix(noticeBytes, maxBytes);
  return '${_utf8Prefix(bytes, contentBudget)}$notice';
}

String _utf8Prefix(List<int> bytes, int budget) {
  var end = budget;
  // Both callers pass a budget below the encoded length. Back up to the
  // start of a scalar when the cut would keep only some of its bytes.
  while (end > 0 && (bytes[end] & 0xc0) == 0x80) {
    end--;
  }
  return utf8.decode(bytes.sublist(0, end));
}

void _systemIme(StringBuffer b, DiagnosticsSnapshot s) {
  final evidence = s.systemIme;
  if (evidence == null) return;
  final at = DateTime.fromMillisecondsSinceEpoch(evidence.capturedAt, isUtc: true);
  if (evidence.source == 'ohosWindowGeometry') {
    b
      ..writeln(_t('## 本应用键盘几何（手动导出，ohosWindowGeometry）', '## Keyboard geometry of this app (manual export, ohosWindowGeometry)'))  // l10n:keep zh half of the bilingual pair
      ..writeln('- capturedAt: ${at.toIso8601String()} · code: ${evidence.code} · events: ${evidence.events.length}')
      ..writeln(
        _t(
          '- 仅本应用主窗口回调；最近120秒、最多64条；坐标与尺寸单位px。时间戳是回调收到时间，不是系统动作发生时间。',  // l10n:keep zh half of the bilingual pair
          '- Callbacks of this app\'s main window only; last 120 seconds, at most 64; coordinates and '
              'sizes in px. A timestamp is when the callback was received, not when the system acted.',
        ),
      )
      ..writeln(
        _t(
          '- 不含输入内容或系统日志；不能据此推断其他窗口、完整浮动键盘轨迹或系统输入法内部状态。',  // l10n:keep zh half of the bilingual pair
          '- No typed content or system logs; it cannot show other windows, a complete floating '
              'keyboard path, or the input method\'s internal state.',
        ),
      );
    if (evidence.events.isEmpty) {
      b.writeln(_t('- 没有可用记录；空记录或失败不能证明键盘行为正常。', '- No usable records; an empty capture or a failure does not prove the keyboard behaved normally.'));  // l10n:keep zh half of the bilingual pair
    } else {
      final recent = evidence.events.reversed.take(diagnosticsSystemImeEvents).toList().reversed;
      b.writeln(
        _t(
          '- 最近${recent.length}条，ZIP保留完整有界记录；同毫秒条目按回调收到顺序排列：',  // l10n:keep zh half of the bilingual pair
          '- Most recent ${recent.length} events; the ZIP keeps the full bounded capture; entries in '
              'the same millisecond are in callback order:',
        ),
      );
      for (final event in recent) {
        b.writeln('  - ${event.timestamp} ${event.event} geometry=${jsonEncode(event.geometry)}');
      }
    }
    b.writeln();
    return;
  }

  b
    ..writeln('## System IME evidence (manual, privilegedIme)')
    ..writeln('- capturedAt: ${at.toIso8601String()} · code: ${evidence.code} · events: ${evidence.events.length}')
    ..writeln('- Fixed events only; preceding 120 seconds, maximum 64. Retained capture, not live monitoring.')
    ..writeln('- Requests do not prove keyboard visibility. fromUser=null means unknown, not false.');
  if (evidence.events.isEmpty) {
    b.writeln('- No usable events: empty/failed capture is NOT evidence that the system behaved normally.');
  } else {
    final recent = evidence.events.reversed.take(diagnosticsSystemImeEvents).toList().reversed;
    b.writeln('- Most recent ${recent.length} events (ZIP contains the full bounded capture):');
    for (final event in recent) {
      b.writeln(
        '  - ${event.timestamp} ${event.event} fromUser=${event.fromUser} reason=${event.reason} origin=${event.origin}',
      );
    }
  }
  b.writeln();
}

void _environment(StringBuffer b, DiagnosticsSnapshot s) {
  final st = s.status;
  final app = s.native.app;
  final device = s.native.device;
  final manifest = s.native.manifest;
  b
    ..writeln(_t('## 环境', '## Environment'))  // l10n:keep zh half of the bilingual pair
    ..writeln('- ${_t('App', 'App')}${_t('：', ': ')}${_join([AppInfo.version, app['versionName'], app['versionCode']?.toString()])}')
    ..writeln(
      '- ${_t('设备', 'Device')}${_t('：', ': ')}${_join([device['manufacturer'], device['brand'], device['model'], _android(device)], mono: true)}',  // l10n:keep zh half of the bilingual pair
    )
    ..writeln(
      '- ${_t('设备资源', 'Device resources')}${_t('：', ': ')}'  // l10n:keep zh half of the bilingual pair
      '${_join([_mb(device['memoryMb'], _t('内存', 'Memory')), _mb(device['freeStorageMb'], _t('剩余存储', 'Free storage'))])}',  // l10n:keep zh half of the bilingual pair
    )
    ..writeln('- ABI${_t('：', ': ')}${st.abi ?? '—'}');
  final display = device['display'];
  if (display is Map) {
    final d = {for (final e in display.entries) '${e.key}': e.value};
    b.writeln(
      '- ${_t('显示', 'Display')}${_t('：', ': ')}${_join([if (d['widthPx'] != null && d['heightPx'] != null) '${d['widthPx']}×${d['heightPx']}', if (d['densityDpi'] != null) '${d['densityDpi']}dpi', if (d['density'] != null) '${d['density']}×', if (d['fontScale'] != null) '${_t('字号', 'Font scale')} ${d['fontScale']}'])}',  // l10n:keep zh half of the bilingual pair
    );
  }
  if (manifest.isNotEmpty) {
    b.writeln(
      '- ${_t('内置运行时', 'Bundled runtime')}${_t('：', ': ')}${_join([manifest['runtimeVersion'], manifest['dshVersion'], manifest['nodeVersion']], mono: true)}',  // l10n:keep zh half of the bilingual pair
    );
  }
  b
    ..writeln(
      '- ${_t('运行时状态', 'Runtime state')}${_t('：', ': ')}${st.phase.name} · ${_t('模式', 'mode')} ${st.mode.name}'  // l10n:keep zh half of the bilingual pair
      '${st.safeState.name != 'off' ? ' · ${_t('安全模式', 'safe mode')} ${st.safeState.name}${st.safeReason == null ? '' : _t('（${st.safeReason}）', ' (${st.safeReason})')}' : ''}'  // l10n:keep zh half of the bilingual pair
      '${st.strikes > 0 ? ' · ${_t('连续失败', 'consecutive failures')} ${st.strikes}' : ''}',  // l10n:keep zh half of the bilingual pair
    )
    ..writeln(
      '- ${_t('版本', 'Versions')}${_t('：', ': ')}${_t('内置', 'bundled')} ${_short(st.bundledVersion)} · ${_t('已装', 'installed')} ${_short(st.installedVersion)} · DSH ${st.dshVersion ?? '—'} · Node ${st.nodeVersion ?? '—'}',  // l10n:keep zh half of the bilingual pair
    )
    ..writeln(
      '- ${_t('启动方式', 'Launch mode')}${_t('：', ': ')}${st.currentExecutionMode ?? st.launchSelectedMode ?? (st.directEngineEnabled ? _t('direct（未观测）', 'direct (unobserved)') : 'proot')}'  // l10n:keep zh half of the bilingual pair
      '${st.launchFailureReason == null ? '' : ' · ${_t('最近失败', 'last failure')} ${st.launchFailureReason}'}'  // l10n:keep zh half of the bilingual pair
      '${st.directEngineFallbackReason == null ? '' : ' · ${_t('回退', 'fallback')} ${st.directEngineFallbackReason}'}',  // l10n:keep zh half of the bilingual pair
    )
    ..writeln('- ${_t('引擎地址', 'Engine address')}${_t('：', ': ')}${st.baseUrl ?? '—'}${_t('（token 不回传）', ' (token not included)')}');  // l10n:keep zh half of the bilingual pair
  if (st.error case final error? when error.isNotEmpty) {
    b.writeln('- ${_t('最近错误', 'Last error')}${_t('：', ': ')}$error');  // l10n:keep zh half of the bilingual pair
  }
  if (st.networkBlocked) {
    b.writeln('- ${_t('系统限制联网', 'Network blocked by the system')}${_t('：${_time(st.networkBlockedAt ?? s.at)} 起', ' from ${_time(st.networkBlockedAt ?? s.at)}')}');  // l10n:keep zh half of the bilingual pair
  }
  b
    ..writeln()
    ..writeln(_t('## 设置', '## Settings'))  // l10n:keep zh half of the bilingual pair
    ..writeln(
      '${_t('- API Key：', '- API Key: ')}${s.settings.hasApiKey ? _t('已设置', 'set') : _t('未设置', 'not set')} · ${_t('自定义服务商', 'custom providers')} ${s.settings.customProviderIds.length}'  // l10n:keep zh half of the bilingual pair
      ' · ${_t('主题', 'theme')} ${s.settings.themeMode.name} · ${_t('对话字号', 'chat text size')} ${s.settings.chatTextScale}',  // l10n:keep zh half of the bilingual pair
    )
    ..writeln(
      '- ${_t('自动起本机引擎', 'Auto-start local engine')} ${s.settings.autoStartLocal} · ${_t('自动批准命令', 'auto-approve commands')} ${s.settings.autoApproveCommands}'  // l10n:keep zh half of the bilingual pair
      ' · ${_t('手机存储', 'phone storage')} ${s.settings.phoneStorage} · ${_t('完成后收起过程', 'collapse finished turns')} ${s.settings.foldCompletedTurns}'  // l10n:keep zh half of the bilingual pair
      ' · ${_t('可视化回复', 'visual replies')} ${s.settings.visualReplies}',  // l10n:keep zh half of the bilingual pair
    )
    ..writeln();
}

void _connection(StringBuffer b, DiagnosticsSnapshot s) {
  b.writeln(_t('## 连接', '## Connection'));  // l10n:keep zh half of the bilingual pair
  final entries = s.connection.entries
      .where((e) => e.key != 'history' && e.value != null && '${e.value}'.isNotEmpty)
      .toList();
  if (entries.isEmpty) {
    b.writeln(_t('- 没有正在观察的连接', '- No connection being observed'));  // l10n:keep zh half of the bilingual pair
  } else {
    for (final e in entries) {
      b.writeln('- ${e.key}${_t('：', ': ')}${e.value}');
    }
  }
  final history = s.connection['history'];
  if (history is Map && history['events'] is List) {
    b.writeln(
      _t(
        '- 已观察的连接历史（已丢弃 ${history['dropped']} 条；不代表观察间隙的完整时序）：',  // l10n:keep zh half of the bilingual pair
        '- Observed connection history (${history['dropped']} dropped; not a complete order across '
            'observation gaps):',
      ),
    );
    for (final event in (history['events'] as List).whereType<Map>()) {
      final fields = [
        '#${event['sequence']}',
        'at=${event['observedAtEpochMs']}',
        '+${event['elapsedMs']}ms',
        '${event['phase']}',
        if (event['step'] != null) '${event['step']}',
        'attempt=${event['attempt']}',
        if (event['transport'] != null) 'transport=${event['transport']}',
        if (event['fallbackReason'] != null) 'fallback=${event['fallbackReason']}',
        if (event['errorKind'] != null) 'error=${event['errorKind']}',
        if (event['retryable'] != null) 'retryable=${event['retryable']}',
        if (event['reasonCode'] != null) 'reason=${event['reasonCode']}',
      ];
      b.writeln('- ${fields.join(' · ')}');
    }
  }
  b.writeln();
}

void _phone(StringBuffer b, DiagnosticsSnapshot s) {
  b.writeln(_t('## 手机操控（本机）', '## Phone control (this device)'));  // l10n:keep zh half of the bilingual pair
  final phone = s.phone;
  if (!phone.ready) {
    b.writeln(_t('- 手机状态不可用', '- Phone status unavailable'));  // l10n:keep zh half of the bilingual pair
  } else {
    b
      ..writeln('- ${_t('手机操控开关', 'Phone control')}${_t('：', ': ')}${phone.enabled} · ${_t('桥接监听', 'bridge listening')}${_t('：', ': ')}${phone.bridgeListening}')  // l10n:keep zh half of the bilingual pair
      ..writeln('- ${_t('无障碍开关', 'Accessibility')}${_t('：', ': ')}${phone.a11y.enabled} · ${_t('服务已连接', 'service connected')}${_t('：', ': ')}${phone.a11y.serviceConnected}');  // l10n:keep zh half of the bilingual pair
  }
  b.writeln();
}

void _performance(StringBuffer b, DiagnosticsSnapshot s) {
  b.writeln(_t('## 性能', '## Performance'));  // l10n:keep zh half of the bilingual pair
  final p = s.performance;
  if (p.isEmpty) {
    b.writeln(_t('- 没有采样', '- No samples'));  // l10n:keep zh half of the bilingual pair
  } else {
    for (final e in p.entries) {
      final value = e.value;
      if (value is Map) {
        b.writeln('- ${e.key}${_t('：', ': ')}${value.entries.map((x) => '${x.key}=${x.value}').join(' ')}');
      } else {
        b.writeln('- ${e.key}${_t('：', ': ')}$value');
      }
    }
  }
  b.writeln();
}

void _evidence(StringBuffer b, DiagnosticsSnapshot s) {
  if (s.native.evidence.isEmpty) return;
  final evidence = diagnosticEvidenceFacts(s.native.evidence);
  b.writeln(_t('## App 故障证据（跨重启保留）', '## App failure evidence (kept across restarts)'));  // l10n:keep zh half of the bilingual pair
  b.writeln('- ${_t('可用性', 'Availability')}${_t('：', ': ')}${jsonEncode(evidence['availability'])}');  // l10n:keep zh half of the bilingual pair
  for (final key in ['processExits', 'appErrors', 'voiceStages']) {
    final rows = evidence[key];
    if (rows is! List) continue;
    final tail = rows.reversed.take(key == 'voiceStages' ? 8 : 3).toList().reversed;
    for (final row in tail) {
      b.writeln('- $key${_t('：', ': ')}${jsonEncode(row)}');
    }
  }
  b.writeln(
    _t(
      '- 无记录或系统不提供记录，不代表没有发生故障；退出原因不等于完整崩溃堆栈。',  // l10n:keep zh half of the bilingual pair
      '- No records, or the system not providing them, does not mean nothing failed; an exit reason '
          'is not a full crash stack.',
    ),
  );
  b.writeln();
}

void _errors(StringBuffer b, DiagnosticsSnapshot s) {
  if (s.appErrors.isEmpty) return;
  b.writeln(_t('## 最近错误（App 内捕获）', '## Recent errors (captured in the app)'));  // l10n:keep zh half of the bilingual pair
  for (final e in s.appErrors.reversed.take(diagnosticsErrorLines).toList().reversed) {
    b.writeln('- ${_time(e.at)} · ${e.source.name}${_t('：', ': ')}${_firstLine(e.message)}');
  }
  b.writeln();
}

void _log(StringBuffer b, String title, List<String> lines, int maxLines) {
  if (lines.isEmpty) return;
  final tail = lines.length <= maxLines ? lines : lines.sublist(lines.length - maxLines);
  b
    ..writeln(
      _t(
        '## $title（${lines.length} 行，取最后 ${tail.length} 行）',  // l10n:keep zh half of the bilingual pair
        '## $title (${lines.length} lines, last ${tail.length})',
      ),
    )
    ..writeln('```log')
    ..writeln(tail.join('\n'))
    ..writeln('```')
    ..writeln();
}

String _join(List<Object?> parts, {bool mono = false}) {
  final text = parts.where((p) => p != null && '$p'.trim().isNotEmpty).map((p) => '$p'.trim()).join(' · ');
  return mono && text.isNotEmpty ? '`$text`' : text;
}

String _android(Map<String, Object?> device) {
  final version = device['android'];
  final sdk = device['sdkInt'];
  if (version == null && sdk == null) {
    // HarmonyOS names them itself (OhosDeviceFacts.ets).
    final os = device['osVersion'];
    final api = device['apiVersion'];
    if (os == null && api == null) return '';
    return os == null ? 'API $api' : '$os${api == null ? '' : ' (API $api)'}';
  }
  return version == null ? 'SDK $sdk' : 'Android $version${sdk == null ? '' : ' (SDK $sdk)'}';
}

String _mb(Object? value, String label) {
  if (value is! num) return '';
  return '$label ${value.round()} MB';
}

String _short(String? version) => version == null ? '—' : (version.length > 22 ? version.substring(0, 22) : version);

String _time(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
}

String _firstLine(String text) {
  final line = text.split('\n').first.trim();
  return line.length <= 240 ? line : '${line.substring(0, 240)}…';
}
