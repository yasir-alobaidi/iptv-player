// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_policy.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Read when the policy is opened; let go when it closes.

@ProviderFor(privacyPolicy)
final privacyPolicyProvider = PrivacyPolicyProvider._();

/// Read when the policy is opened; let go when it closes.

final class PrivacyPolicyProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PolicyBlock>>,
          List<PolicyBlock>,
          FutureOr<List<PolicyBlock>>
        >
    with
        $FutureModifier<List<PolicyBlock>>,
        $FutureProvider<List<PolicyBlock>> {
  /// Read when the policy is opened; let go when it closes.
  PrivacyPolicyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacyPolicyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacyPolicyHash();

  @$internal
  @override
  $FutureProviderElement<List<PolicyBlock>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PolicyBlock>> create(Ref ref) {
    return privacyPolicy(ref);
  }
}

String _$privacyPolicyHash() => r'0e08077a909f28fd9c4616bb3130fcb3b8a66af5';
