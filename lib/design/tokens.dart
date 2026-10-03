import 'package:flutter/material.dart';

/// User-selectable accent (docs/05). Blue is the default and the only one
/// the design canvas shows; the other four are derived from it the same way
/// (hover = 26 % toward white, pressed = 16 % toward [AppColors.bg]).
enum AppAccent {
  blue(
    base: Color(0xFF5B8CFF),
    hover: Color(0xFF86A9FF),
    pressed: Color(0xFF4A78E6),
    deep: Color(0xFF3A5FD0),
    label: 'Blue',
  ),
  violet(
    base: Color(0xFF8B6CFF),
    hover: Color(0xFFA992FF),
    pressed: Color(0xFF765DD9),
    deep: Color(0xFF644FB7),
    label: 'Violet',
  ),
  teal(
    base: Color(0xFF22C3B5),
    hover: Color(0xFF5BD3C8),
    pressed: Color(0xFF1EA69B),
    deep: Color(0xFF1B8C84),
    label: 'Teal',
  ),
  amber(
    base: Color(0xFFFFB020),
    hover: Color(0xFFFFC55A),
    pressed: Color(0xFFD8961D),
    deep: Color(0xFFB67F1B),
    label: 'Amber',
  ),
  rose(
    base: Color(0xFFFF5C8A),
    hover: Color(0xFFFF86A8),
    pressed: Color(0xFFD84F76),
    deep: Color(0xFFB64465),
    label: 'Rose',
  );

  new({
    required this.base,
    required this.hover,
    required this.pressed,
    required this.deep,
    required this.label,
  });

  final Color base;
  final Color hover;
  final Color pressed;

  /// Darkest step, used for the app mark gradient.
  final Color deep;
  final String label;
}

/// Row density (docs/05: Comfortable 56 px, Compact 44 px).
enum AppDensity {
  comfortable(rowHeight: 56, label: 'Comfortable'),
  compact(rowHeight: 44, label: 'Compact');

  new({required this.rowHeight, required this.label});

  final double rowHeight;
  final String label;
}

/// Dark palette. Values come from docs/05 and the design canvas; a light
/// theme would supply a second instance rather than changing these.
@immutable
class AppColors {
  const new({required this.accent});

  /// The accent the user picked; every accent-derived color reads from it.
  final AppAccent accent;

  // Surfaces.
  Color get bg => const Color(0xFF0A0C10);

  /// Between [bg] and [surface1]: a programme that has ended, on the
  /// Guide grid's card (canvas `Guide`).
  Color get surfaceSunken => const Color(0xFF0E1116);
  Color get surface1 => const Color(0xFF11141A);
  Color get surface2 => const Color(0xFF171B23);
  Color get surface3 => const Color(0xFF1F2430);

  // Lines. borderSubtle divides panels from the background (canvas);
  // border outlines controls; borderStrong outlines badges.
  Color get borderSubtle => const Color(0xFF1B2029);
  Color get border => const Color(0xFF2A3040);
  Color get borderStrong => const Color(0xFF3A4254);

  // Text.
  Color get textPrimary => const Color(0xFFF3F5F9);
  Color get textEmphasis => const Color(0xFFC9D0DC);
  Color get textSecondary => const Color(0xFFA7AFBD);
  Color get textTertiary => const Color(0xFF6C7485);
  Color get textDisabled => const Color(0xFF4A5162);

  // Accent.
  Color get accentBase => accent.base;
  Color get accentHover => accent.hover;
  Color get accentPressed => accent.pressed;
  Color get accentDeep => accent.deep;
  Color get onAccent => const Color(0xFFFFFFFF);

  /// Tinted fill and outline for selected chips (canvas: 16 % / 50 %).
  Color get accentSoft => accent.base.withValues(alpha: 0.16);
  Color get accentSoftBorder => accent.base.withValues(alpha: 0.5);

  // Status.
  Color get live => const Color(0xFFFF4D5E);
  Color get success => const Color(0xFF2FD27A);
  Color get warning => const Color(0xFFFFB547);
  Color get danger => const Color(0xFFFF5C5C);

  /// Overlay over video (docs/05: black at 60 %).
  Color get scrim => const Color(0xFF000000).withValues(alpha: 0.6);

  /// Behind and around the picture (letterbox).
  Color get video => const Color(0xFF000000);

