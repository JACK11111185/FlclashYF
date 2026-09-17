import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS service refreshes the actual tunnel route before Core init completes',
    () {
      final channel = File(
        'ios/Runner/ServiceChannel.swift',
      ).readAsStringSync();
      final router = File(
        'ios/Runner/Core/CoreMessageRouter.swift',
      ).readAsStringSync();
      expect(channel, contains('await coreMessageRouter.refreshTunnelState()'));
      expect(router, contains('func refreshTunnelState() async'));
      expect(
        router,
        contains('let active = await tunnelController.isCoreActive()'),
      );
    },
  );

  test(
    'iOS setup reads groups when an unchanged profile skips config push',
    () {
      final source = File(
        'lib/providers/actions/setup.dart',
      ).readAsStringSync();
      final skipStart = source.indexOf(
        'if (!profileFailed && yamlMd5 == globalState.lastConfigMd5 && !force)',
      );
      expect(skipStart, greaterThan(-1));
      final skipEnd = source.indexOf(
        'return _SetupTaskResult.completed;',
        skipStart,
      );
      expect(skipEnd, greaterThan(skipStart));
      final skipBody = source.substring(skipStart, skipEnd);
      expect(skipBody, contains('await preloadInvoke?.call()'));
      expect(skipBody, contains('await onUpdated?.call()'));
    },
  );
}
