import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/shortcuts.dart';
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
import 'package:iptv_player/features/settings/presentation/setting_row.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/settings/presentation/shortcuts_section.dart';
import 'package:iptv_player/features/sources/presentation/categories_manager.dart';
import 'package:iptv_player/features/sources/presentation/sources_settings.dart';

/// Settings (canvas `Settings`): a 248 px sub-navigation card on the left
/// and the chosen section's card beside it. In less room than
/// [twoPanesMinSize] (a phone, a small tablet held upright, a phone on its
/// side; ADR-068), one pane at a time: the list of sections, and a
/// section in its place under "‹ Settings", which goes back to the list.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  /// The sub-navigation card's width (canvas).
  static const navWidth = 248.0;

  /// The least room for the two panes: the section's card keeps over
  /// 400 px beside the list, and a list of rows has the height to be
  /// read in. A desktop's smallest window gives Settings 944 × 576.
  static const twoPanesMinSize = Size(720, 400);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(settingsLocationProvider);
    final sections = SettingsSection.on(ref.watch(formFactorProvider));

    return FocusPane(
      debugLabel: 'screen-settings',
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >= twoPanesMinSize.width &&
                constraints.maxHeight >= twoPanesMinSize.height
            ? _TwoPanes(section: place.section, sections: sections)
            : _OnePane(place: place, sections: sections),
      ),
    );
  }
}

/// The section's own widget, in the traversal its rows want.
Widget _sectionBody(SettingsSection section) =>
    // A form's ↑/↓ go row by row (ADR-050); the categories are a list
    // that moves with Alt+↑/↓ of its own.
    section == SettingsSection.categories
    ? FocusTraversalGroup(
        policy: appTraversalPolicy(),
        child: const CategoriesManager(),
      )
    : RowsTraversalGroup(
        child: switch (section) {
          SettingsSection.sources => const SourcesSettings(),
          SettingsSection.categories => const CategoriesManager(),
          SettingsSection.playback => const PlaybackSettingsSection(),
          SettingsSection.guide => const GuideSettingsSection(),
          SettingsSection.casting => const CastSettingsSection(),
          SettingsSection.downloads => const DownloadSettingsSection(),
          SettingsSection.appearance => const AppearanceSection(),
          SettingsSection.shortcuts => const ShortcutsSection(),
          SettingsSection.about => const AboutSection(),
          SettingsSection.data => const DataSection(),
        },
      );

/// The desktop's, the TV's and a wide tablet's Settings: the list and the
/// section side by side.
class _TwoPanes extends ConsumerWidget {
  const new({required this.section, required this.sections});