  /// Badges and small controls laid over video (canvas: bg at 70 %).
  Color get videoChip => bg.withValues(alpha: 0.7);

  AppColors copyWith({AppAccent? accent}) =>
      AppColors(accent: accent ?? this.accent);
}

/// Spacing scale (docs/05: 4 → 64). Named by value so call sites never
/// have to guess what "md" means.
@immutable
class AppSpacing {
  const new();

  double get s4 => 4;
  double get s8 => 8;
  double get s12 => 12;
  double get s16 => 16;
  double get s20 => 20;
  double get s24 => 24;
  double get s32 => 32;
  double get s40 => 40;
  double get s48 => 48;
  double get s64 => 64;
}

/// Corner radii. [control] is the canvas's radius for buttons, inputs and
/// rows, which docs/05 did not have (ADR-008).
@immutable
class AppRadii {
  const new();

  double get xs => 6;
  double get sm => 8;
  double get control => 10;
  double get md => 12;
  double get lg => 16;
  double get pill => 999;

  BorderRadius get xsAll => BorderRadius.circular(xs);
  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get controlAll => BorderRadius.circular(control);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Bundled font families. Both are variable fonts on the `wght` axis, so a
/// weight is set with [FontWeight] *and* [FontVariation] (ADR-008).
abstract final class AppFonts {
  static const sans = 'Manrope';
  static const mono = 'JetBrains Mono';
}

TextStyle _font(
  String family,
  double size,
  double lineHeight,
  int weight, {
  double? letterSpacing,
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  height: lineHeight / size,
  fontWeight: FontWeight.values.firstWhere((w) => w.value == weight),
  fontVariations: [FontVariation('wght', weight.toDouble())],
  letterSpacing: letterSpacing,
  // Times, channel numbers and durations must not jitter (docs/05).
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Type scale: docs/05 plus the 12, 14 and 17 px styles taken from the
/// canvas. Sizes are size/line-height in px.
@immutable
class AppTypography {
  const new();

  /// 40/48 — details page titles.
  TextStyle get display => _font(AppFonts.sans, 40, 48, 700);

  /// 52/58 — a movie's title on its page (canvas `Movie details`).
  TextStyle get movieTitle =>
      _font(AppFonts.sans, 52, 58, 800, letterSpacing: -0.8);

  /// 44/50 — a series' title on its page (canvas `Series details`).
  TextStyle get seriesTitle =>
      _font(AppFonts.sans, 44, 50, 800, letterSpacing: -0.6);

  /// 34/42 — onboarding step titles (canvas).
  TextStyle get hero => _font(AppFonts.sans, 34, 42, 800, letterSpacing: -0.5);

  /// 28/36 — screen titles on wide layouts.
  TextStyle get h1 => _font(AppFonts.sans, 28, 36, 700);

  /// 24/32 — a Settings section's title (canvas `Settings`).
  TextStyle get panelTitle =>
      _font(AppFonts.sans, 24, 32, 800, letterSpacing: -0.3);

  /// 22/30 — the shell's screen title (canvas weight 700, not docs/05 600).
  TextStyle get h2 => _font(AppFonts.sans, 22, 30, 700, letterSpacing: -0.2);

  /// 22/30 — a figure that leads a summary ("17 of 412 on", canvas).
  TextStyle get stat => _font(AppFonts.sans, 22, 30, 800);

  /// 20/28 — a row's title on Home ("Continue watching", canvas `Home`).
  TextStyle get sectionTitle =>
      _font(AppFonts.sans, 20, 28, 700, letterSpacing: -0.2);

  /// 20/28 — a result card's verdict ("Connected", canvas).
  TextStyle get titleLarge => _font(AppFonts.sans, 20, 28, 800);

  /// 18/26 — card and dialog titles.
  TextStyle get h3 => _font(AppFonts.sans, 18, 26, 600);

  /// 17/24 — canvas section and card titles.
  TextStyle get titleSmall => _font(AppFonts.sans, 17, 24, 800);

  /// 15/22 — general text.
  TextStyle get body => _font(AppFonts.sans, 15, 22, 400);

  /// 15/22 — list primary text (canvas weight 700, not docs/05 600).
  TextStyle get bodyStrong => _font(AppFonts.sans, 15, 22, 700);

  /// 14/20 — canvas control labels.
  TextStyle get label => _font(AppFonts.sans, 14, 20, 600);

  /// 15/22 — filled button labels (canvas weight 800).
  TextStyle get button => _font(AppFonts.sans, 15, 22, 800);

  /// 14/20 — small button labels (canvas weight 800).
  TextStyle get buttonSmall => _font(AppFonts.sans, 14, 20, 800);

  /// 13/18 — metadata.
  TextStyle get caption => _font(AppFonts.sans, 13, 18, 500);

  /// 12/16 — canvas counts and secondary metadata.
  TextStyle get labelSmall => _font(AppFonts.sans, 12, 16, 600);

  /// 12/16 — the Guide's programme times and channel numbers (canvas
  /// weight 400).
  TextStyle get small => _font(AppFonts.sans, 12, 16, 400);

  /// 12/16 — group headings inside a panel ("DOWNLOADS", canvas
  /// `Settings`); callers upper-case the text.
  TextStyle get overline =>
      _font(AppFonts.sans, 12, 16, 800, letterSpacing: 0.6);

  /// 19/26 — the text typed into search (canvas `Search`).
  TextStyle get searchQuery => _font(AppFonts.sans, 19, 26, 600);

  /// 11/14 — search's group headings ("CHANNELS", canvas `Search`).
  TextStyle get searchHeading =>
      _font(AppFonts.sans, 11, 14, 800, letterSpacing: 0.6);

  /// 11/14 — badges (uppercase, +0.4 tracking).
  TextStyle get micro => _font(AppFonts.sans, 11, 14, 600, letterSpacing: 0.4);

  /// 13/18 — stream info and diagnostics.
  TextStyle get mono => _font(AppFonts.mono, 13, 18, 500);

  /// 11/14 — keycaps.
  TextStyle get monoMicro => _font(AppFonts.mono, 11, 14, 500);

  /// 40/48 — what plays on the TV (canvas `Casting`).
  TextStyle get castTitle =>
      _font(AppFonts.sans, 40, 48, 800, letterSpacing: -0.6);

  /// 13/18 — "PLAYING ON LIVING ROOM TV" (canvas `Casting`); callers
  /// upper-case the text.
  TextStyle get castKicker =>
      _font(AppFonts.sans, 13, 18, 800, letterSpacing: 0.8);

  /// 12/16 — the quality tag ("ORIGINAL QUALITY", canvas `Casting`).
  TextStyle get qualityTag =>
      _font(AppFonts.sans, 12, 16, 800, letterSpacing: 0.5);
}

/// Durations and curves (docs/05). [reduceMotion] shortens everything and
/// turns off scale and shimmer effects.
@immutable
class AppMotion {
  const new({required this.reduceMotion});

  final bool reduceMotion;

  Duration get fast => reduceMotion ? const Duration(milliseconds: 60) : _fast;
  Duration get base => reduceMotion ? const Duration(milliseconds: 80) : _base;
  Duration get slow => reduceMotion ? const Duration(milliseconds: 80) : _slow;
  Duration get osdIn =>
      reduceMotion ? const Duration(milliseconds: 60) : _osdIn;
  Duration get osdOut =>
      reduceMotion ? const Duration(milliseconds: 80) : _osdOut;

  Curve get fastCurve => Curves.easeOut;
  Curve get baseCurve => Curves.easeOutCubic;
  Curve get slowCurve => Curves.easeInOutCubic;

  /// False when the user asked for reduced motion: no focus scale, no
  /// skeleton shimmer.
  bool get allowScale => !reduceMotion;
  bool get allowShimmer => !reduceMotion;

  static const _fast = Duration(milliseconds: 120);
  static const _base = Duration(milliseconds: 200);
  static const _slow = Duration(milliseconds: 320);
  static const _osdIn = Duration(milliseconds: 180);
  static const _osdOut = Duration(milliseconds: 240);

  AppMotion copyWith({bool? reduceMotion}) =>
      AppMotion(reduceMotion: reduceMotion ?? this.reduceMotion);
}

/// Focus ring geometry. The canvas draws a 2 px ring plus a 4 px glow at
/// 25 %; on an accent-filled surface the ring inverts to [AppColors
/// .textPrimary] with a 5 px glow at 35 %, because accent-on-accent is
/// invisible.
@immutable
class AppFocusTokens {
  const new();

  double get ringWidth => 2;
  double get glowWidth => 4;
  double get glowOpacity => 0.25;
  double get onAccentGlowWidth => 5;
  double get onAccentGlowOpacity => 0.35;

  /// Tiles and cards grow on focus; rows stay at 1.0 (docs/05).
  double get tileScale => 1.03;
}

/// The details pages' measures (canvas `Movie details`, `Series
/// details`); sizes only they use.
@immutable
class AppDetailsTokens {
  const new();

  /// A movie's poster: 240 × 360.
  Size get moviePoster => const Size(240, 360);

  /// A series' poster: 200 × 300.
  Size get seriesPoster => const Size(200, 300);

  /// Around a movie's page: its poster and text sit 56 in from the edges.
  double get moviePadding => 56;

  /// Between a movie's poster and its text.
  double get posterGap => 40;

  /// The text column stops here, however wide the window.
  double get textMaxWidth => 700;

  /// A series' left column: poster, title, plot, actions.
  double get seriesColumnWidth => 560;

  /// A series' page: 40 around, 24 at the top.
  EdgeInsets get seriesPadding => const EdgeInsets.fromLTRB(40, 24, 40, 40);

  /// A movie's actions are 52 tall; a series' 50.
  double get movieActionHeight => 52;
  double get seriesActionHeight => 50;

  /// The "‹ Movies" chip back to the grid.
  double get backChipHeight => 36;

  /// The line under a movie's actions, "46 min left".
  double get progressWidth => 420;

  /// An episode's still: 176 × 99.
  Size get episodeStill => const Size(176, 99);
}

/// The search overlay's measures (canvas `Search`); sizes only it uses.
@immutable
class AppSearchTokens {
  const new();

  /// The panel: 760 wide, 72 from the top of the window.
  double get panelWidth => 760;
  double get panelTop => 72;

  /// Kept clear under the panel when it grows to the window's height.
  double get panelBottom => 24;

  /// The query bar and its magnifier.
  double get queryBarHeight => 64;
  double get queryIconSize => 22;

  /// A result: 52 tall, its picture centred in a 56 slot — a logo 36
  /// square, a poster 30 × 44.
  double get rowHeight => 52;
  double get pictureSlot => 56;
  double get logoSize => 36;
  Size get posterSize => const Size(30, 44);

  /// The footer of keys and recent searches.
  double get footerHeight => 44;

  /// How dark the screen under the panel goes (canvas: black at 62 %).
  double get scrimOpacity => 0.62;
}

/// The Guide grid's measures (canvas `Guide`, docs/05 §5). Its colors
/// are [AppColors] tokens; these are the sizes only the grid uses.
@immutable
class AppGuideTokens {
  const new();

  /// One hour of programmes (docs/05: 1 hour = 240 px).
  double get hourWidth => 240;

  /// A ruler label every half hour.
  Duration get rulerStep => const Duration(minutes: 30);

  /// The pinned column of channel numbers, logos and names.
  double get channelColumnWidth => 220;

  /// A channel's row, its 1 px divider included.
  double get rowHeight => 72;

  /// The time ruler above the rows.
  double get rulerHeight => 44;

  /// A ruler label sits this far right of its tick.
  double get rulerLabelInset => 8;

  /// A programme cell sits this far inside its row, top and bottom…
  double get cellInsetY => 6;

  /// …and this far from where its programme starts and ends, so two
  /// programmes back to back are 8 px apart.
  double get cellInsetX => 4;

  EdgeInsets get cellPadding =>
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  /// Between a cell's title and its time.
  double get cellLineGap => 4;

  /// Narrower cells drop the AM/PM from their time, then the end time,
  /// then their text.
  double get cellFullTimeWidth => 200;
  double get cellRangeWidth => 120;
  double get cellTextWidth => 40;

  /// The now line and its time pill on the ruler.
  double get nowLineWidth => 2;
  double get nowLineOpacity => 0.9;
  EdgeInsets get nowPillPadding =>
      const EdgeInsets.symmetric(horizontal: 7, vertical: 3);

  /// The channel column: number, 32 px logo, name.
  double get channelPadding => 16;
  double get channelGap => 10;
  double get channelNumberWidth => 26;
  double get logoSize => 32;

  /// The dashed outline of a channel with no guide.
  double get dashLength => 4;
  double get dashGap => 3;
}

/// The casting screens' measures (canvas `Cast device picker` and
/// `Casting`).
@immutable
class AppCastTokens {
  const new();

  /// The casting view: its card's inset, the gap between the artwork and
  /// the text, the artwork, and the text column's widest.
  double get viewInset => 64;
  double get viewGap => 64;
  double get artworkSize => 360;
  double get artworkRadius => 28;
  double get textMaxWidth => 640;

  /// The view's controls (previous and next channel, volume, Stop
  /// casting) and the volume slider.
  double get controlSize => 48;
  double get volumeWidth => 140;

  /// The time line under the programme.
  double get timelineHeight => 5;

  /// The device picker: its width, padding and gaps.
  double get pickerWidth => 540;
  double get pickerPadding => 24;
  double get pickerGap => 18;

  /// A device row's icon tile and its status dot.
  double get deviceIconSize => 44;
  double get deviceIconRadius => 10;
  double get statusDot => 7;

  /// The casting bar under the content.
  double get barHeight => 64;
  double get barRadius => 14;
  double get barLogo => 40;
}

/// Shadows. Only floating surfaces get one (docs/05).
@immutable
class AppElevation {
  const new();

  /// Menus and dialogs.
  List<BoxShadow> get overlay => const [
    BoxShadow(color: Color(0x73000000), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Large artwork on the casting screen.
  List<BoxShadow> get hero => const [
    BoxShadow(color: Color(0x73000000), blurRadius: 60, offset: Offset(0, 30)),
  ];
}

/// Every design token, reachable from a [BuildContext] through
/// `context.tokens`. Accent, density and reduce-motion change at runtime,
/// so this is a [ThemeExtension] rather than a set of constants.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const new({
    required this.colors,
    required this.density,
    required this.motion,
    this.spacing = const AppSpacing(),
    this.radii = const AppRadii(),
    this.text = const AppTypography(),
    this.focus = const AppFocusTokens(),
    this.elevation = const AppElevation(),
    this.guide = const AppGuideTokens(),
    this.details = const AppDetailsTokens(),
    this.search = const AppSearchTokens(),
    this.cast = const AppCastTokens(),
  });

  /// Defaults: blue accent, comfortable rows, full motion.
  factory defaults({
    AppAccent accent = AppAccent.blue,
    AppDensity density = AppDensity.comfortable,
    bool reduceMotion = false,
  }) => AppTokens(
    colors: AppColors(accent: accent),
    density: density,
    motion: AppMotion(reduceMotion: reduceMotion),
  );

  final AppColors colors;
  final AppDensity density;
  final AppMotion motion;
  final AppSpacing spacing;
  final AppRadii radii;
  final AppTypography text;
  final AppFocusTokens focus;
  final AppElevation elevation;
  final AppGuideTokens guide;
  final AppDetailsTokens details;
  final AppSearchTokens search;
  final AppCastTokens cast;

  @override
  AppTokens copyWith({
    AppColors? colors,
    AppDensity? density,
    AppMotion? motion,
    AppSpacing? spacing,
    AppRadii? radii,
    AppTypography? text,
    AppFocusTokens? focus,
    AppElevation? elevation,
    AppGuideTokens? guide,
    AppDetailsTokens? details,
    AppSearchTokens? search,
    AppCastTokens? cast,
  }) => AppTokens(
    colors: colors ?? this.colors,
    density: density ?? this.density,
    motion: motion ?? this.motion,
    spacing: spacing ?? this.spacing,
    radii: radii ?? this.radii,
    text: text ?? this.text,
    focus: focus ?? this.focus,
    elevation: elevation ?? this.elevation,
    guide: guide ?? this.guide,
    details: details ?? this.details,
    search: search ?? this.search,
    cast: cast ?? this.cast,
  );

  /// Tokens are discrete (an accent is picked, not blended), so this snaps
  /// at the halfway point instead of interpolating.
  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null || t < 0.5) return this;
    return other;
  }
}

/// Changes a token style's weight on both axes the bundled variable
/// fonts need: [FontWeight] for fallback fonts and the `wght` variation
/// for the variable ones (ADR-008). `copyWith(fontWeight:)` alone leaves
/// the old variation in place.
extension AppTextStyleWeight on TextStyle {
  TextStyle withWeight(int weight) => copyWith(
    fontWeight: FontWeight.values.firstWhere((w) => w.value == weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );
}

/// `context.tokens` — the only way presentation code reads design values.
extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.defaults();
}
