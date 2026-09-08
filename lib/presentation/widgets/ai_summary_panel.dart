import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
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

  const AiSummaryPanel({
    super.key,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: context.appTextSecondary,
            ),
            SizedBox(width: design.spaceSm),
            Expanded(
              child: Text(
                'AI Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (hasSummary && !_running)
              IconButton(
                key: const ValueKey('ai-summary-regenerate'),
                tooltip: context.tr('重新生成', 'Generate again', '再生成'),
                onPressed: _generate,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
          ],
        ),
        SizedBox(height: design.spaceMd),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (!_transcriptAvailable)
          _TranscriptRequiredState(onPressed: widget.onTranscriptRequired)
        else if (!widget.aiServiceReady)
          _AiServiceRequiredState(onPressed: widget.onAiServiceRequired)
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
          Text(
            _summaryPreview(_summary!),
            key: const ValueKey('ai-summary-collapsed-preview'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
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
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            label: Text(context.tr('查看完整摘要', 'Show full summary', '概要をすべて表示')),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('ai-summary-generate'),
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(context.tr('生成摘要', 'Generate summary', '概要を生成')),
            ),
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

  const _AiServiceRequiredState({this.onPressed});

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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('ai-summary-configure-service'),
              onPressed: onPressed,
              icon: const Icon(Icons.hub_outlined, size: 18),
              label: Text(
                context.tr('连接 AI 服务', 'Connect AI service', 'AIサービスに接続'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TranscriptRequiredState extends StatelessWidget {
  final VoidCallback? onPressed;

  const _TranscriptRequiredState({this.onPressed});

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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('ai-summary-transcribe'),
              onPressed: onPressed,
              icon: const Icon(Icons.subtitles_rounded, size: 18),
              label: Text(
                context.tr(
                  '先生成 Transcript',
                  'Create transcript first',
                  '先に文字起こしを作成',
                ),
              ),
            ),
          ),
        ],
      ],
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
      fontWeight: FontWeight.w800,
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
        strong: baseTextStyle?.copyWith(fontWeight: FontWeight.w800),
        del: baseTextStyle?.copyWith(decoration: TextDecoration.lineThrough),
        blockquote: baseTextStyle,
        checkbox: baseTextStyle?.copyWith(color: accent),
        listBullet: baseTextStyle?.copyWith(color: context.appTextSecondary),
        tableHead: baseTextStyle?.copyWith(fontWeight: FontWeight.w700),
        tableBody: baseTextStyle,
        a: baseTextStyle?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
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

class AiConversationSheet extends ConsumerStatefulWidget {
  final AiContentScope scope;
  final AiCitationCallback? onCitationTap;

  const AiConversationSheet({
    super.key,
    required this.scope,
    this.onCitationTap,
  });

  @override
  ConsumerState<AiConversationSheet> createState() =>
      _AiConversationSheetState();
}

class _AiConversationSheetState extends ConsumerState<AiConversationSheet> {
  static const _currentUserId = 'lumina-user';
  static const _assistantUserId = 'lumina-assistant';

  final _question = TextEditingController();
  late final chat.InMemoryChatController _chatController;
  StreamSubscription<AiAgentUpdate>? _subscription;
  chat.TextMessage? _draftMessage;
  String? _status;
  bool _loading = true;
  bool _running = false;
  int _ephemeralSequence = 0;

  @override
  void initState() {
    super.initState();
    _chatController = chat.InMemoryChatController();
    unawaited(_loadMessages());
  }

  @override
  void dispose() {
    _question.dispose();
    _chatController.dispose();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final thread = await ref
        .read(aiThreadRepositoryProvider)
        .load(widget.scope);
    final messages = thread == null
        ? const <AiMessage>[]
        : await ref.read(aiThreadRepositoryProvider).messages(thread.id);
    if (!mounted) return;
    await _chatController.setMessages(
      messages
          .where((message) => message.kind != 'summary')
          .map(_toChatMessage)
          .toList(growable: false),
      animated: false,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _draftMessage = null;
    });
  }

  chat.TextMessage _toChatMessage(AiMessage message) {
    return chat.Message.text(
          id: message.id,
          authorId: message.role == 'user' ? _currentUserId : _assistantUserId,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            message.createdAt,
            isUtc: true,
          ),
          sentAt: DateTime.fromMillisecondsSinceEpoch(
            message.createdAt,
            isUtc: true,
          ),
          metadata: {'kind': message.kind, 'persisted': true},
          status: chat.MessageStatus.sent,
          text: message.content,
        )
        as chat.TextMessage;
  }

  Future<void> _send(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty || _running) return;
    final timestamp = DateTime.now().toUtc();
    final sequence = _ephemeralSequence++;
    final userMessage = chat.Message.text(
      id: 'pending-user-${timestamp.microsecondsSinceEpoch}-$sequence',
      authorId: _currentUserId,
      createdAt: timestamp,
      sentAt: timestamp,
      status: chat.MessageStatus.sent,
      text: value,
    );
    final draft =
        chat.Message.text(
              id: 'pending-assistant-${timestamp.microsecondsSinceEpoch}-$sequence',
              authorId: _assistantUserId,
              createdAt: timestamp.add(const Duration(microseconds: 1)),
              metadata: {
                'draft': true,
                'statusText': context.tr(
                  '正在核对 Transcript…',
                  'Checking transcript…',
                  '文字起こしを確認中…',
                ),
              },
              status: chat.MessageStatus.sending,
              text: '',
            )
            as chat.TextMessage;
    setState(() {
      _running = true;
      _status = context.tr(
        '正在核对 Transcript…',
        'Checking transcript…',
        '文字起こしを確認中…',
      );
      _draftMessage = draft;
    });
    await _chatController.insertMessage(userMessage);
    await _chatController.insertMessage(draft);
    await _subscription?.cancel();
    if (!mounted) return;
    final languageCode = _resolvedAiServiceLanguageCode(ref);
    _subscription = ref
        .read(aiAssistantServiceProvider)
        .ask(widget.scope, value, languageCode: languageCode)
        .listen((update) => unawaited(_applyConversationUpdate(update)));
  }

  Future<void> _applyConversationUpdate(AiAgentUpdate update) async {
    if (!mounted) return;
    switch (update.type) {
      case AiAgentUpdateType.status:
        final status = update.text ?? '';
        setState(() => _status = status);
        await _updateDraft(statusText: status);
      case AiAgentUpdateType.resetText:
        await _updateDraft(text: '');
      case AiAgentUpdateType.textDelta:
        await _updateDraft(
          text: '${_draftMessage?.text ?? ''}${update.text ?? ''}',
        );
      case AiAgentUpdateType.completed:
        setState(() {
          _running = false;
          _status = null;
        });
        await _loadMessages();
      case AiAgentUpdateType.failed:
        final error =
            update.text ?? context.tr('请求失败', 'Request failed', 'リクエストに失敗しました');
        setState(() {
          _running = false;
          _status = null;
        });
        await _updateDraft(
          text: _draftMessage?.text.trim().isNotEmpty == true
              ? _draftMessage!.text
              : error,
          statusText: error,
          failed: true,
        );
    }
  }

  Future<void> _updateDraft({
    String? text,
    String? statusText,
    bool failed = false,
  }) async {
    final previous = _draftMessage;
    if (previous == null) return;
    final updated = previous.copyWith(
      text: text ?? previous.text,
      updatedAt: DateTime.now().toUtc(),
      failedAt: failed ? DateTime.now().toUtc() : previous.failedAt,
      metadata: {
        ...?previous.metadata,
        'draft': true,
        'statusText': statusText ?? _status,
        'failed': failed,
      },
      status: failed ? chat.MessageStatus.error : chat.MessageStatus.sending,
    );
    _draftMessage = updated;
    await _chatController.updateMessage(previous, updated);
  }

  Future<chat.User?> _resolveUser(chat.UserID id) async {
    return chat.User(
      id: id,
      name: id == _currentUserId ? context.tr('你', 'You', 'あなた') : 'Lumina AI',
    );
  }

  chat.ChatTheme _chatTheme(BuildContext context) {
    return chat.ChatTheme(
      colors: chat.ChatColors(
        primary: context.appAccent,
        onPrimary: Colors.black,
        surface: context.appBackground,
        onSurface: context.appTextPrimary,
        surfaceContainer: context.appSurface,
        surfaceContainerLow: context.appSurface,
        surfaceContainerHigh: context.appSurfaceHighlight,
      ),
      typography: chat.ChatTypography.fromThemeData(Theme.of(context)),
      shape: BorderRadius.circular(context.appDesign.radiusMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    return Scaffold(
      backgroundColor: context.appBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        foregroundColor: context.appTextPrimary,
        title: const Text('AI Summary'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : chat_ui.Chat(
              currentUserId: _currentUserId,
              resolveUser: _resolveUser,
              chatController: _chatController,
              theme: _chatTheme(context),
              backgroundColor: context.appBackground,
              onMessageSend: _send,
              builders: chat.Builders(
                chatAnimatedListBuilder: (context, itemBuilder) =>
                    chat_ui.ChatAnimatedList(
                      key: const ValueKey('ai-conversation-messages'),
                      itemBuilder: itemBuilder,
                      topPadding: design.spaceMd,
                      bottomPadding: design.spaceLg,
                      initialScrollToEndMode:
                          chat_ui.InitialScrollToEndMode.jump,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                    ),
                textMessageBuilder:
                    (
                      context,
                      message,
                      index, {
                      required isSentByMe,
                      groupStatus,
                    }) => _ChatTextMessage(
                      message: message,
                      isSentByMe: isSentByMe,
                      onCitationTap: widget.onCitationTap,
                    ),
                composerBuilder: (context) => chat_ui.Composer(
                  key: const ValueKey('ai-follow-up-input'),
                  textEditingController: _question,
                  padding: EdgeInsets.fromLTRB(
                    design.spaceLg,
                    design.spaceMd,
                    design.spaceLg,
                    design.spaceLg,
                  ),
                  sigmaX: 0,
                  sigmaY: 0,
                  backgroundColor: context.appSurface,
                  inputFillColor: context.appSurfaceHighlight,
                  inputBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.appSurfaceHighlight),
                    borderRadius: BorderRadius.circular(design.radiusLarge),
                  ),
                  hintText: context.tr(
                    '继续提问…',
                    'Ask a follow-up question…',
                    '続けて質問…',
                  ),
                  hintColor: context.appTextSecondary,
                  textColor: context.appTextPrimary,
                  keyboardAppearance: Theme.of(context).brightness,
                  minLines: 1,
                  maxLines: 4,
                  sendButtonDisabled: _running,
                  sendButtonVisibilityMode:
                      chat_ui.SendButtonVisibilityMode.disabled,
                  sendIconColor: context.appAccent,
                  emptyFieldSendIconColor: context.appTextSecondary,
                  sendIcon: const Icon(
                    Icons.arrow_upward_rounded,
                    key: ValueKey('ai-follow-up-send'),
                  ),
                ),
                emptyChatListBuilder: (context) =>
                    const _ConversationEmptyState(),
              ),
            ),
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState();

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        design.spaceXl,
        design.spaceXxl,
        design.spaceXl,
        design.spaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 28,
            color: context.appTextSecondary.withValues(alpha: 0.8),
          ),
          SizedBox(height: design.spaceMd),
          Text(
            context.tr(
              '针对当前内容继续提问',
              'Ask about the current content',
              '現在の内容について質問',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: design.spaceSm),
          Text(
            context.tr(
              '回答会基于 Transcript，并附上可查看的引用。',
              'Answers stay grounded in the transcript with tappable references.',
              '回答は文字起こしに基づき、タップできる参照が付きます。',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTextMessage extends StatelessWidget {
  final chat.TextMessage message;
  final bool isSentByMe;
  final AiCitationCallback? onCitationTap;

  const _ChatTextMessage({
    required this.message,
    required this.isSentByMe,
    this.onCitationTap,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final isDraft = message.metadata?['draft'] == true;
    final failed = message.metadata?['failed'] == true;
    final statusText = message.metadata?['statusText'] as String?;
    final waiting = isDraft && message.text.trim().isEmpty;

    return Container(
      constraints: BoxConstraints(
        maxWidth: isSentByMe ? MediaQuery.sizeOf(context).width * 0.78 : 560,
      ),
      padding: EdgeInsets.all(design.spaceMd),
      decoration: BoxDecoration(
        color: isSentByMe ? context.appSurfaceHighlight : context.appSurface,
        borderRadius: BorderRadius.circular(design.radiusMedium),
        border: isSentByMe
            ? null
            : Border.all(
                color: failed ? Colors.redAccent : context.appSurfaceHighlight,
              ),
      ),
      child: waiting
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: failed ? Colors.redAccent : context.appAccent,
                  ),
                ),
                SizedBox(width: design.spaceSm),
                Flexible(
                  child: Text(
                    statusText ?? '',
                    style: TextStyle(
                      color: failed
                          ? Colors.redAccent
                          : context.appTextSecondary,
                    ),
                  ),
                ),
              ],
            )
          : isSentByMe
          ? Text(message.text, style: TextStyle(color: context.appTextPrimary))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AiAnswerText(text: message.text, onCitationTap: onCitationTap),
                if (isDraft && statusText?.trim().isNotEmpty == true) ...[
                  SizedBox(height: design.spaceSm),
                  Text(
                    statusText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: failed
                          ? Colors.redAccent
                          : context.appTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
