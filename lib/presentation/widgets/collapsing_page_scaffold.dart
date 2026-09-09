import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'app_glass_controls.dart';
import 'app_back_button.dart';
import '../../core/app_design_tokens.dart';

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
    final theme = Theme.of(context);
    final design = context.appDesign;
    final pageInset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return Scaffold(
      backgroundColor: context.appBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverPersistentHeader(
            pinned: true,
            delegate: _CollapsingPageHeaderDelegate(
              theme: theme,
              title: title,
              actions: actions,
              showBackButton: showBackButton,
              compact: compactHeader,
              topPadding: topPadding,
              expandedHeight: expandedHeight,
              pageInset: pageInset,
              toolbarHeight: design.toolbarHeight,
              spaceXs: design.spaceXs,
              spaceSm: design.spaceSm,
              spaceMd: design.spaceMd,
              controlHeight: design.controlHeight,
            ),
          ),
        ],
        body: body,
      ),
    );
  }
}

class _CollapsingPageHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ThemeData theme;
  final String title;
  final List<Widget> actions;
  final bool showBackButton;
  final bool compact;
  final double topPadding;
  final double expandedHeight;
  final double pageInset;
  final double toolbarHeight;
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double controlHeight;

  const _CollapsingPageHeaderDelegate({
    required this.theme,
    required this.title,
    required this.actions,
    required this.showBackButton,
    required this.compact,
    required this.topPadding,
    required this.expandedHeight,
    required this.pageInset,
    required this.toolbarHeight,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.controlHeight,
  });

  @override
  double get minExtent => topPadding + toolbarHeight;

  @override
  double get maxExtent =>
      topPadding + (compact ? toolbarHeight : expandedHeight);

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
      showBackButton ? toolbarHeight + spaceSm : pageInset,
      actions.isEmpty ? pageInset : toolbarHeight * actions.length + spaceMd,
    );
    final currentExtent = maxExtent - shrinkOffset;
    final titleTop = lerpDouble(
      currentExtent - (toolbarHeight + spaceSm),
      topPadding + spaceXs,
      easedProgress,
    )!;
    final textTheme = theme.textTheme;
    final titleStyle = TextStyle.lerp(
      textTheme.headlineLarge,
      textTheme.headlineSmall,
      easedProgress,
    )?.copyWith(color: theme.colorScheme.onSurface);

    return Material(
      key: const ValueKey('collapsing-page-header'),
      color: overlapsContent || shrinkOffset > 0
          ? Colors.transparent
          : theme.colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (overlapsContent || shrinkOffset > 0)
            const Positioned.fill(
              child: IgnorePointer(
                child: AppGlassSurface(radius: 0, child: SizedBox.expand()),
              ),
            ),
          Positioned(
            top: titleTop,
            left: lerpDouble(pageInset, collapsedSide, easedProgress),
            right: lerpDouble(pageInset, collapsedSide, easedProgress),
            height: toolbarHeight,
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
              left: spaceXs,
              width: controlHeight,
              height: toolbarHeight,
              child: const Center(child: AppBackButton()),
            ),
          if (actions.isNotEmpty)
            Positioned(
              top: topPadding,
              right: spaceXs,
              height: toolbarHeight,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CollapsingPageHeaderDelegate oldDelegate) =>
      // A stationary sliver must also rebuild during theme transitions.
      theme != oldDelegate.theme ||
      title != oldDelegate.title ||
      showBackButton != oldDelegate.showBackButton ||
      compact != oldDelegate.compact ||
      topPadding != oldDelegate.topPadding ||
      expandedHeight != oldDelegate.expandedHeight ||
      pageInset != oldDelegate.pageInset ||
      toolbarHeight != oldDelegate.toolbarHeight ||
      spaceXs != oldDelegate.spaceXs ||
      spaceSm != oldDelegate.spaceSm ||
      spaceMd != oldDelegate.spaceMd ||
      controlHeight != oldDelegate.controlHeight ||
      actions != oldDelegate.actions;
}
