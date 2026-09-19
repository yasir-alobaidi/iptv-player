import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/gallery/gallery_media_sections.dart';
import 'package:iptv_player/design/gallery/gallery_section.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/design/tokens.dart';

/// The Component Gallery: every design-system component in every state,
/// with live switches for accent, density and reduce motion. Debug builds
/// only (see `galleryEnabled`); Phase 1 step 4 puts it at `/dev/gallery`.
///
/// It is fully keyboard navigable, which is also how hard rule 5 is
/// checked by hand.
class GalleryScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  AppAccent _accent = AppAccent.blue;
  AppDensity _density = AppDensity.comfortable;
  bool _reduceMotion = false;
  bool _fieldError = false;

  @override
  Widget build(BuildContext context) {
    final theme = buildAppTheme(
      accent: _accent,
      density: _density,
      reduceMotion: _reduceMotion,
    );

    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final tokens = context.tokens;
          return Scaffold(
            backgroundColor: tokens.colors.bg,
            body: SafeArea(
              child: Column(
                children: [
                  _Toolbar(
                    accent: _accent,
                    density: _density,
                    reduceMotion: _reduceMotion,
                    onAccent: (v) => setState(() => _accent = v),
                    onDensity: (v) => setState(() => _density = v),
                    onReduceMotion: (v) => setState(() => _reduceMotion = v),
                  ),
                  Expanded(
                    child: FocusPane(
                      debugLabel: 'gallery-content',
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(tokens.spacing.s24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1040),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _sections(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sections(BuildContext context) {
    final tokens = context.tokens;
    return [
      GallerySection(
        title: 'Buttons',
        description: 'Primary, secondary, ghost and danger; sizes S, M and L.',
        children: [
          for (final variant in AppButtonVariant.values)
            SpecimenRow(
              children: [
                for (final entry in gallerySurfaceStates.entries)
                  Specimen(
                    label: '${variant.name} · ${entry.key}',
                    states: entry.value,
                    child: AppButton(
                      label: 'Play',
                      icon: AppIcons.play,
                      variant: variant,
                      onPressed: () {},
                    ),
                  ),
                Specimen(
                  label: '${variant.name} · disabled',
                  child: AppButton(
                    label: 'Play',
                    icon: AppIcons.play,
                    variant: variant,
                  ),
                ),
                Specimen(
                  label: '${variant.name} · loading',
                  child: AppButton(
                    label: 'Testing',
                    variant: variant,
                    loading: true,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          SpecimenRow(
            children: [
              for (final size in AppButtonSize.values)
                Specimen(
                  label: 'size ${size.name}',
                  child: AppButton(
                    label: 'Add source',
                    size: size,
                    onPressed: () {},
                  ),
                ),
            ],
          ),
        ],
      ),
      GallerySection(
        title: 'Icon buttons',
        description: 'Tooltip is required; shortcut hint optional.',
        children: [
          SpecimenRow(
            children: [
              for (final entry in gallerySurfaceStates.entries)
                Specimen(
                  label: entry.key,
                  states: entry.value,
                  child: AppIconButton(
                    icon: AppIcons.cast,
                    tooltip: 'Cast',
                    shortcut: 'C',
                    onPressed: () {},
                  ),
                ),
              Specimen(
                label: 'Selected',
                child: AppIconButton(
                  icon: AppIcons.starFilled,
                  tooltip: 'Favorite',
                  shortcut: 'F',
                  selected: true,
                  onPressed: () {},
                ),
              ),
              const Specimen(
                label: 'Disabled',
                child: AppIconButton(icon: AppIcons.cast, tooltip: 'Cast'),
              ),
              Specimen(
                label: 'Bordered',
                child: AppIconButton(
                  icon: AppIcons.cast,
                  tooltip: 'Cast',
                  bordered: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
      GallerySection(
        title: 'Text fields',
        children: [
          SpecimenRow(
            children: [
              SizedBox(
                width: 300,
                child: Specimen(
                  label: 'Default',
                  child: AppTextField(
                    label: 'Server URL',
                    hint: 'http://example.com:8080',
                    errorText: _fieldError
                        ? "That server didn't answer. Check the address."
                        : null,
                  ),
                ),
              ),
              const SizedBox(
                width: 300,
                child: Specimen(
                  label: 'Password (reveal)',
                  child: AppTextField(
                    label: 'Password',
                    hint: 'Required',
                    obscure: true,
                  ),
                ),
              ),
              const SizedBox(
                width: 300,
                child: Specimen(
                  label: 'Disabled',
                  child: AppTextField(
                    label: 'User agent',
                    hint: 'Default',
                    enabled: false,
                  ),
                ),
              ),
              Specimen(
                label: 'Toggle error state',
                child: AppButton(
                  label: _fieldError ? 'Clear error' : 'Show error',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.s,
                  onPressed: () => setState(() => _fieldError = !_fieldError),
                ),
              ),
            ],
          ),
          SpecimenRow(
            children: [
              const Specimen(
                label: 'Search field (input)',
                child: SearchField(width: 360),
              ),
              Specimen(
                label: 'Search field (opens overlay)',
                child: SearchField(width: 360, onTap: () {}),
              ),
            ],
          ),
        ],
      ),
      GallerySection(
        title: 'Chips',
        children: [
          SpecimenRow(
            children: [
              for (final entry in gallerySurfaceStates.entries)
                Specimen(
                  label: entry.key,
                  states: entry.value,
                  child: AppChip(label: 'Action', onPressed: () {}),
                ),
              Specimen(
                label: 'Selected',
                child: AppChip(label: 'All', selected: true, onPressed: () {}),
              ),
              Specimen(
                label: 'With count',
                child: AppChip(label: 'Sports', count: 214, onPressed: () {}),
              ),
              Specimen(
                label: 'Removable',
                child: AppChip(
                  label: 'Downloaded',
                  selected: true,
                  onPressed: () {},
                  onRemove: () {},
                ),
              ),
              const Specimen(
                label: 'Disabled',
                child: AppChip(label: 'Kids', enabled: false),
              ),
            ],
          ),
        ],
      ),
      const GallerySection(
        title: 'Badges',
        children: [
          SpecimenRow(
            children: [
              Specimen(
                label: 'live',
                child: AppBadge('Live', tone: AppBadgeTone.live),
              ),
              Specimen(
                label: 'outline',
                child: AppBadge('4K', tone: AppBadgeTone.outline),
              ),
              Specimen(label: 'neutral', child: AppBadge('FHD')),
              Specimen(
                label: 'accent',
                child: AppBadge('New', tone: AppBadgeTone.accent),
              ),
              Specimen(
                label: 'success',
                child: AppBadge('Original', tone: AppBadgeTone.success),
              ),
              Specimen(
                label: 'warning',
                child: AppBadge('Transcoded', tone: AppBadgeTone.warning),
              ),
            ],
          ),
        ],
      ),
      GallerySection(
        title: 'Keycaps and tooltips',
        children: [
          SpecimenRow(
            children: [
              const Specimen(label: 'Kbd', child: Kbd('Ctrl K')),
              const Specimen(label: 'Kbd · Esc', child: Kbd('Esc')),
              Specimen(
                label: 'Tooltip with shortcut (hover)',
                child: AppTooltip(
                  message: 'Search',
                  shortcut: 'Ctrl K',
                  child: AppButton(
                    label: 'Hover me',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GallerySection(
        title: 'Segmented control',
        children: [
          SpecimenRow(
            children: [
              Specimen(
                label: 'Sort',
                child: SegmentedControl<String>(
                  options: const [
                    SegmentOption(value: 'no', label: 'No.'),
                    SegmentOption(value: 'az', label: 'A–Z'),
                  ],
                  value: 'no',
                  onChanged: (_) {},
                ),
              ),
              Specimen(
                label: 'Disabled',
                child: SegmentedControl<String>(
                  options: const [
                    SegmentOption(value: 'no', label: 'No.'),
                    SegmentOption(value: 'az', label: 'A–Z'),
                  ],
                  value: 'az',
                  enabled: false,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ],
      ),
      const GallerySection(
        title: 'Progress and skeletons',
        children: [
          SpecimenRow(
            children: [
              Specimen(
                label: '0.35',
                child: SizedBox(width: 220, child: ProgressBar(value: 0.35)),
              ),
              Specimen(
                label: 'Indeterminate',
                child: SizedBox(width: 220, child: ProgressBar()),
              ),
              Specimen(
                label: 'Row skeleton',
                child: SizedBox(width: 280, child: SkeletonRow()),
              ),
              Specimen(
                label: 'Poster skeleton',
                child: SkeletonPoster(width: 120),
              ),
            ],
          ),
        ],
      ),
      GallerySection(
        title: 'Empty and error states',
        children: [
          SpecimenRow(
            children: [
              SizedBox(
                width: 460,
                height: 300,
                child: Specimen(
                  label: 'Empty',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.colors.surface2,
                      borderRadius: tokens.radii.mdAll,
                    ),
                    child: EmptyState(
                      icon: AppIcons.download,
                      title: 'Nothing downloading',
                      message:
                          'Press D on a movie or episode to '
                          'download it.',
                      actionLabel: 'Open Movies',
                      onAction: () {},
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 460,
                height: 300,
                child: Specimen(
                  label: 'Error',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.colors.surface2,
                      borderRadius: tokens.radii.mdAll,
                    ),
                    child: ErrorState(
                      title: "Couldn't reach the provider",
                      message: 'Check your connection and try again.',
                      details: _sampleDetails,
                      onRetry: () {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ...mediaSections(context),
      GallerySection(
        title: 'Focus ring',
        description: 'Rows keep scale 1.0; tiles and cards grow to 1.03.',
        children: [
          SpecimenRow(
            children: [
              Specimen(
                label: 'Row (focused)',
                states: const SurfaceStates(focused: true),
                child: SizedBox(
                  width: 260,
                  child: _DemoRow(height: tokens.density.rowHeight),
                ),
              ),
              Specimen(
                label: 'Tile (focused, 1.03)',
                states: const SurfaceStates(focused: true),
                child: FocusableSurface(
                  onPressed: () {},
                  growth: FocusGrowth.tile,
                  background: tokens.colors.surface3,
                  borderRadius: tokens.radii.mdAll,
                  builder: (context, states) =>
                      const SizedBox(width: 120, height: 160),
                ),
              ),
              Specimen(
                label: 'On accent (inverted ring)',
                states: const SurfaceStates(focused: true),
                child: AppButton(label: 'Connect', onPressed: () {}),
              ),
            ],
          ),
        ],
      ),
    ];
  }
}

class _DemoRow extends StatelessWidget {
  const new({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FocusableSurface(
      onPressed: () {},
      background: tokens.colors.surface3,
      borderRadius: tokens.radii.controlAll,
      builder: (context, states) => SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
          child: Row(
            children: [
              Text(
                '201',
                style: tokens.text.caption
                    .withWeight(700)
                    .copyWith(color: tokens.colors.accentBase),
              ),
              SizedBox(width: tokens.spacing.s12),
              Expanded(
                child: Text(
                  'Arena Sports 1',
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.bodyStrong.copyWith(
                    color: tokens.colors.textPrimary,
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

class _Toolbar extends StatelessWidget {
  const new({
    required this.accent,
    required this.density,
    required this.reduceMotion,
    required this.onAccent,
    required this.onDensity,
    required this.onReduceMotion,
  });

  final AppAccent accent;
  final AppDensity density;
  final bool reduceMotion;
  final ValueChanged<AppAccent> onAccent;
  final ValueChanged<AppDensity> onDensity;
  final ValueChanged<bool> onReduceMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return FocusPane(
      debugLabel: 'gallery-toolbar',
      child: Container(
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s24),
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border(bottom: BorderSide(color: colors.borderSubtle)),
        ),
        child: Row(
          children: [
            Text(
              'Component Gallery',
              style: tokens.text.h2.copyWith(color: colors.textPrimary),
            ),
            SizedBox(width: tokens.spacing.s24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final value in AppAccent.values) ...[
                      AppChip(
                        label: value.label,
                        selected: value == accent,
                        onPressed: () => onAccent(value),
                      ),
                      SizedBox(width: tokens.spacing.s8),
                    ],
                    SizedBox(width: tokens.spacing.s8),
                    SegmentedControl<AppDensity>(
                      options: [
                        for (final value in AppDensity.values)
                          SegmentOption(value: value, label: value.label),
                      ],
                      value: density,
                      onChanged: onDensity,
                    ),
                    SizedBox(width: tokens.spacing.s12),
                    AppChip(
                      label: 'Reduce motion',
                      icon: AppIcons.eye,
                      selected: reduceMotion,
                      onPressed: () => onReduceMotion(!reduceMotion),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stand-in for a redacted failure detail (hard rule 3: credentials never
/// reach a log or the UI).
const _sampleDetails =
    'GET http://example.com:8080/player_api.php?username=***&password=***\n'
    'SocketException: Connection refused (errno = 111)';
