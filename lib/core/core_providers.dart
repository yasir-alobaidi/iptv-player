import 'package:flutter/services.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/launch_mark.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
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

/// When the launch became usable; `bootstrap()` gives the real one.
@Riverpod(keepAlive: true)
LaunchMark launchMark(Ref ref) => LaunchMark.none();

/// The system keyring in the app; `InMemoryCredentialStore` in tests.
@Riverpod(keepAlive: true)
CredentialStore credentialStore(Ref ref) => throw UnimplementedError(
  'credentialStoreProvider is overridden in bootstrap()',
);

/// `bootstrap()` sets it from the platform ([detectFormFactor]). Unset,
/// it is the desktop: a widget test's platform is Android, which would
/// otherwise make every test a TV's; a test of the TV asks for it.
@Riverpod(keepAlive: true)
FormFactor formFactor(Ref ref) => FormFactor.desktop;

/// Whether this app sends to TVs: not on a TV, which is the player itself
/// (docs/07). Every Cast control asks this; on a TV none is drawn.
@Riverpod(keepAlive: true)
bool castsToTvs(Ref ref) => ref.watch(formFactorProvider) == FormFactor.desktop;

/// The wall clock, for "synced 12 min ago" and expiry countdowns. Tests
/// pin it.
@Riverpod(keepAlive: true)
DateTime Function() appClock(Ref ref) => DateTime.now;

/// Background news for the shell's toast area.
@Riverpod(keepAlive: true)
AppNotices appNotices(Ref ref) {
  final notices = AppNotices();
  ref.onDispose(notices.dispose);
  return notices;
}

/// The version this build was made as, read once from the bundle.
@Riverpod(keepAlive: true)
Future<AppVersion> appVersion(Ref ref) => readAppVersion(rootBundle);
