import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';

import 'page_control_tabs.dart';

/// Search shares the fixed toolbar with view tabs. In compact windows, the
/// search button opens an input in the same row; closing restores the tabs.
class PageToolbarSearch<T> extends StatefulWidget {
  const PageToolbarSearch({
    super.key,
    required this.tabs,
    required this.searchBuilder,
  });

  final PageControlTabs<T> tabs;
  final Widget Function(bool autofocus) searchBuilder;

  @override
  State<PageToolbarSearch<T>> createState() => _PageToolbarSearchState<T>();
}

class _PageToolbarSearchState<T> extends State<PageToolbarSearch<T>> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tabsWidth = widget.tabs.preferredWidth(context);
      final fullSearch = constraints.maxWidth >= tabsWidth + 12 + 200 + 16;
      if (!fullSearch && _expanded) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: widget.searchBuilder(true)),
              IconButton(
                key: const ValueKey('page-toolbar-search-close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: const AppIcon(AppIcons.cancel01, size: 18),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() => _expanded = false);
                },
              ),
            ],
          ),
        );
      }
      return Row(
        children: [
          if (fullSearch)
            SizedBox(width: tabsWidth, child: widget.tabs)
          else
            Expanded(child: widget.tabs),
          const SizedBox(width: 12),
          if (fullSearch)
            Expanded(child: widget.searchBuilder(false))
          else
            IconButton(
              key: const ValueKey('page-toolbar-search-open'),
              tooltip: MaterialLocalizations.of(context).searchFieldLabel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const AppIcon(AppIcons.search01, size: 18),
              onPressed: () => setState(() => _expanded = true),
            ),
          const SizedBox(width: 16),
        ],
      );
    },
  );
}
