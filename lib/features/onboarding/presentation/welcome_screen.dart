import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

/// Onboarding's first page: one centred card that says what the app is
/// and leads to adding a source (the approved Welcome sketch, Phase 2
/// plan). Shown on a launch with no sources.
class WelcomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;

    Future<void> openFile() async {
      final path = await ref.read(playlistFilePickerProvider)();
      if (path == null || !context.mounted) return;
      unawaited(
        context.push<void>(
          addSourceRoutePath,
          extra: ConnectPreset(type: SourceType.m3uFile, path: path),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: AppBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.s32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.s48,
                  vertical: spacing.s40,
                ),
                decoration: BoxDecoration(
                  color: colors.surface1,
                  borderRadius: tokens.radii.lgAll,
                  border: Border.all(color: colors.surface3),
                  boxShadow: tokens.elevation.overlay,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppMark.small(),
                    SizedBox(height: spacing.s32),
                    Semantics(
                      header: true,
                      child: Text(
                        'Your channels, movies and series in one calm place.',
                        textAlign: TextAlign.center,
                        style: tokens.text.h1.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.s16),
                    Text(
                      'Add the provider you already pay for. Nothing is '
                      'uploaded anywhere; your credentials stay on this '
                      'computer.',
                      textAlign: TextAlign.center,
                      style: tokens.text.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: spacing.s32),
                    AppButton(
                      label: 'Add your first source',
                      trailingIcon: AppIcons.arrowRight,
                      size: AppButtonSize.l,
                      autofocus: true,
                      onPressed: () =>
                          unawaited(context.push<void>(addSourceRoutePath)),
                    ),
                    SizedBox(height: spacing.s24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: spacing.s4,
                      children: [
                        Text(
                          'Already have a playlist file?',
                          style: tokens.text.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                        AppButton(
                          label: 'Open a file instead',
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.s,
                          onPressed: () => unawaited(openFile()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
