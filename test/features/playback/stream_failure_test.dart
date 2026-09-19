import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

void main() {
  PlaybackProblemKind kind(
    int? status, {
    String body = '',
    AccountCheck? account,
    String? detail,
  }) => classifyStreamFailure(
    status: status,
    body: body,
    account: account,
    detail: detail,
  ).kind;

  test("docs/03's error classes", () {
    expect(kind(null), PlaybackProblemKind.network);
    expect(kind(200), PlaybackProblemKind.network);
    expect(
      kind(200, detail: 'Failed to initialize a decoder for codec'),
      PlaybackProblemKind.unsupported,
    );
    expect(kind(404, body: 'no live stream'), PlaybackProblemKind.offline);
    expect(kind(429), PlaybackProblemKind.connectionLimit);
    expect(kind(500), PlaybackProblemKind.server);
    expect(kind(503), PlaybackProblemKind.server);
    expect(kind(401), PlaybackProblemKind.auth);
  });

  test('a 403: the body or the account tells a full account from a '
      'refused one', () {
    expect(
      kind(403, body: 'MAX_CONNECTIONS_REACHED'),
      PlaybackProblemKind.connectionLimit,
    );
    expect(
      kind(
        403,
        account: const AccountCheck(
          signedIn: true,
          status: 'Active',
          activeConnections: 1,
          maxConnections: 1,
        ),
      ),
      PlaybackProblemKind.connectionLimit,
    );
    expect(
      kind(
        403,
        account: const AccountCheck(
          signedIn: true,
          status: 'Active',
          activeConnections: 0,
          maxConnections: 1,
        ),
      ),
      PlaybackProblemKind.auth,
    );
    expect(
      kind(403, account: const AccountCheck(signedIn: false)),
      PlaybackProblemKind.auth,
    );
  });

  test('an empty 404: offline, unless the account says it is refused or '
      'full', () {
    const active = AccountCheck(
      signedIn: true,
      status: 'Active',
      activeConnections: 0,
      maxConnections: 1,
    );
    expect(kind(404, account: active), PlaybackProblemKind.offline);
    expect(
      kind(404, account: const AccountCheck(signedIn: false)),
      PlaybackProblemKind.auth,
    );
    expect(
      kind(
        404,
        account: const AccountCheck(
          signedIn: true,
          status: 'Expired',
          activeConnections: 0,
          maxConnections: 1,
        ),
      ),
      PlaybackProblemKind.auth,
    );
  });

  test('the failure carries the status, for "The server answered …"', () {
    final problem = classifyStreamFailure(status: 503);
    expect(problem.failure?.statusCode, 503);
  });
}
