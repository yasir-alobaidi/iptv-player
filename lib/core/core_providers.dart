import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'core_providers.g.dart';

// Created before runApp and passed in through ProviderScope overrides
// (lib/app/bootstrap.dart), so logging works before the first frame.

@Riverpod(keepAlive: true)
AppLog appLog(Ref ref) =>
    throw UnimplementedError('appLogProvider is overridden in bootstrap()');

@Riverpod(keepAlive: true)
SecretRegistry secretRegistry(Ref ref) => throw UnimplementedError(
  'secretRegistryProvider is overridden in bootstrap()',
);

@Riverpod(keepAlive: true)
ErrorReporter errorReporter(Ref ref) => throw UnimplementedError(
  'errorReporterProvider is overridden in bootstrap()',
);

@Riverpod(keepAlive: true)
FormFactor formFactor(Ref ref) =>
    detectFormFactor(platform: defaultTargetPlatform);
