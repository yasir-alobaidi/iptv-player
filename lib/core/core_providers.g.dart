// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appLog)
final appLogProvider = AppLogProvider._();

final class AppLogProvider extends $FunctionalProvider<AppLog, AppLog, AppLog>
    with $Provider<AppLog> {
  AppLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLogHash();

  @$internal
  @override
  $ProviderElement<AppLog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLog create(Ref ref) {
    return appLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLog>(value),
    );
  }
}

String _$appLogHash() => r'3d70e45f6dc4c298bb817a1622579dbca37888cc';

@ProviderFor(secretRegistry)
final secretRegistryProvider = SecretRegistryProvider._();

final class SecretRegistryProvider
    extends $FunctionalProvider<SecretRegistry, SecretRegistry, SecretRegistry>
    with $Provider<SecretRegistry> {
  SecretRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secretRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secretRegistryHash();

  @$internal
  @override
  $ProviderElement<SecretRegistry> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecretRegistry create(Ref ref) {
    return secretRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecretRegistry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecretRegistry>(value),
    );
  }
}

String _$secretRegistryHash() => r'09f1bb59a9275f53d06c0c57a4803a845347b3cb';

@ProviderFor(errorReporter)
final errorReporterProvider = ErrorReporterProvider._();

final class ErrorReporterProvider
    extends $FunctionalProvider<ErrorReporter, ErrorReporter, ErrorReporter>
    with $Provider<ErrorReporter> {
  ErrorReporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'errorReporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$errorReporterHash();

  @$internal
  @override
  $ProviderElement<ErrorReporter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ErrorReporter create(Ref ref) {
    return errorReporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ErrorReporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ErrorReporter>(value),
    );
  }
}

String _$errorReporterHash() => r'c7d27ec2845820d96d058060f5b96b2013f77188';

/// The system keyring in the app; `InMemoryCredentialStore` in tests.

@ProviderFor(credentialStore)
final credentialStoreProvider = CredentialStoreProvider._();

/// The system keyring in the app; `InMemoryCredentialStore` in tests.

final class CredentialStoreProvider
    extends
        $FunctionalProvider<CredentialStore, CredentialStore, CredentialStore>
    with $Provider<CredentialStore> {
  /// The system keyring in the app; `InMemoryCredentialStore` in tests.
  CredentialStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'credentialStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$credentialStoreHash();

  @$internal
  @override
  $ProviderElement<CredentialStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CredentialStore create(Ref ref) {
    return credentialStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CredentialStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CredentialStore>(value),
    );
  }
}

String _$credentialStoreHash() => r'c1953b4cac3a02c91d396a60c794746b72d8e11d';

@ProviderFor(formFactor)
final formFactorProvider = FormFactorProvider._();

final class FormFactorProvider
    extends $FunctionalProvider<FormFactor, FormFactor, FormFactor>
    with $Provider<FormFactor> {
  FormFactorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formFactorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formFactorHash();

  @$internal
  @override
  $ProviderElement<FormFactor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FormFactor create(Ref ref) {
    return formFactor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FormFactor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FormFactor>(value),
    );
  }
}

String _$formFactorHash() => r'5d9b1ac5d1b8c35a7984207d800825857f3c0bd5';
