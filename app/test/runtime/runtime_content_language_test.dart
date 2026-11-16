import 'dart:convert';

import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/runtime/authorized_workspaces.dart';
import 'package:dsh_app/runtime/authorized_workspaces_channel.dart';
import 'package:dsh_app/runtime/ohos_linux_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _han = RegExp(r'[\u3400-\u9fff]');

String _linuxWire() => jsonEncode({
  'v': 1,
  'workspaceLease': false,
  'instanceId': 'instance-1',
  'nativeMemoryRelease': 'process-exit',
  'state': 'enabled',
  'enabled': true,
  'guestOpened': true,
  'admission': true,
  'ownerRetained': false,
  'restartRequired': false,
  'shutdownComplete': false,
  'nextRequestId': 1,
});

Future<AuthorizedWorkspaceFailure> _listFailure() async {
  try {
    await MethodAuthorizedWorkspaces().list();
  } on AuthorizedWorkspaceFailure catch (error) {
    return error;
  }
  fail('listing was expected to fail');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  test('the Linux memory notice follows the app language', () {
    final status = OhosLinuxSnapshot.fromWire(_linuxWire());
    expect(status.nativeMemoryNotice, contains('Linux 原生内存仍保留'));
    AppLocale.use(AppLocale.en);
    expect(status.nativeMemoryNotice, contains('Linux native memory is still held'));
    expect(status.nativeMemoryNotice, isNot(matches(_han)));
  });

  test('a platform failure without a message gets the language\'s fallback', () async {
    final channel = const MethodChannel('dsh/authorized-workspaces');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'denied'),
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    expect((await _listFailure()).message, '目录授权操作未完成。');

    AppLocale.use(AppLocale.en);
    final failure = await _listFailure();
    expect(failure.message, 'The directory authorization operation did not finish.');
    expect(failure.message, isNot(matches(_han)));
  });

  test('an absent channel is reported in the app language', () async {
    expect((await _listFailure()).message, '当前平台没有鸿蒙目录授权通道。');

    AppLocale.use(AppLocale.en);
    final failure = await _listFailure();
    expect(failure.code, 'unsupported');
    expect(failure.message, 'This platform has no HarmonyOS directory authorization channel.');
  });
}
