import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_request.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/presentation/search_text.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';

/// What opening a result does (Phase 6 decision 4). Search closes first,
/// on every action. Made from the app's container and router, not the
/// overlay's `ref`: most of this runs after the overlay is gone.
final class SearchActions {
  new(this._container, this._router);

  final ProviderContainer _container;
  final GoRouter _router;

  void _close() {
    if (isSearchOpen(_router)) _router.pop();
  }

  /// Browses [sourceId] when the result came from another source: the
  /// screen it opens shows the browsed one.
  void _browse(String sourceId) {
    if (_container.read(currentSourceProvider)?.id == sourceId) return;
    _container.read(chosenSourceIdProvider.notifier).choose(sourceId);
  }

  /// A channel full screen, zapping through its source's channels. Esc
  /// returns to the screen search was opened from, and the stream stops
  /// there, as it does back on Home.
  Future<void> watch(ChannelItem channel) async {
    _close();
    final coordinator = _container.read(playbackCoordinatorProvider);
    unawaited(coordinator.playLive(channel));
    await _router.push<void>(
      playerRoutePath,
      extra: ChannelQuery(sourceId: channel.sourceId),
    );
    if (coordinator.current != null) unawaited(coordinator.stop());
  }

  /// On now: its channel, full screen. Upcoming: the Guide on it, with
  /// its sheet open.
  Future<void> openProgramme(ProgrammeHit hit, DateTime now) async {
    if (hit.isOnAt(now)) return await watch(hit.channel);
    _close();
    _browse(hit.channel.sourceId);
    _container
        .read(guideProgrammeRequestProvider.notifier)
        .show(hit.channel, hit.programme);
    _router.go(AppDestination.guide.path);
  }

  /// A title's page, in its own branch, as Home opens one.
  void openMovie(MovieItem movie) {
    _close();
    _router.go(movieDetailsPath(movie));
  }

  void openSeries(SeriesItem series) {
    _close();
    _router.go(seriesDetailsPath(series));
  }

  /// "Show all in Live TV / Movies / Series": the screen, every channel
  /// or title, the text in its filter. The screen's view is made when it
  /// is, so the filter is set once it is up.
  void showAll(SearchGroupKind kind, String text) {
    _close();
    switch (kind) {
      case SearchGroupKind.channels:
        _router.go(AppDestination.liveTv.path);
        _afterFrame(
          () => _container
              .read(liveTvControllerProvider.notifier)
              .showSearch(text),
        );
      case SearchGroupKind.movies:
      case SearchGroupKind.series:
        final catalogue = kind == SearchGroupKind.movies
            ? CatalogueKind.movie
            : CatalogueKind.series;
        _router.go(
          catalogue == CatalogueKind.movie
              ? AppDestination.movies.path
              : AppDestination.series.path,
        );
        _afterFrame(
          () => _container
              .read(catalogueControllerProvider(catalogue).notifier)
              .showSearch(text),
        );
      case SearchGroupKind.programmes:
        break;
    }
  }

  /// The channel's menu's "Show in Live TV": Live TV, every channel, its
  /// name in the filter and the channel in the preview.
  void showInLiveTv(ChannelItem channel) {
    _close();
    _browse(channel.sourceId);
    _router.go(AppDestination.liveTv.path);
    _afterFrame(() {
      _container.read(liveTvControllerProvider.notifier)
        ..showSearch(channel.name)
        ..select(channel);
    });
  }

  Future<void> toggleFavorite(Object hit) async {
    switch (hit) {
      case ChannelHit(:final channel) || ProgrammeHit(:final channel):
        await _container
            .read(channelRepositoryProvider)
            .setFavorite(channel, on: !channel.isFavorite);
      case MovieHit(:final movie):
        await _container
            .read(movieRepositoryProvider)
            .setFavorite(movie, on: !movie.isFavorite);
      case SeriesHit(:final series):
        await _container
            .read(seriesRepositoryProvider)
            .setFavorite(series, on: !series.isFavorite);
    }
  }

  Future<void> hide(ChannelItem channel) => _container
      .read(channelRepositoryProvider)
      .setHidden(channel.id, hidden: true);

  /// The empty state's "Show in Settings": where hidden channels and
  /// categories come back.
  void showHidden() {
    _close();
    final source = _container.read(currentSourceProvider);
    openSettings(
      _router,
      _container.read(settingsLocationProvider.notifier),
      SettingsSection.categories,
      categoriesSourceId: source?.id,
    );
  }

  void addSource() {
    _close();
    unawaited(_router.push<void>(addSourceRoutePath));
  }

  static void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => action())
      ..ensureVisualUpdate();
  }
}
