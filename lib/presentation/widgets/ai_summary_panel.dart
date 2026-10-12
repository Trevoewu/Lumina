import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ai/ai_models.dart';
import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';
import '../../core/app_localizations.dart';
import '../../core/app_preferences.dart';
import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import 'app_sheet.dart';
import 'design_system/editorial_type.dart';
import 'design_system/quiet_button.dart';

typedef AiCitationCallback = Future<void> Function(AiCitation citation);

String _resolvedAiServiceLanguageCode(WidgetRef ref) => ref
    .read(appPreferencesProvider)
    .resolvedAiLanguageCode(WidgetsBinding.instance.platformDispatcher.locale);

class AiSummaryPanel extends ConsumerStatefulWidget {
  final AiContentScope scope;
  final AiCitationCallback? onCitationTap;
  final VoidCallback? onTranscriptRequired;
  final VoidCallback? onAiServiceRequired;
  final bool? transcriptAvailable;
  final bool aiServiceReady;

  /// Laid flat on the player page: a kicker for the title and quiet buttons.
  /// Elsewhere it keeps its titled header and filled buttons.
  final bool flat;

  const AiSummaryPanel({
    super.key,
    this.flat = false,
    required this.scope,
    this.onCitationTap,
    this.onTranscriptRequired,
    this.onAiServiceRequired,
    this.transcriptAvailable,
    this.aiServiceReady = true,
  });

  @override
  ConsumerState<AiSummaryPanel> createState() => _AiSummaryPanelState();
}

class _AiSummaryPanelState extends ConsumerState<AiSummaryPanel> {
  String? _summary;
  String? _status;
  String? _error;
  bool _transcriptAvailable = false;
  bool _loading = true;
  bool _running = false;
  bool _expanded = false;
  StreamSubscription<AiAgentUpdate>? _subscription;

