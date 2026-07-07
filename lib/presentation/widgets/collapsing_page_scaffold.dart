import 'dart:ui' show lerpDouble;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class CollapsingPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool showBackButton;
  final bool compactHeader;
  final double expandedHeight;

  const CollapsingPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.showBackButton = false,
    this.compactHeader = false,
    this.expandedHeight = 124,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: context.appBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverPersistentHeader(
            pinned: true,
            delegate: _CollapsingPageHeaderDelegate(
              title: title,
              actions: actions,
              showBackButton: showBackButton,
              compact: compactHeader,
              topPadding: topPadding,
              expandedHeight: expandedHeight,
            ),
          ),
        ],
        body: body,
      ),
    );
  }
}

class _CollapsingPageHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _toolbarHeight = 56;

  final String title;
  final List<Widget> actions;
  final bool showBackButton;
  final bool compact;
  final double topPadding;
  final double expandedHeight;

  const _CollapsingPageHeaderDelegate({
    required this.title,
    required this.actions,
    required this.showBackButton,
    required this.compact,
    required this.topPadding,
    required this.expandedHeight,
  });

  @override
  double get minExtent => topPadding + _toolbarHeight;

  @override
  double get maxExtent =>
      topPadding + (compact ? _toolbarHeight : expandedHeight);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final progress = compact || range <= 0
        ? 1.0
        : (shrinkOffset / range).clamp(0.0, 1.0);
    final easedProgress = Curves.easeInOutCubic.transform(progress);
    final collapsedSide = math.max(
      showBackButton ? 64.0 : 20.0,
      actions.isEmpty ? 20.0 : 56.0 * actions.length + 12,
    );
    final currentExtent = maxExtent - shrinkOffset;
    final titleTop = lerpDouble(
      currentExtent - 64,
      topPadding + 4,
      easedProgress,
    )!;
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: context.appTextPrimary,
      fontSize: lerpDouble(34, 18, easedProgress),
      fontWeight: FontWeight.w700,
      height: 1.05,
    );

    return Material(
      key: const ValueKey('collapsing-page-header'),
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: titleTop,
            left: lerpDouble(20, collapsedSide, easedProgress),
            right: lerpDouble(20, collapsedSide, easedProgress),
            height: _toolbarHeight,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.lerp(
                  Alignment.centerLeft,
                  Alignment.center,
                  easedProgress,
                )!,
                child: Text(
                  key: const ValueKey('collapsing-page-title'),
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
              ),
            ),
          ),
          if (showBackButton)
            Positioned(
              top: topPadding,
              left: 4,
              width: 52,
              height: _toolbarHeight,
              child: BackButton(onPressed: () => Navigator.maybePop(context)),
            ),
          if (actions.isNotEmpty)
            Positioned(
              top: topPadding,
              right: 4,
              height: _toolbarHeight,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CollapsingPageHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      showBackButton != oldDelegate.showBackButton ||
      compact != oldDelegate.compact ||
      topPadding != oldDelegate.topPadding ||
      expandedHeight != oldDelegate.expandedHeight ||
      actions != oldDelegate.actions;
}
