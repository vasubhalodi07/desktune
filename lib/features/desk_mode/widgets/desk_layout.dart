import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Like [SafeArea], but with the same horizontal padding on both sides.
///
/// A camera cut-out or gesture area usually sits on one side in landscape, so a
/// plain [SafeArea] pushes everything off-centre. Using the larger of the two
/// side insets on both sides keeps the layout balanced and still clear of the
/// cut-out.
class SymmetricSafeArea extends StatelessWidget {
  const SymmetricSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final side = math.max(padding.left, padding.right);
    return Padding(
      padding: EdgeInsets.fromLTRB(side, padding.top, side, padding.bottom),
      // The padding is consumed here, so nested widgets don't apply it again.
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        child: child,
      ),
    );
  }
}

/// The desk screen's clock + player composition, laid out to look the same on
/// every screen.
///
/// [left] and [right] are designed at a fixed size ([leftWidth] and
/// [rightWidth] logical pixels wide). Together they form one composition that is
/// scaled to fit the space available and centred in it, so:
///
/// * the margin on the left and right is always equal;
/// * the whole layout grows on tablets and shrinks on small phones, keeping its
///   proportions instead of leaving a tiny cluster in a big screen;
/// * in a narrow, tall window (split-screen, foldables) the two halves are
///   stacked instead of side by side.
class DeskSplitLayout extends StatelessWidget {
  const DeskSplitLayout({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  /// Design width of the clock half.
  static const double leftWidth = 310;

  /// Design width of the player half.
  static const double rightWidth = 420;

  /// Space between the two halves, at design size.
  static const double gap = 32;

  /// Below this width-to-height ratio the halves are stacked.
  static const double stackBelowAspect = 1.25;

  /// Outer margin as a share of the width, kept within a sensible range.
  static double marginFor(double width) => (width * 0.04).clamp(16.0, 56.0);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final margin = marginFor(width);
          final stacked = height > 0 && width / height < stackBelowAspect;

          final Widget composition = stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: rightWidth,
                      child: Center(child: left),
                    ),
                    const SizedBox(height: gap),
                    SizedBox(width: rightWidth, child: right),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: Center(child: left),
                    ),
                    const SizedBox(width: gap),
                    SizedBox(width: rightWidth, child: right),
                  ],
                );

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: margin,
              vertical: margin * 0.5,
            ),
            // Scales up on tablets, down on small phones, and centres the
            // result, which is what makes both side margins equal.
            child: FittedBox(fit: BoxFit.contain, child: composition),
          );
        },
      ),
    );
  }
}