  @override
  void initState() {
    super.initState();
    _transcriptAvailable = _resolveTranscriptAvailability();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AiSummaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope.id != widget.scope.id ||
        oldWidget.scope.type != widget.scope.type ||
        oldWidget.scope.contentRevision != widget.scope.contentRevision) {
      unawaited(_subscription?.cancel());
      _subscription = null;
      _summary = null;
      _status = null;
      _error = null;
      _loading = true;
      _running = false;
      _expanded = false;
      _transcriptAvailable = _resolveTranscriptAvailability();
      unawaited(_load());
    } else if (oldWidget.transcriptAvailable != widget.transcriptAvailable) {
      setState(() {
        _transcriptAvailable = _resolveTranscriptAvailability();
      });
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final thread = await ref
          .read(aiThreadRepositoryProvider)
          .load(widget.scope);
      if (!mounted) return;
      setState(() {
        _summary = thread?.summaryText;
        _transcriptAvailable = _resolveTranscriptAvailability();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  bool _resolveTranscriptAvailability() {
    final provided = widget.transcriptAvailable;
    if (provided != null) return provided;
    if (!widget.scope.isPodcast) return true;
    final revision = widget.scope.contentRevision;
    if (revision is! String) return false;
    final normalized = revision.trim();
    return normalized.isNotEmpty && normalized != '[]' && normalized != '{}';
  }

  Future<void> _generate() async {
    if (_running) return;
    if (!widget.aiServiceReady) {
      widget.onAiServiceRequired?.call();
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _status = context.tr(
        '正在读取 Transcript…',
        'Reading transcript…',
        '文字起こしを読み込み中…',
      );
    });
    await _subscription?.cancel();
    if (!mounted) return;
    final languageCode = _resolvedAiServiceLanguageCode(ref);
    _subscription = ref
        .read(aiAssistantServiceProvider)
        .summarize(widget.scope, languageCode: languageCode)
        .listen(_applyUpdate);
  }

  void _applyUpdate(AiAgentUpdate update) {
    if (!mounted) return;
    switch (update.type) {
      case AiAgentUpdateType.status:
        setState(() => _status = _localizedStatus(update.text ?? ''));
      case AiAgentUpdateType.resetText:
        setState(() => _summary = '');
      case AiAgentUpdateType.textDelta:
        setState(() => _summary = '${_summary ?? ''}${update.text ?? ''}');
      case AiAgentUpdateType.completed:
        setState(() {
          _running = false;
          _status = null;
        });
        unawaited(_load());
      case AiAgentUpdateType.failed:
        setState(() {
          _running = false;
          _status = null;
          _error = update.text;
          if (_summary?.trim().isEmpty ?? true) _summary = null;
        });
        unawaited(_load());
    }
  }

  String _localizedStatus(String status) {
    if (!Localizations.localeOf(context).languageCode.startsWith('zh')) {
      return status;
    }
    return switch (status) {
      'Reading the complete transcript…' => '正在读取完整 Transcript…',
      'Reading the transcript…' => '正在读取 Transcript…',
      'Searching the transcript…' => '正在搜索 Transcript…',
      'Checking the transcript…' => '正在核对 Transcript…',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final hasSummary = _summary?.trim().isNotEmpty ?? false;
    final flat = widget.flat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!flat) ...[
              AppIcon(
                AppIcons.aiMagic,
                size: 20,
                color: context.appTextSecondary,
              ),
              SizedBox(width: design.spaceSm),
            ],
            Expanded(
              child: Text(
                flat ? 'AI SUMMARY' : 'AI Summary',
                style: flat
                    ? kickerTextStyle(context)
                    : Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
            // The player page keeps the section to reading; regenerating
            // stays with the summary sheet elsewhere.
            if (!flat && hasSummary && !_running)
              IconButton(
                key: const ValueKey('ai-summary-regenerate'),
                tooltip: context.tr('重新生成', 'Generate again', '再生成'),
                onPressed: _generate,
                icon: const AppIcon(AppIcons.refresh, size: 20),
              ),
          ],
        ),
        SizedBox(height: design.spaceMd),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (!_transcriptAvailable)
          _TranscriptRequiredState(
            onPressed: widget.onTranscriptRequired,
            flat: flat,
          )
        else if (!widget.aiServiceReady)
          _AiServiceRequiredState(
            onPressed: widget.onAiServiceRequired,
            flat: flat,
          )
        else if (_running) ...[
          LinearProgressIndicator(
            key: const ValueKey('ai-summary-progress'),
            borderRadius: BorderRadius.circular(99),
          ),
          SizedBox(height: design.spaceSm),
          if (_status != null)
            Text(
              _status!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.appTextSecondary),
            ),
        ] else if (hasSummary) ...[
          if (flat && _expanded)
            AiAnswerText(
              key: const ValueKey('ai-summary-expanded'),
              text: _summary!,
              onCitationTap: widget.onCitationTap,
            )
          else
            Text(
              _summaryPreview(_summary!),
              key: const ValueKey('ai-summary-collapsed-preview'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: flat ? context.appTextPrimary : context.appTextSecondary,
                height: 1.45,
              ),
            ),
          if (_error != null) ...[
            SizedBox(height: design.spaceMd),
            Text(
              _error!,
              key: const ValueKey('ai-summary-error'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
            ),
          ],
          SizedBox(height: design.spaceSm),
          if (flat)
            AppMoreToggle(
              key: const ValueKey('ai-summary-toggle'),
              expanded: _expanded,
              onPressed: () => setState(() => _expanded = !_expanded),
            )
          else
            TextButton.icon(
              key: const ValueKey('ai-summary-toggle'),
              onPressed: () => showAppContentSheet(
                context: context,
                title: 'AI Summary',
                builder: (sheetContext) => AiAnswerText(
                  text: _summary!,
                  onCitationTap: widget.onCitationTap == null
                      ? null
                      : (citation) {
                          Navigator.of(sheetContext).pop();
                          return widget.onCitationTap!(citation);
                        },
                ),
              ),
              iconAlignment: IconAlignment.end,
              icon: const AppIcon(AppIcons.arrowDown01),
              label: Text(
                context.tr('查看完整摘要', 'Show full summary', '概要をすべて表示'),
              ),
            ),
        ] else ...[
          Text(
            context.tr(
              '生成当前内容的简明摘要，并保留可跳转的 Transcript 引用。',
              'Generate a concise overview with references back to the transcript.',
              '文字起こしへの参照付きで簡潔な概要を生成します。',
            ),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.appTextSecondary,
              height: 1.5,
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: design.spaceMd),
            Text(
              _error!,
              key: const ValueKey('ai-summary-error'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
            ),
          ],
          SizedBox(height: design.spaceLg),
          _PanelAction(
            key: const ValueKey('ai-summary-generate'),
            flat: flat,
            onPressed: _generate,
            icon: AppIcons.aiMagic,
            label: context.tr('生成摘要', 'Generate summary', '概要を生成'),
          ),
        ],
      ],
    );
  }
}

