import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'authorized_workspaces.dart';

class MethodAuthorizedWorkspaces extends AuthorizedWorkspacesClient {
  MethodAuthorizedWorkspaces() : super(_invoke);
  static const _channel = MethodChannel('dsh/authorized-workspaces');

  static Future<Object?> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      switch (method) {
        case 'capabilities':
          return await _channel.invokeMethod<Object?>(
            'capabilities',
            arguments,
          );
        case 'list':
          return await _channel.invokeMethod<Object?>('list', arguments);
        case 'select':
          return await _channel.invokeMethod<Object?>('select', arguments);
        case 'attach':
          return await _channel.invokeMethod<Object?>('attach', arguments);
        case 'persist':
          return await _channel.invokeMethod<Object?>('persist', arguments);
        case 'activate':
          return await _channel.invokeMethod<Object?>('activate', arguments);
        case 'deactivate':
          return await _channel.invokeMethod<Object?>('deactivate', arguments);
        case 'revoke':
          return await _channel.invokeMethod<Object?>('revoke', arguments);
        case 'forget':
          return await _channel.invokeMethod<Object?>('forget', arguments);
        case 'cancel':
          return await _channel.invokeMethod<Object?>('cancel', arguments);
        default:
          throw AuthorizedWorkspaceFailure(
            'unsupported_method',
            AppLocale.isEnglish
                ? 'The directory authorization method is not supported.'
                : '目录授权方法不受支持。',  // l10n:keep zh half of the bilingual pair
          );
      }
    } on MissingPluginException {
      throw AuthorizedWorkspaceFailure(
        'unsupported',
        AppLocale.isEnglish
            ? 'This platform has no HarmonyOS directory authorization channel.'
            : '当前平台没有鸿蒙目录授权通道。',  // l10n:keep zh half of the bilingual pair
      );
    } on PlatformException catch (error) {
      throw AuthorizedWorkspaceFailure(
        error.code,
        error.message ??
            (AppLocale.isEnglish
                ? 'The directory authorization operation did not finish.'
                : '目录授权操作未完成。'),  // l10n:keep zh half of the bilingual pair
        details: error.details,
      );
    }
  }

  @override
  Future<AuthorizedWorkspaceCapabilities> capabilities() async {
    try {
      return await super.capabilities();
    } on AuthorizedWorkspaceFailure catch (error) {
      if (error.code != 'unsupported') rethrow;
      return const AuthorizedWorkspaceCapabilities.unavailable();
    }
  }
}
