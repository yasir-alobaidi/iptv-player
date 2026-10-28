import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/platform/licenses.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// About's Licences: every package, the bundled fonts, FFmpeg and mpv on
/// the left; the chosen one's text on the right. The list is one Tab
/// stop (↑/↓ inside, Enter shows a licence); the text is another,
/// scrolled by the keyboard.
Future<void> showLicensesDialog(BuildContext context) =>
    showAppDialog<void>(context, builder: (context) => const LicensesDialog());

class LicensesDialog extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LicensesDialog> createState() => _LicensesDialogState();
}

class _LicensesDialogState extends ConsumerState<LicensesDialog> {
  /// Narrower than this, the list goes above the text.
  static const _sideBySideFrom = 520.0;

  /// The list's height above the text: four packages and a half, so it
  /// says it scrolls.
  static const _stackedListHeight = 172.0;

  String? _chosen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final licenses = ref.watch(licensesProvider);
    final packages = licenses.value;
    return AppDialog(
      title: 'Licences',
      subtitle: packages == null || packages.isEmpty
          ? 'What $appName is built with.'
          : 'What $appName is built with: '
                '${formatCount(packages.length)} packages, fonts and '
                'programs.',
      width: 880,
      onClose: () => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.s20),
        child: SizedBox(
          height: 440,
          child: switch (licenses) {
            AsyncData(:final value) when value.isEmpty => const EmptyState(
              icon: AppIcons.info,
              title: 'No licences to show',
              message: 'This build came without its list of licences.',
              compact: true,
            ),
            AsyncData(:final value) => _content(value),
            AsyncError(:final error) => ErrorState(
              title: "The licences couldn't be read",
              message: 'They are part of the app itself. Try again.',
              details: '$error',
              onRetry: () => ref.invalidate(licensesProvider),
              retryLabel: 'Try again',
              compact: true,
            ),
            _ => Semantics(
              label: 'Reading the licences',
              container: true,
              child: SkeletonColumn(
                children: [
                  for (var i = 0; i < 7; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.s8),
                      child: const Skeleton(height: 36),
                    ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }

  Widget _content(List<PackageLicenses> packages) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final chosen = packages.firstWhere(
      (package) => package.package == _chosen,
      orElse: () => packages.first,
    );
    final list = FocusPane(
      debugLabel: 'licences-packages',
      tabStop: true,
      child: ListView.builder(
        // Room for a row's focus ring, which is drawn outside it.
        padding: EdgeInsets.all(
          tokens.focus.ringWidth + tokens.focus.glowWidth,
        ),
        itemCount: packages.length,
        itemExtent: context.scaled(36) + 2,
        itemBuilder: (context, index) {
          final package = packages[index];
          final selected = package == chosen;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Semantics(
              selected: selected,
              child: FocusableSurface(
                ringPlacement: RingPlacement.inside,
                autofocus: selected,
                onPressed: () => setState(() => _chosen = package.package),
                background: selected ? colors.surface3 : null,
                hoverBackground: colors.surface3,
                borderRadius: tokens.radii.smAll,
                semanticLabel: package.package,
                builder: (context, states) => Container(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
                  child: Text(
                    package.package,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.label
                        .withWeight(selected ? 700 : 500)
                        .copyWith(
                          color: selected || states.highlighted
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    final text = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.controlAll,
        border: Border.all(color: colors.border),
      ),
      child: ScrollPane.child(
        // A new package's text starts at its top.
        key: ValueKey(chosen.package),
        semanticLabel: 'The licence of ${chosen.package}',
        padding: EdgeInsets.all(tokens.spacing.s16),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            chosen.text,
            style: tokens.text.caption.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // A phone (ADR-068): the packages above the chosen one's text.
        if (constraints.maxWidth < _sideBySideFrom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: context.scaled(_stackedListHeight), child: list),
              SizedBox(height: tokens.spacing.s12),
              Expanded(child: text),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 260, child: list),
            SizedBox(width: tokens.spacing.s16),
            Expanded(child: text),
          ],
        );
      },
    );
  }
}
