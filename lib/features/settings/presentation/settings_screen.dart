import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/presentation/cast_settings_section.dart';
import 'package:iptv_player/features/downloads/presentation/download_settings_section.dart';
import 'package:iptv_player/features/guide/presentation/guide_settings.dart';
import 'package:iptv_player/features/playback/presentation/playback_settings.dart';
import 'package:iptv_player/features/settings/presentation/about_section.dart';
import 'package:iptv_player/features/settings/presentation/appearance_section.dart';
import 'package:iptv_player/features/settings/presentation/data_section.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/settings/presentation/shortcuts_section.dart';
import 'package:iptv_player/features/sources/presentation/categories_manager.dart';
import 'package:iptv_player/features/sources/presentation/sources_settings.dart';

/// Settings (canvas `Settings`): a 248 px sub-navigation card on the left
/// and the chosen section's card beside it.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  /// The sub-navigation card's width (canvas).
  static const navWidth = 248.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final section = ref.watch(settingsLocationProvider).section;

    return FocusPane(
      debugLabel: 'screen-settings',
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s16),
        // A form: in a wide window its rows keep their words and their
        // controls within reach of each other.
        child: PageMeasure(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: navWidth,
                child: _SettingsNav(
                  current: section,
                  onSelect: ref.read(settingsLocationProvider.notifier).show,
                  sections: SettingsSection.on(ref.watch(formFactorProvider)),
                ),
              ),
              SizedBox(width: tokens.spacing.s16),
              Expanded(
                child: _Card(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.s24 + 4,
                    tokens.spacing.s20 + 2,
                    tokens.spacing.s24 + 4,
                    tokens.spacing.s20,
                  ),
                  // A form's ↑/↓ go row by row (ADR-050); the categories
                  // are a list that moves with Alt+↑/↓ of its own.
                  child: section == SettingsSection.categories
                      ? FocusTraversalGroup(
                          policy: appTraversalPolicy(),
                          child: const CategoriesManager(),
                        )
                      : RowsTraversalGroup(
                          child: switch (section) {
                            SettingsSection.sources => const SourcesSettings(),
                            SettingsSection.categories =>
                              const CategoriesManager(),
                            SettingsSection.playback =>
                              const PlaybackSettingsSection(),
                            SettingsSection.guide =>
                              const GuideSettingsSection(),
                            SettingsSection.casting =>
                              const CastSettingsSection(),
                            SettingsSection.downloads =>
                              const DownloadSettingsSection(),
                            SettingsSection.appearance =>
                              const AppearanceSection(),
                            SettingsSection.shortcuts =>
                              const ShortcutsSection(),
                            SettingsSection.about => const AboutSection(),
                            SettingsSection.data => const DataSection(),
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const new({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.colors.surface1,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: tokens.colors.borderSubtle),
      ),
      child: child,
    );
  }
}

/// The section list. Choosing one keeps focus on it, as the nav rail does
/// (docs/05): the user is browsing the list; Right or Tab moves into the
/// section.
class _SettingsNav extends StatelessWidget {
  const new({
    required this.current,
    required this.onSelect,
    required this.sections,
  });

  final SettingsSection current;
  final ValueChanged<SettingsSection> onSelect;
  final List<SettingsSection> sections;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return _Card(
      padding: EdgeInsets.all(tokens.spacing.s12),
      child: FocusTraversalGroup(
        policy: appTraversalPolicy(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.s8 + 2,
                  tokens.spacing.s8,
                  tokens.spacing.s8 + 2,
                  tokens.spacing.s8 + 2,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    'SETTINGS',
                    style: tokens.text.overline.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ),
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _NavItem(
                    section: section,
                    selected: section == current,
                    onPressed: () => onSelect(section),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const new({
    required this.section,
    required this.selected,
    required this.onPressed,
  });

  final SettingsSection section;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Semantics(
      selected: selected,
      child: FocusableSurface(
        ringPlacement: RingPlacement.inside,
        onPressed: onPressed,
        borderRadius: tokens.radii.smAll,
        background: selected ? colors.surface3 : null,
        hoverBackground: colors.surface2,
        semanticLabel: section.label,
        builder: (context, states) => SizedBox(
          height: context.scaled(tokens.spacing.s40),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Always in the tree, transparent when unselected: see the
              // nav rail's indicator (ADR-008).
              Positioned(
                left: 0,
                top: tokens.spacing.s8 + 2,
                bottom: tokens.spacing.s8 + 2,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: selected ? colors.accentBase : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.s8 + 2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.label
                            .withWeight(selected ? 700 : 600)
                            .copyWith(
                              color: selected || states.highlighted
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's content: its title with optional [actions] beside it, then
/// the [body], then an optional [footer] note.
class SettingsPanel extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.footer,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.panelTitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: tokens.spacing.s4),
                    Text(
                      subtitle!,
                      style: tokens.text.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final (index, action) in actions.indexed) ...[
              SizedBox(
                width: index == 0 ? tokens.spacing.s16 : tokens.spacing.s8,
              ),
              action,
            ],
          ],
        ),
        SizedBox(height: tokens.spacing.s16 + 2),
        Expanded(child: body),
        if (footer != null) ...[SizedBox(height: tokens.spacing.s12), footer!],
      ],
    );
  }
}
