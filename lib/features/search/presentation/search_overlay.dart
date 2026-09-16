import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// The Ctrl+K / `/` search overlay (docs/05, canvas `Search.dc.html`): a
/// scrim over the shell and a 760 px panel with the query at the top.
///
/// Phase 6 fills in the grouped results; step 4 builds the frame, the
/// keyboard path and the Esc affordance the canvas draws.
class SearchOverlay extends StatefulWidget {
  const new({this.onClose, super.key});

  /// Esc and the scrim call this; the router pops the overlay.
  final VoidCallback? onClose;

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    // The overlay is its own route with no Scaffold, and Material's
    // text field needs a Material ancestor; transparency adds nothing
    // visible.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: 'Search',
        explicitChildNodes: true,
        child: Stack(
          children: [
            // The scrim closes on a click but is not a focus stop: Esc is
            // the keyboard way out.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: ColoredBox(
                  color: const Color(0xFF000000).withValues(alpha: 0.62),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: tokens.spacing.s64 + 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.s24,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: tokens.radii.lgAll,
                      border: Border.all(color: colors.border),
                      boxShadow: tokens.elevation.overlay,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FocusPane(
                      debugLabel: 'search-overlay',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QueryBar(controller: _query),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: tokens.spacing.s32,
                            ),
                            child: const EmptyState(
                              compact: true,
                              icon: AppIcons.search,
                              title: 'Search comes in Phase 6',
                              message:
                                  'Channels, what is on now, movies, '
                                  'series and your library, in one box.',
                            ),
                          ),
                        ],
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
  }
}

/// The 64 px header from the canvas: magnifier, the query, and an Esc
/// keycap that says how to get out.
class _QueryBar extends StatelessWidget {
  const new({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Container(
      height: 64,
      padding: EdgeInsets.only(
        left: tokens.spacing.s20,
        right: tokens.spacing.s16,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.search, size: 22, color: colors.textSecondary),
          SizedBox(width: tokens.spacing.s12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              cursorColor: colors.accentBase,
              style: tokens.text.h3.copyWith(
                fontSize: 19,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search channels, shows, movies',
                hintStyle: tokens.text.h3.copyWith(
                  fontSize: 19,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.s12),
          // A hint, not a control: Esc closes the overlay and a click
          // on the scrim does the same.
          const ExcludeSemantics(child: Kbd('Esc')),
        ],
      ),
    );
  }
}
