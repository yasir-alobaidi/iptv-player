import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_names.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/playback_text.dart';
import 'package:iptv_player/features/playback/presentation/vod_osd.dart';

/// What the full-screen player shows from the moment something is asked
/// for until its picture comes (the user: "add a nice loading screen for
/// it so the user won't get bored"), under the OSD.
///
/// A film, an episode or a video of the library opens on its own artwork,
/// dimmed and calm, with its title, the spinner and "Preparing…"; nothing
/// is fetched for it, and with no artwork it is the app's own dark
/// surface. A channel zaps fast and often: a quick zap is the spinner
/// alone, as before, and only a slow one brings its logo and name. Past a
/// few seconds, and again past a long while, the line under the spinner
/// says it goes on ([openingText]). Reconnecting before its first picture
/// keeps the artwork and the name under the pill, which says the rest.
///
/// The surface drops it the moment the picture shows (on a TV the picture
/// may be on its own layer behind the app: nothing is painted over it
/// then), and on a failure its card takes the place.
class PlayerOpeningScreen extends StatefulWidget {
  const new({required this.state, this.tv = false, super.key});

  /// [PlaybackOpening], or [PlaybackReconnecting] before any picture.
  final PlaybackState state;

  /// A TV: no blur filter on its small GPU (docs/07).
  final bool tv;

  @override
  State<PlayerOpeningScreen> createState() => _PlayerOpeningScreenState();
}

class _PlayerOpeningScreenState extends State<PlayerOpeningScreen> {
  final _timers = <Timer>[];
  bool _begun = false;

  /// A channel's logo and name are due.
  bool _named = false;
  OpeningWait _wait = OpeningWait.start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The clock starts with the screen: the tokens aren't there before.
    if (!_begun) {
      _begun = true;
      _restart();
    }
  }

  @override
  void didUpdateWidget(PlayerOpeningScreen old) {
    super.didUpdateWidget(old);
    // Every open has its own clock: a zap, another film, a Retry. A
    // reconnect is the same open going on.
    final state = widget.state;
    if (state.item != old.state.item ||
        (state is PlaybackOpening && !identical(state, old.state))) {
      _restart();
    }
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _restart() {
    _cancel();
    _named = false;
    _wait = OpeningWait.start;
    final player = context.tokens.player;
    void at(Duration after, VoidCallback change) => _timers.add(
      Timer(after, () {
        if (mounted) setState(change);
      }),
    );
    at(player.openingNameAfter, () => _named = true);
    at(player.openingStillAfter, () => _wait = OpeningWait.still);
    at(player.openingSlowAfter, () => _wait = OpeningWait.slow);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.state.item;
    if (item == null) return const SizedBox.shrink();
    // Reconnecting, the pill speaks and turns: no second spinner or line.
    final opening = widget.state is PlaybackOpening;
    final heading = switch (item) {
      PlayableChannel(:final channel) =>
        _named ? _FadeIn(child: _ChannelHeading(channel)) : null,
      _ => _TitleHeading(item),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item is! PlayableChannel)
          // Still while the spinner turns over it.
          RepaintBoundary(
            child: _Artwork(candidates: openingArtwork(item), tv: widget.tv),
          ),
        OsdScale(
          child: _Centred(
            heading: heading,
            spinner: opening,
            line: opening ? openingText(item, _wait) : null,
          ),
        ),
      ],
    );
  }
}

/// The spinner over the picture's area: while a stream opens, while it
/// fills its buffer. With reduce motion it is the still loading icon, as
/// every spinner in the app is.
class PlayerSpinner extends StatelessWidget {
  const new({this.large = false, super.key});

  /// The full-screen player's.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = tokens.player;
    final size = large ? player.spinnerSize : player.previewSpinnerSize;
    final color = tokens.colors.textPrimary;
    return SizedBox.square(
      dimension: size,
      child: tokens.motion.reduceMotion
          ? AppIcon(AppIcons.loading, size: size, color: color)
          : CircularProgressIndicator(
              strokeWidth: large
                  ? player.spinnerStroke
                  : player.previewSpinnerStroke,
              color: color,
            ),
    );
  }
}

/// A picture behind an opening: its address, and whether it is drawn soft
/// (a poster, a still or a video's frame) rather than as it is (a
/// backdrop).
typedef OpeningArtwork = ({String? url, bool soft});

/// The pictures [item] already carries, the best first: whichever is a
/// picture at all is drawn. Nothing is fetched for them: they are the
/// ones its pages and cards show.
List<OpeningArtwork> openingArtwork(Playable item) => switch (item) {
  PlayableMovie(:final movie) => [(url: movie.posterUrl, soft: true)],
  PlayableEpisode(:final series, :final episode) => [
    (url: series.backdropUrl, soft: false),
    (url: episode.stillUrl, soft: true),
    (url: series.posterUrl, soft: true),
  ],
  PlayableLibraryItem(item: final file) => _libraryArtwork(file),
  PlayableChannel() => const [],
};

