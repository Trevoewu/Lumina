import 'package:flutter/material.dart';

import '../../../core/app_design_tokens.dart';

class AppSearchField extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSearch;
  final bool loading;
  final bool autofocus;

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
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    return SizedBox(
      height: design.controlHeight,
      child: TextField(
        key: fieldKey,
        controller: controller,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: loading ? null : onSubmitted,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : onSearch == null
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context).searchFieldLabel,
                  onPressed: onSearch,
                  icon: const Icon(Icons.arrow_forward),
                ),
        ),
      ),
    );
  }
}
