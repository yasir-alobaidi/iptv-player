import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/presentation/playback_text.dart';

// Every phrase the casting screens say (docs/05 §11, sketches A–E).

/// The ports the TV fetches the stream on: what a firewall must let in.
const castPortRange = '$castRelayFirstPort–$castRelayLastPort';

/// The picker's model line: "Chromecast · 1080p · H.264 only", from what
/// the device says and what it taught the app.
String castModelLine(CastDevice device, KnownCastDevice? known) {
  final learned = known?.learned;
  final hevc = known?.hevc ?? HevcSupport.auto;
  return [
    device.model ?? (device.manual ? 'Added by address' : 'Cast device'),
    if (learned?.maxHeight case final height?) '${height}p',
    if (hevc == HevcSupport.no ||
        (hevc == HevcSupport.auto &&
            (learned?.refusedCodecs.contains('hevc') ?? false)))
      'H.264 only'
    else if (hevc == HevcSupport.yes)
      'HEVC',
  ].join(' · ');
}

/// A device's status in the picker.
enum CastDeviceStatus { available, busy, casting, notAnswering }

CastDeviceStatus castDeviceStatus(CastDevice device, {required bool casting}) {
  if (casting) return CastDeviceStatus.casting;
  if (!device.answering) return CastDeviceStatus.notAnswering;
  if (device.status != null) return CastDeviceStatus.busy;
  return CastDeviceStatus.available;
}

String castDeviceStatusLabel(CastDevice device, CastDeviceStatus status) =>
    switch (status) {
      CastDeviceStatus.available => 'Available',
      CastDeviceStatus.casting => 'Casting',
      CastDeviceStatus.notAnswering => 'Not answering',
      CastDeviceStatus.busy => 'Busy · ${_busyWith(device.status!)}',
    };

String _busyWith(String status) {
  final text = status.trim();
  if (text.isEmpty) return 'in use';
  final lower = text.toLowerCase();
  if (lower.contains('music') || lower.contains('spotify')) {
    return 'playing music';
  }
  return text;
}

/// What the picker's subtitle says will be cast: "Arena Sports 1 ·
/// Continental Cup · Semi-final".
String castWhatLine(Playable? item, {String? programme}) => switch (item) {
  null => 'Choose a device, then play something.',
  PlayableChannel(:final channel) => [channel.name, ?programme].join(' · '),
  PlayableMovie(:final movie) => movie.name,
  PlayableEpisode(:final series, :final episode) =>
    '${series.name} · S${episode.season} E${episode.episode} · '
        '${episode.title}',
  PlayableLibraryItem(:final item) => item.title,
};

/// The casting view's and the bar's word for where a cast is, when it
/// isn't simply playing.
String? castPhaseLine(CastingState state) => switch (state.phase) {
  CastPhase.connecting => 'Connecting…',
  CastPhase.preparing => 'Preparing…',
  CastPhase.idle => 'Nothing playing',
  CastPhase.ended => 'Finished',
  CastPhase.failed => "Couldn't play",
  CastPhase.playing || CastPhase.off => null,
};

/// Sketch D's message for [problem] on [deviceName]; a stream's problem
/// in the same words as playing here.
({String title, String message}) castProblemText(
  CastProblem problem,
  String deviceName, {
  Playable? item,
}) => switch (problem.kind) {
  CastProblemKind.deviceUnreachable => (
    title: "Couldn't reach $deviceName",
    message:
        'Check that it is on and on the same Wi-Fi as this computer, '
        'not a guest network.',
  ),
  CastProblemKind.receiverRefused => (
    title: "$deviceName didn't start casting",
    message: 'It may be busy or updating. Try again in a moment.',
  ),
  CastProblemKind.computerUnreachable => (
    title: "$deviceName couldn't reach this computer",
    message:
        'Check that a firewall lets it in on ports $castPortRange, and '
        'that no VPN is in the way.',
  ),
  CastProblemKind.deviceCantPlay => (
    title: "$deviceName couldn't play this",
    message: 'Try it here, or try another channel.',
  ),
  CastProblemKind.cantReencode => (
    title: "This computer can't convert this stream for $deviceName",
    message:
        'Its picture needs re-encoding, and no encoder works here. Try it '
        'here instead.',
  ),
  CastProblemKind.relay => (
    title: 'The stream to $deviceName stopped',
    message: 'It kept failing on this computer. Try again in a moment.',
  ),
  CastProblemKind.nothingToPlay => (
    title: 'Nothing to play',
    message: 'This stream has neither a picture nor a sound.',
  ),
  CastProblemKind.stream => problemText(problem.stream!, item: item),
};

/// A toast for a session the device ended.
String castClosedText(CastSessionClosed notice) => switch (notice.end) {
  CastEnd.otherApp =>
    '${notice.deviceName} started ${notice.otherApp ?? 'something else'}',
  CastEnd.closedOnDevice => 'Casting stopped on ${notice.deviceName}',
  CastEnd.lost => 'Lost the connection to ${notice.deviceName}',
  CastEnd.stopped || CastEnd.left => 'Stopped casting to ${notice.deviceName}',
};

/// The firewall and network help (the picker's Troubleshoot, Settings →
/// Casting): what each line names, in order.
const castTroubleshooting = [
  (
    'Same network',
    'The device and this computer have to be on the same Wi-Fi or wired '
        'network. A guest network keeps its devices apart.',
  ),
  (
    'Firewall',
    'The TV fetches the stream from this computer on ports $castPortRange. '
        'On Ubuntu with ufw on: sudo ufw allow '
        '$castRelayFirstPort:$castRelayLastPort/tcp. On Windows, allow IPTV '
        'Player when Windows asks, or in Windows Security → Firewall → '
        'Allow an app.',
  ),
  (
    'VPN',
    'A VPN on this computer can send its traffic elsewhere. Pause it, or '
        'let it pass local network traffic.',
  ),
  (
    'Not listed at all?',
    "Add the device by its IP address: you find it in the TV's settings "
        '(Network → About).',
  ),
];

/// What a device taught, for Settings → Casting ("Learned: 1080p at most ·
/// no HEVC"); null when nothing.
String? castLearnedLine(CastLearned learned) {
  final parts = [
    if (learned.maxHeight case final height?) '${height}p at most',
    if (learned.refusedCodecs.contains('hevc')) 'no HEVC',
    for (final codec in learned.refusedCodecs)
      if (codec != 'hevc') 'no ${codec.toUpperCase()}',
    if (learned.refusedInterlaced) 'interlaced re-encoded',
    if (learned.directRefusedSources.length == 1)
      'one source through this computer'
    else if (learned.directRefusedSources.length > 1)
      '${learned.directRefusedSources.length} sources through this computer',
  ];
  return parts.isEmpty ? null : 'Learned: ${parts.join(' · ')}';
}
