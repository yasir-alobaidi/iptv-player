import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/gallery/gallery_section.dart';
import 'package:iptv_player/design/tokens.dart';

/// The step 3b half of the gallery: media, overlay, and download
/// components, plus the canvas icon set.
List<Widget> mediaSections(BuildContext context) {
  final tokens = context.tokens;
  final colors = tokens.colors;

  return [
    GallerySection(
      title: 'Channel rows and logos',
      description:
          'The monogram tile and its color come from the channel name.',
      children: [
        SpecimenRow(
          children: [
            for (final name in const [
              'Arena Sports 1',
              'Vista Movies',
              'City News',
              'Kids World',
            ])
              Specimen(
                label: name,
                child: ChannelLogo(name: name),
              ),
            const Specimen(
              label: 'Large',
              child: ChannelLogo(name: 'Horizon Cinema', size: 64),
            ),
          ],
        ),
        for (final entry in gallerySurfaceStates.entries)
          SpecimenRow(
            children: [
              SizedBox(
                width: 420,
                child: Specimen(
                  label: entry.key,
                  states: entry.value,
                  child: ChannelRow(
                    name: 'Arena Sports 1',
                    number: 201,
                    nowTitle: 'Premier League: Arsenal v Chelsea',
                    progress: 0.42,
                    badges: const [AppBadge('FHD', tone: AppBadgeTone.outline)],
                    onPressed: () {},
                    onMenu: () {},
                    onToggleFavorite: () {},
                  ),
                ),
              ),
            ],
          ),
        SpecimenRow(
          children: [
            SizedBox(
              width: 420,
              child: Specimen(
                label: 'Favorited, no guide data',
                child: ChannelRow(
                  name: 'City News',
                  number: 202,
                  isFavorite: true,
                  onPressed: () {},
                  onToggleFavorite: () {},
                ),
              ),
            ),
            SizedBox(
              width: 420,
              child: Specimen(
                label: 'Selected (previewing)',
                child: ChannelRow(
                  name: 'Vista Movies',
                  number: 203,
                  nowTitle: 'Copper Hollow',
                  progress: 0.8,
                  selected: true,
                  onPressed: () {},
                  onToggleFavorite: () {},
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    GallerySection(
      title: 'Cards and rails',
      description: 'Cards grow to 1.03 on focus; rails virtualize.',
      children: [
        SpecimenRow(
          children: [
            Specimen(
              label: 'Poster',
              child: PosterCard(
                title: 'Copper Hollow',
                meta: '2025',
                rating: 7.1,
                onPressed: () {},
              ),
            ),
            Specimen(
              label: 'Poster · focused',
              states: const SurfaceStates(focused: true),
              child: PosterCard(
                title: 'The Orchard Line',
                meta: '2025',
                rating: 6.8,
                onPressed: () {},
              ),
            ),
            Specimen(
              label: 'Poster · progress and badge',
              child: PosterCard(
                title: 'Night Harbour',
                meta: '2024',
                progress: 0.35,
                badge: const AppBadge('New', tone: AppBadgeTone.accent),
                onPressed: () {},
              ),
            ),
            Specimen(
              label: 'Landscape',
              child: LandscapeCard(
                title: 'The Long Way Home',
                subtitle: 'S1 · E3 · 49 min',
                progress: 0.62,
                onPressed: () {},
              ),
            ),
          ],
        ),
        SectionHeader(
          title: 'Continue watching',
          subtitle: '6 items',
          onSeeAll: () {},
        ),
        SizedBox(
          height: 240,
          child: HorizontalRail(
            height: 240,
            itemCount: 12,
            itemBuilder: (context, index) => PosterCard(
              title: 'Feature ${index + 1}',
              meta: '202${index % 6}',
              rating: 6 + (index % 4) * 0.4,
              width: 120,
              onPressed: () {},
            ),
          ),
        ),
      ],
    ),
    const GallerySection(
      title: 'Sliders',
      children: [
        SpecimenRow(
          children: [
            SizedBox(
              width: 260,
              child: Specimen(label: 'Volume', child: _SliderDemo()),
            ),
            SizedBox(
              width: 360,
              child: Specimen(
                label: 'Seek with buffered range and time bubble',
                child: _SliderDemo(seek: true),
              ),
            ),
          ],
        ),
      ],
    ),
    GallerySection(
      title: 'Banners and toasts',
      children: [
        for (final tone in BannerTone.values)
          SpecimenRow(
            children: [
              SizedBox(
                width: 620,
                child: Specimen(
                  label: tone.name,
                  child: AppBanner(
                    message: switch (tone) {
                      BannerTone.info =>
                        "You're offline — downloads and local files "
                            'still play',
                      BannerTone.warning => 'Your account expires in 3 days',
                      BannerTone.error => "Couldn't reach Home provider",
                      BannerTone.success => 'Guide updated',
                    },
                    tone: tone,
                    actionLabel: 'Open Library',
                    onAction: () {},
                    onDismiss: () {},
                  ),
                ),
              ),
            ],
          ),
        SpecimenRow(
          children: [
            for (final tone in ToastTone.values)
              Specimen(
                label: 'Toast · ${tone.name}',
                child: AppToast(
                  message: switch (tone) {
                    ToastTone.neutral => 'Added to favorites',
                    ToastTone.success => 'Download finished',
                    ToastTone.error => 'Download failed',
                  },
                  tone: tone,
                  actionLabel: tone == ToastTone.error ? 'Retry' : null,
                  onAction: tone == ToastTone.error ? () {} : null,
                ),
              ),
          ],
        ),
      ],
    ),
    GallerySection(
      title: 'Dialog, sheet and menu',
      children: [
        SpecimenRow(
          children: [
            SizedBox(
              width: 560,
              height: 300,
              child: Specimen(
                label: 'Dialog (destructive)',
                child: AppDialog(
                  title: 'Delete downloaded file?',
                  subtitle: 'This moves the file to the trash.',
                  primaryLabel: 'Delete file',
                  destructive: true,
                  secondaryLabel: 'Cancel',
                  onPrimary: () {},
                  onSecondary: () {},
                  onClose: () {},
                  child: Text(
                    'Copper Hollow · 3.4 GB',
                    style: tokens.text.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Specimen(
              label: 'Item menu',
              child: AppMenu(
                items: [
                  AppMenuItem(
                    label: 'Play',
                    icon: AppIcons.play,
                    shortcut: 'Enter',
                    onPressed: () {},
                  ),
                  AppMenuItem(
                    label: 'Add to favorites',
                    icon: AppIcons.star,
                    shortcut: 'F',
                    onPressed: () {},
                  ),
                  AppMenuItem(
                    label: 'Cast',
                    icon: AppIcons.cast,
                    shortcut: 'C',
                    onPressed: () {},
                  ),
                  const AppMenuItem.separator(),
                  AppMenuItem(
                    label: 'Show in folder',
                    icon: AppIcons.folder,
                    onPressed: () {},
                  ),
                  AppMenuItem(
                    label: 'Delete file',
                    icon: AppIcons.close,
                    destructive: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
    GallerySection(
      title: 'Casting',
      children: [
        SpecimenRow(
          children: [
            SizedBox(
              width: 900,
              child: Specimen(
                label: 'Casting bar',
                child: CastingBar(
                  title: 'Arena Sports 1',
                  deviceName: 'Living Room TV',
                  subtitle: '1080p · 50 fps',
                  quality: StreamQuality.original,
                  onPlayPause: () {},
                  onStop: () {},
                ),
              ),
            ),
            SizedBox(
              width: 900,
              child: Specimen(
                label: 'Casting bar · transcoded, reconnecting, VOD',
                child: CastingBar(
                  title: 'Copper Hollow',
                  deviceName: 'Living Room TV',
                  quality: StreamQuality.transcoded,
                  qualityDetail: 'This TV cannot play HEVC',
                  progress: 0.28,
                  reconnecting: true,
                  isPlaying: false,
                  onPlayPause: () {},
                  onStop: () {},
                ),
              ),
            ),
          ],
        ),
        SpecimenRow(
          children: [
            for (final quality in StreamQuality.values)
              Specimen(label: quality.name, child: QualityBadge(quality)),
            const Specimen(
              label: 'Reconnecting',
              child: ReconnectingPill(attempt: 2),
            ),
          ],
        ),
      ],
    ),
    GallerySection(
      title: 'Downloads',
      children: [
        SpecimenRow(
          children: [
            for (final state in DownloadState.values)
              Specimen(
                label: state.name,
                child: DownloadButton(
                  state: state,
                  progress: 0.42,
                  onPressed: () {},
                ),
              ),
            Specimen(
              label: 'With label',
              child: DownloadButton(
                state: DownloadState.downloading,
                progress: 0.42,
                showLabel: true,
                onPressed: () {},
              ),
            ),
          ],
        ),
        SpecimenRow(
          children: [
            SizedBox(
              width: 620,
              child: Specimen(
                label: 'Downloading',
                child: DownloadRow(
                  title: 'The Long Way Home',
                  subtitle: 'S1 · E3',
                  state: DownloadState.downloading,
                  progress: 0.42,
                  speed: '4.2 MB/s',
                  timeLeft: '6 min',
                  size: '3.4 GB',
                  reorderable: true,
                  onPressed: () {},
                  onPrimaryAction: () {},
                  onMenu: () {},
                ),
              ),
            ),
            SizedBox(
              width: 620,
              child: Specimen(
                label: 'Failed',
                child: DownloadRow(
                  title: 'Copper Hollow',
                  state: DownloadState.failed,
                  errorMessage: 'The source stopped responding',
                  onPressed: () {},
                  onPrimaryAction: () {},
                ),
              ),
            ),
            const SizedBox(
              width: 420,
              child: Specimen(
                label: 'Storage meter',
                child: StorageMeter(
                  usedLabel: 'Downloads 42.3 GB',
                  freeLabel: '118 GB free',
                  usedFraction: 0.26,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    GallerySection(
      title: 'Icons',
      description:
          'Extracted from the canvas by tools/extract_icons.dart; '
          'tinted through currentColor.',
      children: [
        Wrap(
          spacing: tokens.spacing.s12,
          runSpacing: tokens.spacing.s12,
          children: [
            for (final icon in AppIcons.values)
              SizedBox(
                width: 84,
                child: Column(
                  children: [
                    AppIcon(icon, color: colors.textPrimary),
                    SizedBox(height: tokens.spacing.s4 + 2),
                    Text(
                      icon.asset,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tokens.text.micro.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  ];
}

class _SliderDemo extends StatefulWidget {
  const new({this.seek = false});

  final bool seek;

  @override
  State<_SliderDemo> createState() => _SliderDemoState();
}

class _SliderDemoState extends State<_SliderDemo> {
  double _value = 0.4;

  @override
  Widget build(BuildContext context) => AppSlider(
    value: _value,
    bufferedValue: widget.seek ? 0.62 : null,
    semanticLabel: widget.seek ? 'Seek' : 'Volume',
    bubbleLabel: widget.seek ? _timecode : null,
    onChanged: (value) => setState(() => _value = value),
  );

  static String _timecode(double value) {
    final seconds = (value * 5400).round();
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
