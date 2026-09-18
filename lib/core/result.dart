import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/logging/redact.dart';
import 'package:meta/meta.dart';

/// Outcome of an operation that can fail. Repositories and services return
/// this instead of throwing across layers.
@immutable
sealed class Result<T> {
  const new();

  const factory ok(T value) = Ok<T>;

  const factory err(AppFailure failure) = Err<T>;

  /// Runs [body] and turns any thrown error into an [Err] with the matching
  /// [AppFailure].
  static Future<Result<R>> guard<R>(FutureOr<R> Function() body) async {
    try {
      return Ok(await body());
    } on Object catch (error) {
      return Err(AppFailure.fromError(error));
    }
  }

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  R fold<R>(R Function(T value) onOk, R Function(AppFailure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok(transform(value)),
    Err<T>(:final failure) => Err(failure),
  };
}

final class Ok<T> extends Result<T> {
  const new(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const new(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'Err($failure)';
}

/// Why an operation failed. The UI picks its human message from the type;
/// a stream reports one as its error, hence [Exception].
/// [detail] is technical text with credentials removed, used only in logs
/// and behind a "Details" disclosure.
sealed class AppFailure implements Exception {
  new([String? detail]) : detail = detail == null ? null : redact(detail);

  /// Maps an error thrown by Dart or dart:io to a failure type.
  factory fromError(Object error) {
    final text = error.toString();
    return switch (error) {
      TimeoutException() => TimeoutFailure(text),
      SocketException() ||
      HttpException() ||
      TlsException() => NetworkFailure(text),
      FileSystemException() => StorageFailure(text),
      FormatException() => ParseFailure(text),
      _ => UnexpectedFailure(text),
    };
  }

  final String? detail;

  /// Stable name for logs and diagnostics.
  String get code;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}

/// The server couldn't be reached or the connection broke.
final class NetworkFailure extends AppFailure {
  new([super.detail, this.statusCode]);

  final int? statusCode;

  @override
  String get code => 'network';
}

/// Credentials were rejected or the account can't be used.
final class AuthFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'auth';
}

final class NotFoundFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'not_found';
}

/// Data couldn't be understood.
final class ParseFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'parse';
}

/// Reading or writing local files or the database failed.
final class StorageFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'storage';
}

/// The system keyring (libsecret, Windows Credential Manager) is missing,
/// locked, or refused access. Passwords are never saved anywhere else, so
/// the user has to unlock or install it.
final class SecureStorageFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'secure_storage';
}

/// The caller passed something the operation refuses, such as a source
/// draft without a server. Forms validate inline first; this is the
/// backstop, so its detail names the field, never the value.
final class InvalidInputFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'invalid_input';
}

final class TimeoutFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'timeout';
}

final class CancelledFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'cancelled';
}

final class UnexpectedFailure extends AppFailure {
  new([super.detail]);

  @override
  String get code => 'unexpected';
}
