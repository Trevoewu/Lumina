import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

/// Pill search control from the Lumina dictionary design: a white card with a
/// leading glyph and a trailing submit button that lights up once the field
/// has something to submit.
class AppSearchField extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSearch;
  final bool loading;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;

  const AppSearchField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
    this.onChanged,
    this.onSearch,
    this.loading = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 18, right: 7),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 19, color: ink.withValues(alpha: 0.45)),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              autofocus: autofocus,
              autocorrect: autocorrect,
              enableSuggestions: enableSuggestions,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: loading ? null : onSubmitted,
              style: TextStyle(fontSize: 16, color: ink),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: ink.withValues(alpha: 0.32),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SubmitButton(
            controller: controller,
            loading: loading,
            onSearch: onSearch,
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback? onSearch;

  const _SubmitButton({
    required this.controller,
    required this.loading,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;

    if (loading) {
      return SizedBox.square(
        dimension: 38,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
        ),
      );
    }
    if (onSearch == null) return const SizedBox(width: 4);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final ready = value.text.trim().isNotEmpty;
        return Tooltip(
          message: MaterialLocalizations.of(context).searchFieldLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ready ? onSearch : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready ? accent : ink.withValues(alpha: 0.06),
              ),
              child: Icon(
                Icons.arrow_forward,
                size: 18,
                color: ready
                    ? Theme.of(context).colorScheme.onPrimary
                    : ink.withValues(alpha: 0.35),
              ),
            ),
          ),
        );
      },
    );
  }
}