/// A download's backdrop as its page has it, else the picture beside the
/// file or the frame grabbed from it, else what it was downloaded with.
List<OpeningArtwork> _libraryArtwork(LibraryItem file) {
  final stored = file.details ?? const <String, Object?>{};
  String? text(String key) => switch (stored[key]) {
    final String value when value.trim().isNotEmpty => value.trim(),
    _ => null,
  };
  return [
    (url: text('backdrop_url') ?? text('series_backdrop_url'), soft: false),
    if (libraryItemPicture(file) case final path?)
      (url: localArtworkUrl(path), soft: true),
    (url: text('still_url'), soft: true),
    (url: text('poster_url') ?? text('series_poster_url'), soft: true),
  ];
}

/// The artwork filling the picture's area, black at `openingDim` over its
/// own pixels; the app's dark surface under it, which is all there is
/// with none, and until it comes (or if it never does: offline): the
/// surface itself is never dimmed.
class _Artwork extends StatelessWidget {
  const new({required this.candidates, required this.tv});

  final List<OpeningArtwork> candidates;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final player = tokens.player;
    final window = MediaQuery.sizeOf(context).width;
    ImageProvider? image;
    var soft = false;
    for (final (:url, soft: drawnSoft) in candidates) {
      image = artworkFor(
        context,
        url,
        // A soft picture has no detail to keep: a TV's is a few pixels
        // wide and the stretch softens it, as a details page does.
        width: !drawnSoft
            ? window
            : tv
            ? player.openingTvSoftWidth
            : window * player.openingSoftDecode,
      );
      soft = drawnSoft;
      if (image != null) break;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.bg),
        if (image != null)
          ImageFiltered(
            enabled: soft && !tv,
            imageFilter: ImageFilter.blur(
              sigmaX: player.openingBlur,
              sigmaY: player.openingBlur,
            ),
            child: Image(
              image: image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // Dimmed in its own paint: no layer of its own, and nothing
              // darkens the surface while it hasn't come.
              color: colors.video.withValues(alpha: player.openingDim),
              colorBlendMode: BlendMode.srcATop,
              // A picture that doesn't come leaves the dark surface.
              errorBuilder: (context, _, _) => const SizedBox.shrink(),
              frameBuilder: tokens.motion.reduceMotion
                  ? null
                  : (context, child, frame, synchronous) => synchronous
                        ? child
                        : AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: player.openingFadeIn,
                            curve: tokens.motion.slowCurve,
                            child: child,
                          ),
            ),
          ),
      ],
    );
  }
}

/// [heading] above the spinner and [line] under it, the spinner at the
/// very centre, where it always was: nothing moves when the heading
/// comes, or the line, or when the spinner goes (its room is kept).
class _Centred extends StatelessWidget {
  const new({required this.heading, required this.spinner, this.line});

  final Widget? heading;
  final bool spinner;
  final String? line;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = tokens.player;
    final line = this.line;
    Widget measure(Widget child) => Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: player.openingTextWidth),
        child: child,
      ),
    );
    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: heading == null ? null : measure(heading!),
          ),
        ),
        SizedBox(height: tokens.spacing.s24),
        if (spinner)
          const PlayerSpinner(large: true)
        else
          SizedBox.square(dimension: player.spinnerSize),
        SizedBox(height: tokens.spacing.s24),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: line == null
                ? null
                : measure(
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        line,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.body.copyWith(
                          color: tokens.colors.textEmphasis,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// A film's or an episode's title, and "S2 · E5 · Northbound" under its
/// show's name, as the OSD's top calls it.
class _TitleHeading extends StatelessWidget {
  const new(this.item);

  final Playable item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final (title, line) = playableTitleLines(item);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tokens.text.hero.copyWith(color: colors.textPrimary),
        ),
        if (line != null) ...[
          SizedBox(height: tokens.spacing.s8),
          Text(
            line,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.h3.copyWith(color: colors.textEmphasis),
          ),
        ],
      ],
    );
  }
}

/// A slow channel's logo (or its monogram) over its name.
class _ChannelHeading extends StatelessWidget {
  const new(this.channel);

  final ChannelItem channel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = tokens.player.openingLogoSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChannelLogo(
          name: channel.name,
          size: size,
          borderRadius: tokens.radii.lgAll,
          image: artworkFor(context, channel.logoUrl, width: size),
        ),
        SizedBox(height: tokens.spacing.s16),
        Text(
          channel.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tokens.text.h1.copyWith(color: tokens.colors.textPrimary),
        ),
      ],
    );
  }
}

/// [child] fading in as it comes, when motion is allowed; at once when it
/// isn't.
class _FadeIn extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (tokens.motion.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: tokens.player.openingFadeIn,
      curve: tokens.motion.slowCurve,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: child,
    );
  }
}
