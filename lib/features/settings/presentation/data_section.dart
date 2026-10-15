import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_store.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';
import 'package:iptv_player/features/settings/data/data_providers.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/settings/presentation/data_text.dart';
import 'package:iptv_player/features/settings/presentation/setting_row.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';

/// What the page is busy with; one thing at a time.
enum _Busy { pictures, guide, exporting, importing }

/// Settings → Data (Phase 9 step 3, sketch C): the kept pictures and the
/// guide, each with a Clear that asks first, and Export… / Import… of
/// the settings and the user's choices.
class DataSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<DataSection> {
  _Busy? _busy;
  String? _error;

  /// True from Import…'s press to the end of its preview: a second press
  /// must not open a second one. Not [_busy], which disables the button
  /// and so would take the focus from it under the preview.
  var _choosingFile = false;

  /// Each button's focus, to give it back when its work is done: a
  /// button is disabled while it works, and a disabled control can't
  /// hold the focus.
  final Map<_Busy, FocusNode> _focus = {
    for (final what in _Busy.values) what: FocusNode(),
  };

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _done([String? error]) {
    if (!mounted) return;
    final was = _busy;
    setState(() {
      _busy = null;
      _error = error;
    });
    if (was != null) _refocus(was);
  }

  /// Once the buttons are enabled again: the focus back on the one that
  /// was pressed, or, if that one has nothing left to do (Clear, with
  /// nothing kept), on the next that can be pressed. Pressing it was the
  /// last thing the user did here, and where the focus fell when the
  /// button went busy is nowhere they chose. Not while something else is
  /// on top of the page.
  void _refocus(_Busy was) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final order = [
        was,
        for (final what in _Busy.values)
          if (what.index > was.index) what,
      ];
      for (final what in order) {
        final node = _focus[what]!;
        if (node.context != null && node.canRequestFocus) {
          node.requestFocus();
          return;
        }
      }
    });
  }

  AppNotices get _notices => ref.read(appNoticesProvider);

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async =>
      await showAppDialog<bool>(
        context,
        builder: (context) => AppDialog(
          title: title,
          primaryLabel: action,
          destructive: true,
          onPrimary: () => Navigator.of(context).pop(true),
          secondaryLabel: 'Keep',
          onSecondary: () => Navigator.of(context).pop(false),
          child: Padding(
            padding: EdgeInsets.only(bottom: context.tokens.spacing.s4),
            child: Text(
              body,
              style: context.tokens.text.body.copyWith(
                color: context.tokens.colors.textSecondary,
              ),
            ),
          ),
        ),
      ) ??
      false;

  Future<void> _clearPictures(int bytes) async {
    if (!await _confirm(
      title: 'Clear the kept pictures?',
      body: clearPicturesBody(bytes, device: _device),
      action: 'Clear',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = _Busy.pictures);
    final cleared = await ref.read(artworkStoreProvider).clear();
    ref.invalidate(artworkUsageProvider);
    switch (cleared) {
      case Ok():
        _notices.show(
          AppNotice(picturesCleared(bytes), tone: NoticeTone.success),
        );
        _done();
      case Err(:final failure):
        _done("Couldn't clear the pictures. ${failureMessage(failure)}");
    }
  }

  Future<void> _clearGuide(List<String> sourceIds) async {
    if (!await _confirm(
      title: 'Clear the guide?',
      body: clearGuideBody,
      action: 'Clear guide',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = _Busy.guide);
    final guide = ref.read(epgRepositoryProvider);
    AppFailure? failed;
    for (final id in sourceIds) {
      final cleared = await guide.clearGuide(id);
      failed ??= cleared.failureOrNull;
    }
    if (failed != null) {
      _done("Couldn't clear the whole guide. ${failureMessage(failed)}");
      return;
    }
    _notices.show(
      AppNotice(
        'Guide cleared. It comes back at its next refresh.',
        tone: NoticeTone.success,
      ),
    );
    _done();
  }

  Future<void> _export() async {
    final name = settingsExportFileName(ref.read(appClockProvider)());
    final path = await ref.read(settingsSavePickerProvider)(name);
    if (path == null || !mounted) return;
    setState(() => _busy = _Busy.exporting);
    switch (await ref.read(settingsTransferProvider).exportTo(path)) {
      case Ok(:final value):
        _notices.show(AppNotice(exportDone(value), tone: NoticeTone.success));
        _done();
      case Err(:final failure):
        _done("Couldn't write that file. ${failureMessage(failure)}");
    }
  }

  Future<void> _import() async {
    if (_choosingFile) return;
    _choosingFile = true;
    try {
      await _chooseAndImport();
    } finally {
      _choosingFile = false;
    }
  }

  Future<void> _chooseAndImport() async {
    final path = await ref.read(settingsOpenPickerProvider)();
    if (path == null || !mounted) return;
    final transfer = ref.read(settingsTransferProvider);
    final read = await transfer.read(path);
    if (!mounted) return;
    switch (read) {
      case SettingsFileUnread(:final failure):
        setState(() {
          _error = "Couldn't read that file. ${failureMessage(failure)}";
        });
        return;
      case SettingsFileUnusable(:final problem, :final format):
        await showAppDialog<void>(
          context,
          builder: (context) => AppDialog(
            title: "This file can't be imported",
            primaryLabel: 'Close',
            onPrimary: () => Navigator.of(context).pop(),
            child: Padding(
              padding: EdgeInsets.only(bottom: context.tokens.spacing.s4),
              child: Text(
                fileProblem(problem, format: format),
                style: context.tokens.text.body.copyWith(
                  color: context.tokens.colors.textSecondary,
                ),
              ),
            ),
          ),
        );
        return;
      case SettingsFileReadable(:final plan):
        final go = await showAppDialog<bool>(
          context,
          builder: (context) => ImportPreviewDialog(plan: plan),
        );
        if (go != true || !mounted) return;
        setState(() => _busy = _Busy.importing);
        final applied = await transfer.apply(plan);
        switch (applied) {
          case Ok(:final value):
            await _afterImport(plan, value);
            _notices.show(
              AppNotice(importDone(value), tone: NoticeTone.success),
            );
            _done();
          case Err(:final failure):
            _done(
              "Couldn't import that file, so nothing was changed. "
              '${failureMessage(failure)}',
            );
        }
    }
  }

  /// What is held in memory follows what was just written: the settings
  /// pages, and the matching of every source whose matches changed.
  Future<void> _afterImport(ImportPlan plan, ImportSummary summary) async {
    final pages = summary.settingsPages;
    await Future.wait([
      if (pages.contains('appearance'))
        ref.read(appearanceControllerProvider.notifier).retry(),
      if (pages.contains('playback'))
        ref.read(playbackSettingsControllerProvider.notifier).reload(),
      if (pages.contains('guide'))
        ref.read(guideSettingsControllerProvider.notifier).reload(),
      if (pages.contains('cast'))
        ref.read(castSettingsControllerProvider.notifier).reload(),
      if (pages.contains('downloads'))
        ref.read(downloadSettingsControllerProvider.notifier).reload(),
    ]);
    final matching = ref.read(guideMatchingProvider);
    for (final source in plan.here) {
      if (source.exported.guideMatches.isEmpty) continue;
      // Live TV and the Guide follow the new matches. One that can't be
      // applied now is applied by the next sync or guide refresh.
      await matching.rematch(source.sourceId!);
    }
  }

  /// "this computer", "this TV".
  String get _device => ref.read(formFactorProvider).thisDevice;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final usage = ref.watch(artworkUsageProvider);
    final guide = ref.watch(guideTotalsProvider);
    final busy = _busy;

    final pictures = usage.value?.valueOrNull;
    final picturesFailure = usage.value?.failureOrNull;

    // Nothing kept is nothing to clear; a size that couldn't be measured
    // still can be. A guide being imported can't be cleared.
    final canClearPictures =
        busy == null &&
        ((pictures != null && pictures.bytes > 0) || picturesFailure != null);
    final canClearGuide =
        busy == null &&
        guide != null &&
        !guide.importing &&
        guide.sourceIds.isNotEmpty;
    // A button that has the focus and has just run out of work (Clear,
    // once the pictures are gone) would drop it nowhere: it goes to the
    // next button instead.
    if (busy == null) {
      final enabled = {
        _Busy.pictures: canClearPictures,
        _Busy.guide: canClearGuide,
        _Busy.exporting: true,
        _Busy.importing: true,
      };
      for (final MapEntry(key: what, value: node) in _focus.entries) {
        if (node.hasPrimaryFocus && !enabled[what]!) _refocus(what);
      }
    }

    return SettingsPanel(
      title: 'Data',
      body: ListView(
        children: [
          if (_error case final error?) ...[
            AppBanner(
              message: error,
              tone: BannerTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
            SizedBox(height: tokens.spacing.s16),
          ],
          SettingRow(
            title: 'Pictures',
            description: switch ((pictures, picturesFailure)) {
              (final kept?, _) => picturesLine(
                bytes: kept.bytes,
                maxBytes: kept.maxBytes,
                device: _device,
              ),
              (_, final failure?) =>
                "${picturesKept(_device)} Couldn't measure them. "
                    '${failureMessage(failure)}',
              _ => '${picturesKept(_device)} Measuring them…',
            },
            control: AppButton(
              label: 'Clear',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.s,
              focusNode: _focus[_Busy.pictures],
              loading: busy == _Busy.pictures,
              onPressed: canClearPictures
                  ? () => unawaited(_clearPictures(pictures?.bytes ?? 0))
                  : null,
            ),
          ),
          SettingRow(
            title: 'Guide',
            description: guide == null
                ? 'Reading the guide…'
                : guideLine(
                    programmes: guide.programmes,
                    until: guide.until,
                    importing: guide.importing,
                    device: _device,
                  ),
            control: AppButton(
              label: 'Clear guide',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.s,
              focusNode: _focus[_Busy.guide],
              loading: busy == _Busy.guide,
              onPressed: canClearGuide
                  ? () => unawaited(_clearGuide(guide.sourceIds))
                  : null,
            ),
          ),
          // A file to take to another device: a TV has no files to
          // write or open (ADR-025).
          if (ref.watch(formFactorProvider) == FormFactor.desktop)
            SettingRow(
              title: 'Your settings and choices',
              description: exportDescription,
              control: Wrap(
                spacing: tokens.spacing.s8,
                runSpacing: tokens.spacing.s8,
                children: [
                  AppButton(
                    label: 'Export…',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.s,
                    focusNode: _focus[_Busy.exporting],
                    loading: busy == _Busy.exporting,
                    onPressed: busy != null ? null : () => unawaited(_export()),
                  ),
                  AppButton(
                    label: 'Import…',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.s,
                    focusNode: _focus[_Busy.importing],
                    loading: busy == _Busy.importing,
                    onPressed: busy != null ? null : () => unawaited(_import()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What an import will do, before it does it (sketch C): the settings
/// replaced, each source's choices merged into the source here, and the
/// sources that aren't here named and left out. Cancel has the focus.
class ImportPreviewDialog extends StatelessWidget {
  const new({required this.plan, super.key});

  final ImportPlan plan;

  /// `bijou-settings-2026-10-12.json`: the file's own name, the
  /// folder left off.
  static String fileName(String path) =>
      path
          .split(RegExp(r'[/\\]'))
          .where((part) => part.isNotEmpty)
          .lastOrNull ??
      path;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final rows = <(String, String, bool)>[
      if (plan.replacesSettings) ('Settings', importSettingsLine, true),
      for (final source in plan.sources)
        if (source.isHere)
          (
            source.sourceName ?? source.exported.name,
            importSourceLine(source.exported),
            true,
          )
        else
          (source.exported.name, importMissingLine, false),
    ];
    return AppDialog(
      title: 'Import "${fileName(plan.path)}"?',
      subtitle: plan.isEmpty
          ? 'Nothing in this file can be brought over to this computer.'
          : "Your sources, their passwords and what you've watched stay as "
                'they are.',
      width: 640,
      // Cancel first: Enter straight away must change nothing.
      focusSecondary: true,
      primaryLabel: plan.isEmpty ? null : 'Import',
      onPrimary: plan.isEmpty ? null : () => Navigator.of(context).pop(true),
      secondaryLabel: plan.isEmpty ? 'Close' : 'Cancel',
      onSecondary: () => Navigator.of(context).pop(false),
      child: ScrollPane.child(
        semanticLabel: 'What importing this file will do',
        padding: EdgeInsets.all(tokens.spacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rows.isEmpty)
              Text(
                'The file holds no settings and no sources.',
                style: tokens.text.body.copyWith(color: colors.textSecondary),
              ),
            for (final (name, line, taken) in rows)
              Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.s8 - 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: context.scaled(168),
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.label.copyWith(
                          color: taken
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.s16),
                    Expanded(
                      child: Text(
                        line,
                        style: tokens.text.label
                            .withWeight(500)
                            .copyWith(
                              color: taken
                                  ? colors.textSecondary
                                  : colors.warning,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
