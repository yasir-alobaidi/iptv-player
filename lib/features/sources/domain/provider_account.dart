import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_account.freezed.dart';

/// What an Xtream panel says about the account it signed in: the result
/// card after "Test connection", the sync screen's Account line and
/// Settings → Sources. Holds no credentials.
@freezed
abstract class ProviderAccount with _$ProviderAccount {
  const factory({
    /// `Active`, `Expired`, `Banned`, `Disabled`, as the panel words it.
    String? status,

    /// Null means the account doesn't expire.
    DateTime? expiresAt,
    @Default(false) bool isTrial,
    int? activeConnections,
    int? maxConnections,

    /// The live formats the panel offers, lower case: `ts`, `m3u8`, `rtmp`.
    @Default(<String>[]) List<String> allowedFormats,

    /// The panel's time zone name, e.g. `Europe/London`.
    String? serverTimezone,
  }) = _ProviderAccount;
}
