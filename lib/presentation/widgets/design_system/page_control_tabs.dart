import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';

/// Standard text-and-underline selector for fixed page control bars.
/// The parent toolbar constrains the natural 44-point height on desktop.
class PageControlTabs<T> extends StatelessWidget {
  const PageControlTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.itemKey,
    this.height,
    this.padding,
  });

  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onSelected;
  final Key Function(T)? itemKey;
  final double? height;
  final EdgeInsetsGeometry? padding;

  /// Width needed to show every label without scrolling, including padding.
  double preferredWidth(BuildContext context) {
    final design = context.appDesign;
    var width =
        design.pageInsetFor(MediaQuery.sizeOf(context).width) +
        6 +
        design.spaceXs +
        (labels.length - 1) * 22;
    for (final label in labels.values) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      width += painter.width;
      painter.dispose();
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final values = labels.keys.toList(growable: false);
    final effectiveHeight = height ?? 38.0;
    final effectivePadding =
        padding ?? EdgeInsets.fromLTRB(inset + 6, 0, design.spaceXs, 0);

    return SizedBox(
      height: effectiveHeight,
      child: ListView.separated(
        padding: effectivePadding,
        scrollDirection: Axis.horizontal,
        primary: false,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (context, index) {
          final value = values[index];
          return _PageControlTab(
            key: itemKey?.call(value),
            label: labels[value]!,
            selected: selected == value,
            onTap: () => onSelected(value),
          );
        },
      ),
    );
  }
}

/// Underline tab from the Lumina home design: weight, opacity and a 2px rule
/// carry the selected state instead of a filled chip.
class _PageControlTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PageControlTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: IntrinsicWidth(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.normal,
                  color: selected ? ink : ink.withValues(alpha: 0.35),
                ),
                child: Text(label),
              ),
              const SizedBox(height: 4),
              AnimatedScale(
                duration: const Duration(milliseconds: 300),
                curve: const Cubic(0.2, 0.7, 0.2, 1),
                alignment: Alignment.centerLeft,
                scale: selected ? 1 : 0.3,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: selected ? 1 : 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
