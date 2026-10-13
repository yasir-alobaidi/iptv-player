import 'package:flutter/widgets.dart';
import 'package:iptv_player/design/tokens.dart';

/// Keeps a page of rows or a form to a readable width in a wide window
/// (ADR-017): at most [maxWidth] — [AppLayoutTokens.pageMeasure] unless
/// given — at the left, where the page's title and its tabs are. A row
/// stretched across a 2560 px window puts a name and its button a metre
/// apart.
///
/// A page whose tabs differ (a grid on one, rows on another) keeps this
/// in the tree for both and passes `double.infinity` for the grid, so
/// changing tab rebuilds nothing above the tab's own body.
class PageMeasure extends StatelessWidget {
  const new({
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topLeft,
    super.key,
  });

  final Widget child;
  final double? maxWidth;

  /// Where the page sits in a window wider than it: the left for a
  /// screen in the shell; the middle for a page that stands alone.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? context.tokens.layout.pageMeasure,
      ),
      child: child,
    ),
  );
}
