import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

/// What the account says, when a refused stream needs it read.
final class AccountCheck {
  const new({
    required this.signedIn,
    this.status,
    this.activeConnections,
    this.maxConnections,
  });

  /// False when the panel refused the sign-in itself.
  final bool signedIn;
  final String? status;
  final int? activeConnections;
  final int? maxConnections;

  bool get full =>
      activeConnections != null &&
      maxConnections != null &&
      activeConnections! >= maxConnections!;
}

/// docs/03's error classes from what the stream's URL answered: [status]
/// null when nothing answered; [body] the first few hundred bytes;
/// [account] the account read after a refusal (Xtream only); [detail] the
/// player's own text.
PlaybackProblem classifyStreamFailure({
  required int? status,
  String body = '',
  AccountCheck? account,
  String? detail,
}) {
  String answer(int s) => 'stream: HTTP $s';
  final text = body.toLowerCase();
  final limitHint =
      text.contains('max_connections') ||
      text.contains('max connections') ||
      text.contains('connection limit') ||
      text.contains('too many');
  if (status == null) {
    return PlaybackProblem(
      PlaybackProblemKind.network,
      failure: NetworkFailure('stream: no answer'),
      detail: detail,
    );
  }
  if (status >= 200 && status < 300) {
    // It opens now: the player's failure was a moment's, or the codec.
    final decoder =
        detail != null &&
        RegExp(
          'decoder|codec|unsupported|not supported',
          caseSensitive: false,
        ).hasMatch(detail);
    return PlaybackProblem(
      decoder ? PlaybackProblemKind.unsupported : PlaybackProblemKind.network,
      detail: detail,
    );
  }
  if (status == 429) {
    return PlaybackProblem(
      PlaybackProblemKind.connectionLimit,
      failure: NetworkFailure(answer(status), status),
      detail: detail,
    );
  }
  if (status == 401 ||
      status == 403 ||
      (status == 404 && body.trim().isEmpty)) {
    if (account != null && !account.signedIn) {
      return PlaybackProblem(
        PlaybackProblemKind.auth,
        failure: AuthFailure(answer(status), status),
        detail: detail,
      );
    }
    if (limitHint || (account?.full ?? false)) {
      return PlaybackProblem(
        PlaybackProblemKind.connectionLimit,
        failure: NetworkFailure(answer(status), status),
        detail: detail,
      );
    }
    final accountStatus = account?.status?.toLowerCase();
    if (status != 404 || (accountStatus != null && accountStatus != 'active')) {
      return PlaybackProblem(
        PlaybackProblemKind.auth,
        failure: AuthFailure(answer(status), status),
        detail: detail,
      );
    }
  }
  if (status == 404 || status == 410 || (status >= 400 && status < 500)) {
    return PlaybackProblem(
      PlaybackProblemKind.offline,
      failure: NotFoundFailure(answer(status), status),
      detail: detail,
    );
  }
  return PlaybackProblem(
    PlaybackProblemKind.server,
    failure: NetworkFailure(answer(status), status),
    detail: detail,
  );
}

/// [StreamProber] over HTTP: one GET of the stream's URL, its status and
/// the first bytes read, then closed at once. On a refusal from an Xtream
/// panel the account is read too, to tell a full account from a refused
/// one.
final class HttpStreamProber implements StreamProber {
  new(this._sources, {Dio? dio, this.timeout = const Duration(seconds: 8)})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              responseType: ResponseType.stream,
              validateStatus: (_) => true,
            ),
          );

  final SourceRepository _sources;
  final Dio _dio;
  final Duration timeout;

  @override
  Future<PlaybackProblem> diagnose(
    ChannelItem channel,
    ResolvedStream stream, {
    String? detail,
  }) async {
    final (status, body) = await _probe(stream);
    AccountCheck? account;
    final refused =
        status == 401 ||
        status == 403 ||
        (status == 404 && body.trim().isEmpty);
    if (refused) account = await _account(channel.sourceId);
    return classifyStreamFailure(
      status: status,
      body: body,
      account: account,
      detail: detail,
    );
  }

  Future<(int?, String)> _probe(ResolvedStream stream) async {
    final cancel = CancelToken();
    try {
      final response = await _dio
          .getUri<ResponseBody>(
            Uri.parse(stream.url),
            cancelToken: cancel,
            options: Options(
              headers: {
                HttpHeaders.userAgentHeader:
                    stream.userAgent ?? defaultUserAgent,
              },
            ),
          )
          .timeout(timeout);
      final status = response.statusCode;
      final bytes = BytesBuilder(copy: false);
      final source = response.data?.stream;
      if (source != null && (status == null || status >= 300)) {
        // An error page's first bytes can say why ("max connections").
        await for (final chunk in source.timeout(const Duration(seconds: 2))) {
          bytes.add(chunk);
          if (bytes.length >= 512) break;
        }
      }
      return (status, utf8.decode(bytes.takeBytes(), allowMalformed: true));
    } on Object {
      return (null, '');
    } finally {
      // Let go of the connection at once: on a one-connection panel the
      // probe must not hold the slot the next attempt needs.
      cancel.cancel();
    }
  }

  Future<AccountCheck?> _account(String sourceId) async {
    final found = (await _sources.byId(sourceId)).valueOrNull;
    if (found == null || found.type != SourceType.xtream) return null;
    final credentials = (await _sources.credentialsFor(sourceId)).valueOrNull;
    if (credentials == null) return null;
    final client = XtreamClient(
      server: credentials.url,
      username: credentials.username ?? '',
      password: credentials.password ?? '',
      userAgent: found.userAgent,
    );
    final result = await client.account(retry: false);
    return switch (result) {
      Ok(:final value) => AccountCheck(
        signedIn: true,
        status: value.status,
        activeConnections: value.activeConnections,
        maxConnections: value.maxConnections,
      ),
      Err(failure: AuthFailure()) => const AccountCheck(signedIn: false),
      Err() => null,
    };
  }
}
