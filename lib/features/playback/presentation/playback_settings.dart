import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';

/// Settings → Playback (ADR-010 decision 5): the buffer preset,
/// deinterlacing, preferred languages, and, for the source being browsed,
/// its live format. Every change is saved at once and applies to the next
/// stream opened.
class PlaybackSettingsSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PlaybackSettingsSection> createState() =>
      _PlaybackSettingsSectionState();
}

class _PlaybackSettingsSectionState
    extends ConsumerState<PlaybackSettingsSection> {
  late final _audio = TextEditingController(
    text: ref
        .read(playbackSettingsControllerProvider)
        .audioLanguages
        .join(', '),
  );
  late final _subtitles = TextEditingController(
    text: ref
        .read(playbackSettingsControllerProvider)
        .subtitleLanguages
        .join(', '),
  );
  String? _error;

  @override
  void dispose() {
    _audio.dispose();
    _subtitles.dispose();
    super.dispose();
  }

  Future<void> _save(PlaybackSettings settings) async {
    final result = await ref
        .read(playbackSettingsControllerProvider.notifier)
        .update(settings);
    if (!mounted) return;
    setState(() {
      _error = switch (result) {
        Err(:final failure) =>
          "Couldn't save that change. ${failureMessage(failure)}",
        Ok() => null,
      };
    });
  }

  static List<String> _languages(String text) => [
    for (final part in text.split(RegExp('[,; ]+')))
      if (part.trim().isNotEmpty) part.trim().toLowerCase(),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = ref.watch(playbackSettingsControllerProvider);
    // The stored choices arrive after the first frame: fill the fields
    // then, unless the user is already typing.
    ref.listen(playbackSettingsControllerProvider, (previous, next) {
      if (previous?.audioLanguages != next.audioLanguages &&
          _languages(_audio.text).join(',') != next.audioLanguages.join(',')) {
        _audio.text = next.audioLanguages.join(', ');
      }
      if (previous?.subtitleLanguages != next.subtitleLanguages &&
          _languages(_subtitles.text).join(',') !=
              next.subtitleLanguages.join(',')) {
        _subtitles.text = next.subtitleLanguages.join(', ');
      }
    });
    final source = ref.watch(currentSourceProvider);

    return SettingsPanel(
      title: 'Playback',
      subtitle: 'Applies to the next channel you open.',
      body: ListView(
        children: [
          if (_error case final error?) ...[
            AppBanner(message: error, tone: BannerTone.error),
            SizedBox(height: tokens.spacing.s16),
          ],
          _Setting(
            title: 'Buffering',
            description: switch (settings.preset) {
              BufferPreset.lowLatency =>
                'About 2 s of buffer: quickest to start and closest to '
                    'live. For a strong connection.',
              BufferPreset.balanced =>
                'About 8 s of buffer. Right for most connections.',
              BufferPreset.stable =>
                'About 20 s of buffer: rides out a weak Wi-Fi or an '
                    'unsteady provider, at the cost of a slower start.',
            },
            control: SegmentedControl<BufferPreset>(
              options: const [
                SegmentOption(
                  value: BufferPreset.lowLatency,
                  label: 'Low latency',
                ),
                SegmentOption(value: BufferPreset.balanced, label: 'Balanced'),
                SegmentOption(value: BufferPreset.stable, label: 'Stable'),
              ],
              value: settings.preset,
              onChanged: (preset) =>
                  unawaited(_save(settings.copyWith(preset: preset))),
            ),
          ),
          _Setting(
            title: 'Deinterlacing',
            description:
                'Auto smooths interlaced broadcasts (1080i, 576i) and '
                'leaves the rest alone.',
            control: SegmentedControl<String>(
              options: const [
                SegmentOption(value: 'auto', label: 'Auto'),
                SegmentOption(value: 'on', label: 'On'),
                SegmentOption(value: 'off', label: 'Off'),
              ],
              value: switch (settings.deinterlace) {
                null => 'auto',
                true => 'on',
                false => 'off',
              },
              onChanged: (value) => unawaited(
                _save(
                  settings.copyWith(
                    deinterlace: () => switch (value) {
                      'on' => true,
                      'off' => false,
                      _ => null,
                    },
                  ),
                ),
              ),
            ),
          ),
          _Setting(
            title: 'Preferred audio',
            description:
                'Language codes, most wanted first, e.g. "ar, en". The '
                "stream's own choice is used when none of them is there.",
            control: SizedBox(
              width: 240,
              child: AppTextField(
                controller: _audio,
                hint: 'ar, en',
                onChanged: (text) => unawaited(
                  _save(settings.copyWith(audioLanguages: _languages(text))),
                ),
              ),
            ),
          ),
          _Setting(
            title: 'Preferred subtitles',
            description:
                'Language codes, most wanted first. Leave it empty to '
                'start with subtitles off.',
            control: SizedBox(
              width: 240,
              child: AppTextField(
                controller: _subtitles,
                hint: 'en',
                onChanged: (text) => unawaited(
                  _save(settings.copyWith(subtitleLanguages: _languages(text))),
                ),
              ),
            ),
          ),
          if (source != null && source.type == SourceType.xtream)
            _Setting(
              title: 'Live format · ${source.name}',
              description:
                  'TS starts faster and zaps better. Try HLS if channels '
                  'from this provider stall or refuse to start.',
              control: SegmentedControl<LiveFormat>(
                options: const [
                  SegmentOption(value: LiveFormat.ts, label: 'TS'),
                  SegmentOption(value: LiveFormat.hls, label: 'HLS'),
                ],
                value: source.liveFormat,
                onChanged: (format) =>
                    unawaited(_setLiveFormat(source, format)),
              ),
            ),
          if (source != null)
            _Setting(
              title: 'User-Agent · ${source.name}',
              description: source.userAgent == null
                  ? 'The default one players use. Some providers want '
                        'their own.'
                  : 'Set to "${source.userAgent}".',
              control: AppButton(
                label: 'Edit source',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.s,
                onPressed: () => context.push(editSourcePath(source.id)),
              ),
            ),
        ],
      ),
    );
  }

  /// Saves the format on the source itself (docs/02: `live_format` is a
  /// source's column); the password stays as stored.
  Future<void> _setLiveFormat(Source source, LiveFormat format) async {
    final sources = ref.read(sourceRepositoryProvider);
    final secrets = await sources.credentialsFor(source.id);
    final credentials = secrets.valueOrNull;
    Result<void> result;
    if (credentials == null) {
      result = Err(secrets.failureOrNull!);
    } else {
      result = await sources.update(
        source.id,
        SourceDraft(
          type: source.type,
          name: source.name,
          url: credentials.url,
          username: source.username,
          epgUrl: credentials.epgUrl,
          userAgent: source.userAgent,
          liveFormat: format,
          epgOffsetMinutes: source.epgOffsetMinutes,
          refreshHours: source.refreshHours,
          maxConnectionsOverride: source.maxConnectionsOverride,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _error = switch (result) {
        Err(:final failure) =>
          "Couldn't change the live format. ${failureMessage(failure)}",
        Ok() => null,
      };
    });
  }
}

/// One setting: its name and what it does on the left, the control on
/// the right.
class _Setting extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.control,
  });

  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tokens.text.label.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: tokens.spacing.s4),
                Text(
                  description,
                  style: tokens.text.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.s24),
          control,
        ],
      ),
    );
  }
}
