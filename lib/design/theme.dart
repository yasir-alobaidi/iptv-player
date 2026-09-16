import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// The app's dark theme, built only from [AppTokens]. Material's own
/// colors are pointed at our tokens so any stray Material widget still
/// looks like the rest of the app.
ThemeData buildAppTheme({
  AppAccent accent = AppAccent.blue,
  AppDensity density = AppDensity.comfortable,
  bool reduceMotion = false,
}) {
  final tokens = AppTokens.defaults(
    accent: accent,
    density: density,
    reduceMotion: reduceMotion,
  );
  final colors = tokens.colors;
  final text = tokens.text;

  final scheme = ColorScheme.dark(
    primary: colors.accentBase,
    onPrimary: colors.onAccent,
    secondary: colors.accentBase,
    onSecondary: colors.onAccent,
    surface: colors.surface1,
    onSurface: colors.textPrimary,
    error: colors.danger,
    onError: colors.onAccent,
    outline: colors.border,
    outlineVariant: colors.borderSubtle,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    fontFamily: AppFonts.sans,
    extensions: [tokens],
    // The design system draws its own focus ring (FocusableSurface).
    focusColor: Colors.transparent,
    hoverColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerTheme: DividerThemeData(
      color: colors.borderSubtle,
      space: 1,
      thickness: 1,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accentBase,
      selectionColor: colors.accentSoft,
      selectionHandleColor: colors.accentBase,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: tokens.radii.smAll,
        border: Border.all(color: colors.border),
        boxShadow: tokens.elevation.overlay,
      ),
      textStyle: text.caption.copyWith(color: colors.textPrimary),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s8,
        vertical: tokens.spacing.s4 + 2,
      ),
      waitDuration: const Duration(milliseconds: 400),
    ),
    textTheme: TextTheme(
      displayLarge: text.display,
      headlineLarge: text.h1,
      headlineMedium: text.h2,
      titleLarge: text.h3,
      titleMedium: text.titleSmall,
      bodyLarge: text.body,
      bodyMedium: text.body,
      labelLarge: text.label,
      bodySmall: text.caption,
      labelSmall: text.labelSmall,
    ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary),
  );
}
