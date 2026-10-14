// Phase 9 step 6's last item, by hand: one real reminder on the user's own
// desktop, twice — a click on the notification's text, then its Watch
// button — to see what the code can't be tested for: whether the desktop
// shows the notification, and whether the click brings the window forward
// (GNOME on Wayland refuses a window that raises itself without the token
// the click hands out).
//
// Not a CI test (its name doesn't end in `_test.dart`). On the real
// display, with the user at it and told what to do:
//
//     flutter test integration_test/manual/real_reminder.dart -d linux
//
// The app opens on the fake panel (nothing of a real provider, no TV). It
// waits until its window is covered (the user clicks another one), then
// sets its clock so that a programme with a reminder starts 15 s later;
// after the answer it waits to be covered again for a second one. A
// reminder that comes due while the window is in front is a toast, by
// design, so the countdown must not start before the window is covered
// (a first version counted from the launch, and both came as toasts).
// What the desktop sent back, whether the window was in front afterwards
// and whether the channel played go to the console and to
// build/real_reminder/session.log.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/window_setup.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/data/platform/system_notifiers.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_actions.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_watch.dart';
import 'package:logger/logger.dart';

import '../support/fake_panel.dart';
import '../support/panel_app.dart';

/// How long after the window is covered the programme starts.
const _lead = Duration(seconds: 15);

/// How long the session waits for the window to be covered.
const _cover = Duration(minutes: 6);