String _summaryPreview(String markdown) {
  return markdown
      .replaceAll(RegExp(r'\[(?:P\d+|\d{1,2}:\d{2}(?::\d{2})?)\]'), '')
      .replaceAll(RegExp(r'[*_#>`~-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _AiServiceRequiredState extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool flat;

  const _AiServiceRequiredState({this.onPressed, this.flat = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('ai-service-required'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            '连接 AI 模型后，可以生成摘要、询问内容并获得带引用的回答。',
            'Connect an AI model to create summaries and ask grounded questions with citations.',
            'AIモデルに接続すると、概要の生成や引用付きの質問ができます。',
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.appTextSecondary,
            height: 1.5,
          ),
        ),
        if (onPressed != null) ...[
          SizedBox(height: context.appDesign.spaceLg),
          _PanelAction(
            key: const ValueKey('ai-summary-configure-service'),
            flat: flat,
            onPressed: onPressed,
            icon: AppIcons.aiNetwork,
            label: context.tr('连接 AI 服务', 'Connect AI service', 'AIサービスに接続'),
          ),
        ],
      ],
    );
  }
}

class _TranscriptRequiredState extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool flat;

  const _TranscriptRequiredState({this.onPressed, this.flat = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            '需要 Transcript 才能生成可靠的摘要。',
            'A transcript is required for a grounded summary.',
            '正確な概要を生成するには文字起こしが必要です。',
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.appTextSecondary,
            height: 1.5,
          ),
        ),
        if (onPressed != null) ...[
          SizedBox(height: context.appDesign.spaceLg),
          _PanelAction(
            key: const ValueKey('ai-summary-transcribe'),
            flat: flat,
            onPressed: onPressed,
            icon: AppIcons.subtitle,
            label: context.tr(
              '先生成 Transcript',
              'Create transcript first',
              '先に文字起こしを作成',
            ),
          ),
        ],
      ],
    );
  }
}

/// The panel's main action: a quiet button on a flat page, a full-width
/// filled one elsewhere.
class _PanelAction extends StatelessWidget {
  final bool flat;
  final VoidCallback? onPressed;
  final AppIconData icon;
  final String label;

