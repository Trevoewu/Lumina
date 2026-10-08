import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'app_back_button.dart';
import '../../core/app_design_tokens.dart';

/// Secondary pages keep their back button and actions in a toolbar pinned
/// above the content, so scrolling never strands the reader without a way
/// back. The large title scrolls away with the content and its compact form
/// takes over the toolbar once it is gone.
class CollapsingPageScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool showBackButton;
  final bool compactHeader;
  final double expandedHeight;
  final bool showTitle;

  const CollapsingPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.showBackButton = false,
    this.compactHeader = false,
    this.expandedHeight = 124,
    this.showTitle = true,
  });

  @override
  State<CollapsingPageScaffold> createState() => _CollapsingPageScaffoldState();
}

class _CollapsingPageScaffoldState extends State<CollapsingPageScaffold> {
  final _titleKey = GlobalKey();
  final _titleScrolledAway = ValueNotifier(false);

  @override
  void dispose() {
    _titleScrolledAway.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    // Only the outer scroll moves the header; the body's own lists report at
    // a deeper depth.
    if (notification.depth != 0) return false;
    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    final titleHeight = titleBox?.size.height ?? 0;
    _titleScrolledAway.value =
        titleHeight > 0 && notification.metrics.pixels >= titleHeight;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final design = context.appDesign;
    final pageInset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final gutter = pageInset + 6;
    final isMac = theme.platform == TargetPlatform.macOS;
    final renderBackButton = widget.showBackButton && !isMac;
    final hasToolbar = renderBackButton || widget.actions.isNotEmpty;
    final showHeader = hasToolbar || widget.showTitle;

    if (!showHeader) {
      return Scaffold(
        backgroundColor: context.appBackground,
        body: widget.body,
      );
    }

    final content = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: SafeArea(
            top: !hasToolbar,
            bottom: false,
            child: Material(
              key: const ValueKey('collapsing-page-header'),
              color: context.appBackground,
              child: Padding(
                key: _titleKey,
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  hasToolbar ? 0 : 18.0,
                  gutter,
                  design.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showTitle)
                      Text(
                        widget.title,
                        key: const ValueKey('collapsing-page-title'),
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: context.appTextPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      body: widget.body,
    );

    if (!hasToolbar) {
      return Scaffold(backgroundColor: context.appBackground, body: content);
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Material(
              key: const ValueKey('collapsing-page-toolbar'),
              color: context.appBackground,
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 0),
                child: SizedBox(
                  height: design.toolbarHeight,
                  child: NavigationToolbar(
                    leading: renderBackButton ? const AppBackButton() : null,
                    middle: widget.showTitle
                        ? ValueListenableBuilder<bool>(
                            valueListenable: _titleScrolledAway,
                            // Swapped out rather than faded to zero, so the
                            // title is not announced twice while the large one
                            // is still on screen.
                            builder: (context, visible, _) => AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 160),
                              child: visible
                                  ? Text(
                                      widget.title,
                                      key: const ValueKey(
                                        'collapsing-page-compact-title',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: context.appTextPrimary,
                                          ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          )
                        : null,
                    trailing: widget.actions.isEmpty
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.actions,
                          ),
                    middleSpacing: design.spaceSm,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: design.spaceSm),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}
