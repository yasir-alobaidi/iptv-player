import 'package:iptv_player/core/result.dart';

/// The human first line for a failure (docs/05: "human message, never raw
/// exception text" — hard rule 4). [AppFailure.detail] stays behind a
/// Details disclosure; it is redacted but still technical.
String failureMessage(AppFailure failure) => switch (failure) {
  // Reached, but it answered with an error status (serverAnswer says which).
  NetworkFailure(statusCode: _?) =>
    'The server answered with an error. Try again in a while; if it keeps '
        'happening, ask your provider.',
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

/// What the server actually answered, in words, when it answered with an
/// HTTP status: shown beside [failureMessage] wherever an error is, so the
/// user sees the server's answer and not only our reading of it. Null
/// when there was no answer (a refused connection, a timeout) or no
/// status.
String? serverAnswer(AppFailure failure) {
  final status = failure.statusCode;
  if (status == null) return null;
  // An empty 404 is how some panels refuse a sign-in (docs/02); say both
  // what came back and why we read it that way.
  if (failure is AuthFailure && status == 404) {
    return 'The server answered HTTP 404 with an empty page, which is how '
        'some panels refuse a wrong username or password.';
  }
  final reason = switch (_reasons[status]) {
    null => '',
    final text => ' ($text)',
  };
  return 'The server answered HTTP $status$reason.';
}

/// [failureMessage] and, when there is one, [serverAnswer].
String failureWithAnswer(AppFailure failure) => switch (serverAnswer(failure)) {
  null => failureMessage(failure),
  final answer => '${failureMessage(failure)} $answer',
};

const _reasons = {
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  408: 'Request Timeout',
  410: 'Gone',
  429: 'Too Many Requests',
  500: 'Internal Server Error',
  502: 'Bad Gateway',
  503: 'Service Unavailable',
  504: 'Gateway Timeout',
};