  const _PanelAction({
    super.key,
    required this.flat,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (flat) {
      return AppQuietButton(icon: icon, label: label, onPressed: onPressed);
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: AppIcon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class AiAnswerText extends StatelessWidget {
  final String text;
  final AiCitationCallback? onCitationTap;

  const AiAnswerText({super.key, required this.text, this.onCitationTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.appAccent;
    final baseTextStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(color: context.appTextPrimary, height: 1.5);
    final headingStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: context.appTextPrimary,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    return MarkdownBody(
      data: _linkifyCitations(text),
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseTextStyle,
        h1: headingStyle,
        h2: headingStyle,
        h3: headingStyle,
        h4: headingStyle,
        h5: headingStyle,
        h6: headingStyle,
        em: baseTextStyle?.copyWith(fontStyle: FontStyle.italic),
        strong: baseTextStyle?.copyWith(fontWeight: FontWeight.w600),
        del: baseTextStyle?.copyWith(decoration: TextDecoration.lineThrough),
        blockquote: baseTextStyle,
        checkbox: baseTextStyle?.copyWith(color: accent),
        listBullet: baseTextStyle?.copyWith(color: context.appTextSecondary),
        tableHead: baseTextStyle?.copyWith(fontWeight: FontWeight.w600),
        tableBody: baseTextStyle,
        a: baseTextStyle?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        blockSpacing: context.appDesign.spaceMd,
        listIndent: context.appDesign.spaceLg,
        code: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appTextPrimary,
          backgroundColor: context.appSurfaceHighlight,
        ),
        codeblockDecoration: BoxDecoration(
          color: context.appSurfaceHighlight,
          borderRadius: BorderRadius.circular(context.appDesign.radiusSmall),
        ),
        blockquoteDecoration: BoxDecoration(
          color: context.appSurfaceHighlight,
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
      ),
      onTapLink: (label, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri == null) return;
        if (uri.scheme == _citationScheme) {
          final citations = extractAiCitations('[${uri.path}]');
          if (citations.isNotEmpty && onCitationTap != null) {
            await onCitationTap!(citations.first);
          }
          return;
        }
        if (uri.scheme == 'https' || uri.scheme == 'http') {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

const _citationScheme = 'lumina-citation';
final _citationPattern = RegExp(r'\[(P\d+|\d{1,2}:\d{2}(?::\d{2})?)\](?!\()');

String _linkifyCitations(String markdown) {
  return markdown.replaceAllMapped(
    _citationPattern,
    (match) => '[${match.group(1)}]($_citationScheme:${match.group(1)})',
  );
}

/// A conversation about [scope] laid into the page: each question with its
/// grounded answer, then a quiet field for the next one. It lives in the
/// player's AI Chatbot section rather than a sheet of its own.
class AiInlineConversation extends ConsumerStatefulWidget {
  final AiContentScope scope;
  final AiCitationCallback? onCitationTap;

  const AiInlineConversation({
    super.key,
    required this.scope,
    this.onCitationTap,
  });

  @override
  ConsumerState<AiInlineConversation> createState() =>
      _AiInlineConversationState();
}

class _ConversationTurn {
  final String id;
  final bool fromUser;
  final String text;

  const _ConversationTurn({
    required this.id,
    required this.fromUser,
    required this.text,
  });
}

class _AiInlineConversationState extends ConsumerState<AiInlineConversation> {
  final _question = TextEditingController();
  List<_ConversationTurn> _turns = const [];
  StreamSubscription<AiAgentUpdate>? _subscription;
  bool _loading = true;
  bool _running = false;

  /// The question being answered, shown until the thread is reloaded with
  /// it saved, and kept with [_error] when the answer fails.
  String? _pendingQuestion;
  String _draft = '';
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AiInlineConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope.id != widget.scope.id ||
        oldWidget.scope.type != widget.scope.type) {
      unawaited(_subscription?.cancel());
      _subscription = null;
      _turns = const [];
      _loading = true;
      _running = false;
      _pendingQuestion = null;
      _draft = '';
      _status = null;
      _error = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _question.dispose();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  /// Reads the saved thread. With [settlePending], the question and answer
  /// shown while streaming give way to their saved copies in the same frame.
  Future<void> _load({bool settlePending = false}) async {
    final repository = ref.read(aiThreadRepositoryProvider);
    final thread = await repository.load(widget.scope);
    final messages = thread == null
        ? const <AiMessage>[]
        : await repository.messages(thread.id);
    if (!mounted) return;
    setState(() {
      _turns = [
        for (final message in messages)
          if (message.kind != 'summary')
            _ConversationTurn(
              id: message.id,
              fromUser: message.role == 'user',
              text: message.content,
            ),
      ];
      _loading = false;
      if (settlePending && !_running) {
        _pendingQuestion = null;
        _draft = '';
      }
    });
  }

  Future<void> _send() async {
    final value = _question.text.trim();
    if (value.isEmpty || _running) return;
    final checking = context.tr(
      '正在核对 Transcript…',
      'Checking transcript…',
      '文字起こしを確認中…',
    );
    _question.clear();
    setState(() {
      _running = true;
      _pendingQuestion = value;
      _draft = '';
      _status = checking;
      _error = null;
    });
    await _subscription?.cancel();
    if (!mounted) return;
    _subscription = ref
        .read(aiAssistantServiceProvider)
        .ask(
          widget.scope,
          value,
          languageCode: _resolvedAiServiceLanguageCode(ref),
        )
        .listen((update) => unawaited(_apply(update)));
  }

  Future<void> _apply(AiAgentUpdate update) async {
    if (!mounted) return;
    switch (update.type) {
      case AiAgentUpdateType.status:
        setState(() => _status = update.text ?? '');
      case AiAgentUpdateType.resetText:
        setState(() => _draft = '');
      case AiAgentUpdateType.textDelta:
        setState(() => _draft += update.text ?? '');
      case AiAgentUpdateType.completed:
        // The answer stays on screen as it streamed in until the saved
        // thread replaces it, so nothing flickers while that loads.
        setState(() {
          _running = false;
          _status = null;
        });
        await _load(settlePending: true);
      case AiAgentUpdateType.failed:
        setState(() {
          _running = false;
          _status = null;
          _error =
              update.text ??
              context.tr('请求失败', 'Request failed', 'リクエストに失敗しました');
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.appTextSecondary);
    final pending = _pendingQuestion;

    return Column(
      key: const ValueKey('ai-conversation-messages'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        for (final turn in _turns)
          Padding(
            padding: EdgeInsets.only(bottom: design.spaceMd),
            child: turn.fromUser
                ? _QuestionText(turn.text)
                : AiAnswerText(
                    text: turn.text,
                    onCitationTap: widget.onCitationTap,
                  ),
          ),
        if (pending != null) ...[
          _QuestionText(pending),
          SizedBox(height: design.spaceMd),
          if (_draft.trim().isNotEmpty)
            AiAnswerText(text: _draft, onCitationTap: widget.onCitationTap),
          // A spinner only until the first words arrive; after that the
          // streaming answer shows the progress and the status is a note.
          if (_running &&
              _draft.trim().isNotEmpty &&
              _status?.trim().isNotEmpty == true)
            Padding(
              padding: EdgeInsets.only(top: design.spaceSm),
              child: Text(_status!, style: secondary),
            ),
          if (_running &&
              _draft.trim().isEmpty &&
              _status?.trim().isNotEmpty == true)
            Padding(
              padding: EdgeInsets.only(top: design.spaceSm),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: design.spaceSm),
                  Flexible(child: Text(_status!, style: secondary)),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: design.spaceSm),
              child: Text(
                _error!,
                style: secondary?.copyWith(color: Colors.redAccent),
              ),
            ),
          SizedBox(height: design.spaceMd),
        ],
        _QuietComposer(
          controller: _question,
          hint: _turns.isEmpty && pending == null
              ? context.tr(
                  '针对当前内容提问…',
                  'Ask about this content…',
                  'この内容について質問…',
                )
              : context.tr('继续提问…', 'Ask a follow-up question…', '続けて質問…'),
          sending: _running,
          onSend: _send,
        ),
      ],
    );
  }
}

/// A question asked in the conversation, set apart from the answers by
/// weight alone.
class _QuestionText extends StatelessWidget {
  final String text;

  const _QuestionText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: context.appTextPrimary,
      ),
    );
  }
}

/// The question field: a hairline capsule, like the section's quiet buttons,
/// with the send arrow inside it.
class _QuietComposer extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool sending;
  final VoidCallback onSend;

  const _QuietComposer({
    required this.controller,
    required this.hint,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    OutlineInputBorder border(double alpha) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: ink.withValues(alpha: alpha)),
    );
    return TextField(
      key: const ValueKey('ai-follow-up-input'),
      controller: controller,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.send,
      keyboardAppearance: Theme.of(context).brightness,
      onSubmitted: (_) => onSend(),
      style: TextStyle(fontSize: 15, color: ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: context.appTextSecondary),
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        border: border(0.14),
        enabledBorder: border(0.14),
        focusedBorder: border(0.3),
        suffixIcon: IconButton(
          key: const ValueKey('ai-follow-up-send'),
          tooltip: context.tr('发送', 'Send', '送信'),
          onPressed: sending ? null : onSend,
          icon: AppIcon(
            AppIcons.arrowUp02,
            size: 20,
            color: sending ? ink.withValues(alpha: 0.3) : ink,
          ),
        ),
      ),
    );
  }
}