/// How long a notification may wait for its answer.
const _patience = Duration(minutes: 4);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final file = File('build/real_reminder/session.log');
  final started = Stopwatch()..start();
  void say(String line) {
    final at = (started.elapsedMilliseconds / 1000).toStringAsFixed(1);
    final stamped = '[${at.padLeft(6)} s] $line';
    // Read live, from the console.
    // ignore: avoid_print
    print('REMINDER $stamped');
    file.writeAsStringSync('$stamped\n', mode: FileMode.append);
  }

  testWidgets('two real reminders: a click on the text, then Watch', (
    tester,
  ) async {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync('');
    HttpOverrides.global = null;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    var ahead = Duration.zero;
    DateTime clock() => DateTime.now().add(ahead);
    final log = AppLog(output: _Quiet(), secrets: SecretRegistry());
    final desktop = _Heard(platformSystemNotifier(log), say);
    final window = _Seen(const WindowManagerControls(), say);

    final panel = (await tester.runAsync(
      () => FakePanel.start(streams: streamsAvailable),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    final app = (await tester.runAsync(
      () => PanelApp.open(
        panel,
        video: true,
        overrides: [
          appClockProvider.overrideWithValue(clock),
          systemNotificationsProvider.overrideWithValue(desktop),
          windowControlsProvider.overrideWithValue(window),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(app.close));
    final container = app.container;
    final imported = (await tester.runAsync(
      () =>
          container.read(guideImportServiceProvider).importGuide(app.sourceId),
    ))!;
    expect(imported.isOk, isTrue, reason: '${imported.failureOrNull}');

    // Two programmes that start later today, on the first two channels
    // (the ones with a stream to play).
    final rounds = (await tester.runAsync(() => _two(app, clock())))!;
    container.read(reminderWatchesProvider);
    await tester.runAsync(
      () => container.read(reminderServiceProvider).start(),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const IptvPlayerApp(),
      ),
    );
    await _wait(tester, const Duration(seconds: 2));
    container.read(routerProvider).go(AppDestination.guide.path);
    await _wait(tester, const Duration(seconds: 1));
    say('the app is open, on the Guide');

    final coordinator = container.read(playbackCoordinatorProvider);
    for (final (index, (channel, programme)) in rounds.indexed) {
      final what = index == 0
          ? "click the notification's TEXT"
          : "click the notification's WATCH button";
      say(
        'round ${index + 1}: waiting for the window to be covered (click '
        'another window)',
      );
      final coverBy = DateTime.now().add(_cover);
      var covered = 0;
      while (covered < 4 && DateTime.now().isBefore(coverBy)) {
        await _wait(tester, const Duration(milliseconds: 500));
        final front = await tester.runAsync(
          const WindowManagerControls().isFocused,
        );
        covered = front ?? true ? 0 : covered + 1;
      }
      if (covered < 4) say('the window was never covered: going on anyway');
      // The app's clock, so that this programme starts a quarter of a
      // minute of real time from now.
      ahead = programme.start.difference(DateTime.now()) - _lead;
      await tester.runAsync(
        () => toggleReminder(container, channel, programme),
      );
      final held = (await tester.runAsync(
        () => container.read(reminderRepositoryProvider).all(),
      ))!.valueOrNull!;
      expect(held, hasLength(1), reason: 'the reminder is set');
      say(
        'round ${index + 1}: a reminder is set for "${programme.title}" on '
        '${channel.name}, starting in ${_lead.inSeconds} s; then $what',
      );

      final shown = desktop.shown.length;
      final answered = desktop.answers.length;
      final raised = window.raised.length;
      final deadline = DateTime.now().add(_lead + _patience);
      while (DateTime.now().isBefore(deadline)) {
        await _wait(tester, const Duration(milliseconds: 500));
        if (desktop.answers.length > answered ||
            window.raised.length > raised ||
            app.location == '/player') {
          break;
        }
      }
      if (desktop.shown.length == shown) {
        say(
          'NO notification went to the desktop: the window was in front at '
          'the start (the app said it in a toast), or the desktop has no '
          'notification service',
        );
      }
      // What the click led to, once it has had time to.
      await _wait(tester, const Duration(seconds: 4));
      final focused = await tester.runAsync(
        const WindowManagerControls().isFocused,
      );
      final answer = desktop.answers.length > answered
          ? '${desktop.answers.last}'
          : 'nothing';
      final asked = window.raised.length - raised;
      final token = asked == 0
          ? ''
          : ' (token: ${window.raised.last == null ? 'none' : 'yes'})';
      say(
        'after the answer: the desktop said $answer; the app asked for the '
        'window $asked time(s)$token; the window is '
        '${focused ?? false ? 'IN FRONT' : 'NOT in front'}; the app is on '
        '${app.location}; playback is ${coordinator.state.runtimeType}',
      );
      // A few seconds of the channel, then back to the Guide for the next.
      await _wait(tester, const Duration(seconds: 8));
      if (app.location == '/player') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _wait(tester, const Duration(seconds: 2));
      }
      await tester.runAsync(coordinator.stop);
      container.read(routerProvider).go(AppDestination.guide.path);
      await _wait(tester, const Duration(seconds: 2));
    }
    say('done: the app closes now');
  }, timeout: const Timeout(Duration(minutes: 24)));
}

/// Frames for [time] of real time.
Future<void> _wait(WidgetTester tester, Duration time) async {
  final until = DateTime.now().add(time);
  while (DateTime.now().isBefore(until)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

/// A later programme on each of the first two channels.
Future<List<(ChannelItem, EpgProgramme)>> _two(
  PanelApp app,
  DateTime now,
) async {
  final container = app.container;
  final channels =
      (await container
              .read(channelRepositoryProvider)
              .range(ChannelQuery(sourceId: app.sourceId), 0, 2))
          .valueOrNull!;
  final guide =
      (await container
              .read(epgRepositoryProvider)
              .windowForChannels(
                [for (final channel in channels) channel.id],
                now.add(const Duration(minutes: 30)),
                now.add(const Duration(hours: 12)),
              ))
          .valueOrNull!;
  return [
    for (final channel in channels)
      (
        channel,
        (guide[channel.id] ?? const <EpgProgramme>[]).firstWhere(
          (p) => p.start.isAfter(now.add(const Duration(minutes: 30))),
        ),
      ),
  ];
}

/// The desktop's real notifications, with what goes to them and comes
/// back said aloud.
final class _Heard implements SystemNotifier {
  new(this._real, this._say) {
    _real.responses.listen((response) {
      answers.add(response);
      _say('the desktop answered: $response');
      _responses.add(response);
    });
  }

  final SystemNotifier _real;
  final void Function(String line) _say;
  final shown = <SystemNotice>[];
  final answers = <NoticeResponse>[];
  final _responses = StreamController<NoticeResponse>.broadcast();

  @override
  Future<bool> show(SystemNotice notice) async {
    final ok = await _real.show(notice);
    if (ok) shown.add(notice);
    _say(
      'notification "${notice.title}" / "${notice.body}" '
      '[${notice.action ?? 'no button'}]: '
      '${ok ? 'the desktop took it' : 'the desktop did NOT take it'}',
    );
    return ok;
  }

  @override
  Stream<NoticeResponse> get responses => _responses.stream;

  @override
  Future<void> dispose() => _real.dispose();
}

/// The real window, with each ask to bring it forward said aloud.
final class _Seen implements WindowControls {
  new(this._real, this._say);

  final WindowControls _real;
  final void Function(String line) _say;

  /// The token of each ask, or null.
  final raised = <String?>[];

  @override
  Future<bool> isFullScreen() => _real.isFullScreen();

  @override
  Future<void> setFullScreen({required bool on}) => _real.setFullScreen(on: on);

  @override
  Future<bool> isFocused() async {
    final focused = await _real.isFocused();
    _say('is the window in front? ${focused ? 'yes' : 'no'}');
    return focused;
  }

  @override
  Future<void> bringToFront({String? activationToken}) {
    raised.add(activationToken);
    _say(
      'bringing the window forward '
      '(${activationToken == null ? 'no token' : "with the desktop's token"})',
    );
    return _real.bringToFront(activationToken: activationToken);
  }
}

class _Quiet extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
