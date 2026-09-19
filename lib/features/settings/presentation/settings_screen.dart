import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/presentation/categories_manager.dart';
import 'package:iptv_player/features/sources/presentation/sources_settings.dart';

/// Settings (canvas `Settings`): a 248 px sub-navigation card on the left
/// and the chosen section's card beside it. Phase 2 builds Sources and
/// Categories; the other sections say which phase brings them.
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: navWidth,
              child: _SettingsNav(
                current: section,
                onSelect: ref.read(settingsLocationProvider.notifier).show,
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
                child: FocusTraversalGroup(
                  child: switch (section) {
                    SettingsSection.sources => const SourcesSettings(),
                    SettingsSection.categories => const CategoriesManager(),
                    _ => _ComingLater(section: section),
                  },
                ),
              ),
            ),
          ],
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
  const new({required this.current, required this.onSelect});

  final SettingsSection current;
  final ValueChanged<SettingsSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return _Card(
      padding: EdgeInsets.all(tokens.spacing.s12),
      child: FocusTraversalGroup(
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
              for (final section in SettingsSection.values)
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
        onPressed: onPressed,
        borderRadius: tokens.radii.smAll,
        background: selected ? colors.surface3 : null,
        hoverBackground: colors.surface2,
        semanticLabel: section.label,
        builder: (context, states) => SizedBox(
          height: tokens.spacing.s40,
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
                    if (section.phase != null)
                      Text(
                        'Phase ${section.phase}',
                        style: tokens.text.labelSmall.copyWith(
                          color: colors.textDisabled,
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

/// A section a later phase builds. Still a card with a title, so the
/// panel never looks broken.
class _ComingLater extends StatelessWidget {
  const new({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    final summary = switch (section) {
      SettingsSection.playback =>
        'Buffering, hardware decoding, deinterlacing, preferred audio and '
            'subtitle languages.',
      SettingsSection.casting =>
        'Known devices, HEVC and Dolby options, and firewall help.',
      SettingsSection.downloads =>
        'Download folder, downloads at a time, speed limit and library '
            'folders.',
      SettingsSection.guide =>
        'Guide links, refresh time, time offset and channel matching.',
      SettingsSection.appearance =>
        'Accent colour, density, reduce motion and the clock format.',
      SettingsSection.shortcuts => 'Every keyboard shortcut in one place.',
      SettingsSection.data =>
        'Clear the image cache or the guide, and export or import settings.',
      SettingsSection.about => 'Version, the log viewer and Copy diagnostics.',
      SettingsSection.sources || SettingsSection.categories => '',
    };
    return SettingsPanel(
      title: section.label,
      body: EmptyState(
        icon: AppIcons.settings,
        title: '${section.label} comes in Phase ${section.phase}',
        message: summary,
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
