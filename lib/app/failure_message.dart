import 'package:iptv_player/core/result.dart';

/// The human first line for a failure (docs/05: "human message, never raw
/// exception text" — hard rule 4). [AppFailure.detail] stays behind a
/// Details disclosure; it is redacted but still technical.
String failureMessage(AppFailure failure) => switch (failure) {
  NetworkFailure() =>
    "Can't reach the server. Check your internet "
        'connection.',
  AuthFailure() =>
    'Your provider rejected these details. Check the username '
        'and password.',
  NotFoundFailure() => "That isn't available from your provider any more.",
  ParseFailure() => "The provider sent something we couldn't read.",
  StorageFailure() =>
    "Couldn't read or write on this computer. Check disk "
        'space and permissions.',
  SecureStorageFailure() =>
    "Couldn't use this computer's password keyring. Unlock it, "
        'or check that one is installed, and try again.',
  InvalidInputFailure() => 'Some of these details are missing or invalid.',
  TimeoutFailure() => 'The server took too long to answer.',
  CancelledFailure() => 'Cancelled.',
  UnexpectedFailure() => 'Something went wrong. The details are in the log.',
};