  final SettingsSection section;
  final List<SettingsSection> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.s16),
      // A form: in a wide window its rows keep their words and their
      // controls within reach of each other.
      child: PageMeasure(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: SettingsScreen.navWidth,
              child: _SettingsNav(
                current: section,
                onSelect: ref.read(settingsLocationProvider.notifier).show,
                sections: sections,
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
                child: _sectionBody(section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings one pane at a time (ADR-068): the list of sections at full
/// width, or the open section at full width under "‹ Settings". Back —
/// the chip, Esc, the system's Back — returns to the list, on the row of
/// the section it came from.
class _OnePane extends ConsumerStatefulWidget {
  const new({required this.place, required this.sections});

  final SettingsPlace place;
  final List<SettingsSection> sections;

  @override
  ConsumerState<_OnePane> createState() => _OnePaneState();
}

class _OnePaneState extends ConsumerState<_OnePane> {
  /// An open section shorter than this scrolls as a whole (a phone on its
  /// side): its rows and its lists keep room to be read in.
  static const _sectionMinHeight = 420.0;

  final _back = FocusNode(debugLabel: 'Back to Settings');
  final _rows = <SettingsSection, FocusNode>{};

  FocusNode _row(SettingsSection section) => _rows.putIfAbsent(
    section,
    () => FocusNode(debugLabel: 'Settings: ${section.label}'),
  );

  static bool _isOpen(_OnePane pane) =>
      pane.place.opened && pane.sections.contains(pane.place.section);

  bool get _open => _isOpen(widget);

  @override
  void didUpdateWidget(_OnePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved =
        _isOpen(oldWidget) != _open ||
        (_open && oldWidget.place.section != widget.place.section);
    if (!moved) return;
    // The pane in front takes the keyboard: the chip over an opened
    // section, the row of the section left on the list.
    final target = _open ? _back : _row(widget.place.section);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && target.context != null) target.requestFocus();
    });
  }

  @override
  void dispose() {
    _back.dispose();
    for (final node in _rows.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _toList() => ref.read(settingsLocationProvider.notifier).showList();

  /// The system's Back over an open section: back to the list. A dialog
  /// or a page over Settings is the router's to close first.
  Future<bool> _onSystemBack() async {
    if (!mounted || !_open) return false;
    if (GoRouter.of(context).canPop()) return false;
    _toList();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.tokens.spacing;
    if (!_open) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(spacing.s16),
        child: FocusTraversalGroup(
          policy: appTraversalPolicy(),
          child: _SectionList(
            sections: widget.sections,
            current: widget.place.section,
            focusNodeOf: _row,
            onSelect: ref.read(settingsLocationProvider.notifier).show,
          ),
        ),
      );
    }

    final section = widget.place.section;
    final page = Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.s16,
        spacing.s8,
        spacing.s16,
        spacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _BackChip(focusNode: _back, onPressed: _toList),
          ),
          SizedBox(height: spacing.s12),
          Expanded(
            // Laid out for a finger: buttons and segments 44 px high,
            // segmented controls across the row, controls under words.
            child: TouchTargets(
              child: SegmentedFill(
                child: SettingsOnePane(
                  onePane: true,
                  // Another section is another page.
                  child: KeyedSubtree(
                    key: ValueKey(section),
                    child: _sectionBody(section),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return BackButtonListener(
      onBackButtonPressed: _onSystemBack,
      child: Actions(
        actions: {
          CloseTopIntent: CallbackAction<CloseTopIntent>(
            onInvoke: (_) {
              _toList();
              return null;
            },
          ),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final least =
                context.scaled(_sectionMinHeight) +
                context.scaled(touchTargetSize);
            if (constraints.maxHeight >= least) return page;
            return SingleChildScrollView(
              child: SizedBox(height: least, child: page),
            );
          },
        ),
      ),
    );
  }
}

/// "‹ Settings" over an open section (a title's "‹ Movies" chip, at a
/// finger's height).
class _BackChip extends StatelessWidget {
  const new({required this.focusNode, required this.onPressed});

  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      focusNode: focusNode,
      onPressed: onPressed,
      borderRadius: tokens.radii.pillAll,
      semanticLabel: 'Back to Settings',
      builder: (context, states) => Container(
        height: context.scaled(touchTargetSize),
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.s12,
          0,
          tokens.spacing.s16,
          0,
        ),
        decoration: BoxDecoration(
          color: states.highlighted ? colors.surface3 : colors.surface1,
          borderRadius: tokens.radii.pillAll,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.chevronLeft,
              size: 18,
              color: colors.textSecondary,
            ),
            SizedBox(width: tokens.spacing.s4 + 2),
            Text(
              'Settings',
              style: tokens.text.label
                  .withWeight(700)
                  .copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sections as a phone's list (ADR-068): a card of rows a finger
/// high, each the section's name and a chevron; the section opened last
/// is marked as the two panes' list marks it.
class _SectionList extends StatelessWidget {
  const new({
    required this.sections,
    required this.current,
    required this.focusNodeOf,
    required this.onSelect,
  });

  final List<SettingsSection> sections;
  final SettingsSection current;
  final FocusNode Function(SettingsSection section) focusNodeOf;
  final ValueChanged<SettingsSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return _Card(
      padding: EdgeInsets.all(tokens.spacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, section) in sections.indexed) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: tokens.spacing.s12,
                endIndent: tokens.spacing.s12,
                color: colors.surface3,
              ),
            FocusableSurface(
              focusNode: focusNodeOf(section),
              ringPlacement: RingPlacement.inside,
              onPressed: () => onSelect(section),
              borderRadius: tokens.radii.smAll,
              hoverBackground: colors.surface2,
              semanticLabel: section.label,
              builder: (context, states) => ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: context.scaled(tokens.spacing.s48 + 4),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.s12,
                    vertical: tokens.spacing.s8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          section.label,
                          style: tokens.text.label
                              .withWeight(section == current ? 700 : 600)
                              .copyWith(color: colors.textPrimary),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.s12),
                      AppIcon(
                        AppIcons.chevronRight,
                        size: 18,
                        color: states.highlighted
                            ? colors.textSecondary
                            : colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
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
/// the [body], then an optional [footer] note. Narrower than
/// [actionsBesideMinWidth] (a phone) the actions go under the title.
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

  /// The least width at which the actions sit beside the title.
  static const actionsBesideMinWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.panelTitle.copyWith(color: colors.textPrimary),
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: tokens.spacing.s4),
          Text(
            subtitle!,
            style: tokens.text.caption.copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
    final top = SettingsOnePane.of(context) && actions.isNotEmpty
        ? LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= actionsBesideMinWidth
                ? _besides(context, heading)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      SizedBox(height: tokens.spacing.s12),
                      Wrap(
                        spacing: tokens.spacing.s8,
                        runSpacing: tokens.spacing.s8,
                        children: actions,
                      ),
                    ],
                  ),
          )
        : _besides(context, heading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        SizedBox(height: tokens.spacing.s16 + 2),
        Expanded(child: body),
        if (footer != null) ...[SizedBox(height: tokens.spacing.s12), footer!],
      ],
    );
  }

  Widget _besides(BuildContext context, Widget heading) {
    final spacing = context.tokens.spacing;
    return Row(
      children: [
        Expanded(child: heading),
        for (final (index, action) in actions.indexed) ...[
          SizedBox(width: index == 0 ? spacing.s16 : spacing.s8),
          action,
        ],
      ],
    );
  }
}
