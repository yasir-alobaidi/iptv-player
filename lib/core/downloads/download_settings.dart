import 'package:meta/meta.dart';

/// Settings → Downloads & library's speed limit (docs/09): it leaves room
/// for streaming on the same network.
enum DownloadSpeedLimit {
  unlimited(null),
  mbps50(50),
  mbps20(20),
  mbps10(10);

  new(this.megabits);

  /// Megabits a second; null is no limit.
  final int? megabits;

  /// Bytes a second; null is no limit.
  int? get bytesPerSecond => switch (megabits) {
    final m? => m * 1000 * 1000 ~/ 8,
    null => null,
  };
}

/// Settings → Downloads & library's download half (docs/09, the canvas).
@immutable
final class DownloadSettings {
  const new({
    this.folder,
    this.atATime = 1,
    this.speedLimit = DownloadSpeedLimit.unlimited,
    this.resumeOnLaunch = true,
    this.keepAwake = true,
  });

  /// Tolerant: anything missing or of another type reads as its default.
  factory fromJson(Object? json) {
    if (json is! Map) return const DownloadSettings();
    final folder = json['folder'];
    final atATime = json['at_a_time'];
    final limit = json['speed_limit_mbps'];
    return DownloadSettings(
      folder: folder is String && folder.trim().isNotEmpty ? folder : null,
      atATime: atATime is int ? atATime.clamp(1, maxAtATime) : 1,
      speedLimit: DownloadSpeedLimit.values.firstWhere(
        (l) => l.megabits == limit,
        orElse: () => DownloadSpeedLimit.unlimited,
      ),
      resumeOnLaunch: json['resume_on_launch'] != false,
      keepAwake: json['keep_awake'] != false,
    );
  }

  static const maxAtATime = 3;

  /// Where new downloads go; null is the system's Videos folder +
  /// `IPTV Player`. A change applies to new downloads only.
  final String? folder;

  /// 1–3, and never more than a source has free (docs/09).
  final int atATime;
  final DownloadSpeedLimit speedLimit;

  /// Unfinished downloads pick up where they stopped when the app opens.
  final bool resumeOnLaunch;

  /// The computer stays awake while downloads run.
  final bool keepAwake;

  DownloadSettings copyWith({
    String? folder,
    int? atATime,
    DownloadSpeedLimit? speedLimit,
    bool? resumeOnLaunch,
    bool? keepAwake,
  }) => DownloadSettings(
    folder: folder ?? this.folder,
    atATime: atATime ?? this.atATime,
    speedLimit: speedLimit ?? this.speedLimit,
    resumeOnLaunch: resumeOnLaunch ?? this.resumeOnLaunch,
    keepAwake: keepAwake ?? this.keepAwake,
  );

  Map<String, Object?> toJson() => {
    'folder': folder,
    'at_a_time': atATime,
    'speed_limit_mbps': speedLimit.megabits,
    'resume_on_launch': resumeOnLaunch,
    'keep_awake': keepAwake,
  };

  @override
  bool operator ==(Object other) =>
      other is DownloadSettings &&
      other.folder == folder &&
      other.atATime == atATime &&
      other.speedLimit == speedLimit &&
      other.resumeOnLaunch == resumeOnLaunch &&
      other.keepAwake == keepAwake;

  @override
  int get hashCode =>
      Object.hash(folder, atATime, speedLimit, resumeOnLaunch, keepAwake);
}
