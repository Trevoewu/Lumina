import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import 'podcast_link_text.dart';

class PodcastExpandableDescription extends StatefulWidget {
  final String text;
  final int collapsedLines;

  const PodcastExpandableDescription({
    super.key,
    required this.text,
    this.collapsedLines = 5,
  });

  @override
  State<PodcastExpandableDescription> createState() =>
      _PodcastExpandableDescriptionState();
}

class _PodcastExpandableDescriptionState
    extends State<PodcastExpandableDescription> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant PodcastExpandableDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: context.appTextSecondary, height: 1.45);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final canExpand = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastLinkText(
              widget.text,
              maxLines: _expanded ? null : widget.collapsedLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: style,
            ),
            if (canExpand) ...[
              const SizedBox(height: 4),
              TextButton(
                key: const ValueKey('podcast-description-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _expanded
                      ? context.tr('收起', 'Show less', '折りたたむ')
                      : context.tr('展开介绍', 'Show more', 'もっと見る'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
