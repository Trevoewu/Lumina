import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'app_back_button.dart';
import '../../core/app_design_tokens.dart';

class CollapsingPageScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final design = context.appDesign;
    final pageInset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final gutter = pageInset + 6;
    final isMac = theme.platform == TargetPlatform.macOS;
    final renderBackButton = showBackButton && !isMac;
    final showHeader = renderBackButton || actions.isNotEmpty || showTitle;

    if (!showHeader) {
      return Scaffold(
        backgroundColor: context.appBackground,
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Material(
                key: const ValueKey('collapsing-page-header'),
                color: context.appBackground,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    (renderBackButton || actions.isNotEmpty) ? 6.0 : 18.0,
                    gutter,
                    design.spaceMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (renderBackButton || actions.isNotEmpty) ...[
                        SizedBox(
                          height: design.toolbarHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (renderBackButton)
                                const AppBackButton()
                              else
                                const SizedBox.shrink(),
                              if (actions.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: actions,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: design.spaceSm),
                      ],
                      if (showTitle)
                        Text(
                          title,
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
        body: body,
      ),
    );
  }
}
