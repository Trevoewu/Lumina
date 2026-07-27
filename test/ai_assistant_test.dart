import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/ai/ai_assistant_service.dart';
import 'package:lumina/ai/ai_models.dart';
import 'package:lumina/ai/ai_thread_repository.dart';
import 'package:lumina/ai/transcript_tool.dart';
import 'package:lumina/data/database/app_database.dart';

void main() {
  test('citation parser resolves paragraph and timestamp references', () {
    final citations = extractAiCitations(
      'A claim [P3], another [12:45], and a long episode [01:02:03]. [P3]',
    );

    expect(citations, hasLength(3));
    expect(citations[0].paragraphIndex, 3);
    expect(citations[1].positionMs, 765000);
    expect(citations[2].positionMs, 3723000);
  });

  test(
    'transcript tools expose bounded referenced chunks and search',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.insertParagraphs(const [
        Paragraph(
          id: 'paragraph-1',
          chapterId: 'chapter-1',
          bookId: 'book-1',
          paragraphIndex: 0,
          content: 'Alice enters the garden.',
        ),
        Paragraph(
          id: 'paragraph-2',
          chapterId: 'chapter-1',
          bookId: 'book-1',
          paragraphIndex: 1,
          content: 'The white rabbit checks a watch.',
        ),
      ]);
      const scope = AiContentScope(
        type: AiScopeType.chapter,
        id: 'chapter-1',
        parentId: 'book-1',
        title: 'Down the Rabbit-Hole',
        parentTitle: 'Alice',
      );
      final tools = AiTranscriptTools(database);
      final snapshot = await tools.load(scope);

      expect(snapshot.isAvailable, isTrue);
      final chunk =
          jsonDecode(
                tools.execute(snapshot, 'read_transcript', {
                  'cursor': 0,
                  'max_characters': 1000,
                }),
              )
              as Map<String, dynamic>;
      expect(chunk['has_more'], isFalse);
      expect(
        (chunk['items'] as List<dynamic>).map(
          (item) => (item as Map<String, dynamic>)['reference'],
        ),
        ['P1', 'P2'],
      );

      final search =
          jsonDecode(
                tools.execute(snapshot, 'search_transcript', {
                  'query': 'rabbit',
                  'limit': 4,
                }),
              )
              as Map<String, dynamic>;
      expect(search['items'], hasLength(1));
      expect((search['items'] as List<dynamic>).single['reference'], 'P2');
    },
  );

  test(
    'Responses agent runs a local transcript tool and persists summary',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(database.close);
      addTearDown(server.close);
      await database.insertParagraphs(const [
        Paragraph(
          id: 'paragraph-1',
          chapterId: 'chapter-agent',
          bookId: 'book-agent',
          paragraphIndex: 0,
          content: 'The chapter begins with a storm.',
        ),
      ]);
      final requestBodies = <Map<String, dynamic>>[];
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        requestBodies.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        if (requestCount == 1 || requestCount == 3) {
          final followUp = requestCount == 3;
          final responseId = followUp ? 'resp-question-tool' : 'resp-tool';
          final callId = followUp ? 'call-search' : 'call-read';
          final toolName = followUp ? 'search_transcript' : 'read_transcript';
          final arguments = followUp
              ? {'query': 'storm', 'limit': 4}
              : {'cursor': 0, 'max_characters': 12000};
          request.response.write(
            _sse({
              'type': 'response.created',
              'response': {'id': responseId},
            }),
          );
          request.response.write(
            _sse({
              'type': 'response.output_item.done',
              'item': {
                'type': 'function_call',
                'call_id': callId,
                'name': toolName,
                'arguments': jsonEncode(arguments),
              },
            }),
          );
          request.response.write(
            _sse({
              'type': 'response.completed',
              'response': {'id': responseId, 'output': <Object>[]},
            }),
          );
        } else {
          final followUp = requestCount == 4;
          final responseId = followUp ? 'resp-answer' : 'resp-final';
          final answer = followUp
              ? 'The storm establishes the opening atmosphere. [P1]'
              : 'Summary\nA storm opens the chapter. [P1]\n\n'
                    'Key points\n• The weather sets the scene. [P1]';
          request.response.write(
            _sse({
              'type': 'response.created',
              'response': {'id': responseId},
            }),
          );
          request.response.write(
            _sse({'type': 'response.output_text.delta', 'delta': answer}),
          );
          request.response.write(
            _sse({
              'type': 'response.completed',
              'response': {'id': responseId, 'output': <Object>[]},
            }),
          );
        }
        await request.response.close();
      });

      const scope = AiContentScope(
        type: AiScopeType.chapter,
        id: 'chapter-agent',
        parentId: 'book-agent',
        title: 'The Storm',
        parentTitle: 'Test Book',
      );
      final repository = AiThreadRepository(database);
      final service = AiAssistantService(
        transcriptTools: AiTranscriptTools(database),
        threads: repository,
        configurationLoader: () async => AiServiceConfiguration(
          baseUrl: 'http://${server.address.host}:${server.port}/v1',
          apiKey: 'test-key',
          modelId: 'gpt-test',
        ),
      );

      final updates = await service
          .summarize(scope, languageCode: 'en')
          .toList();

      expect(requestCount, 2);
      expect(requestBodies.first['tool_choice'], 'required');
      final toolOutputs = requestBodies[1]['input'] as List<dynamic>;
      expect(toolOutputs.single['call_id'], 'call-read');
      expect(toolOutputs.single['output'], contains('"reference":"P1"'));
      expect(
        updates.where((update) => update.type == AiAgentUpdateType.textDelta),
        isNotEmpty,
      );
      expect(updates.last.type, AiAgentUpdateType.completed);

      final thread = await repository.load(scope);
      expect(thread?.lastResponseId, 'resp-final');
      expect(thread?.summaryText, contains('A storm opens the chapter. [P1]'));
      final messages = await repository.messages(thread!.id);
      expect(messages, hasLength(1));
      expect(messages.single.kind, 'summary');

      final followUpUpdates = await service
          .ask(scope, 'What role does the storm play?', languageCode: 'en')
          .toList();
      expect(requestCount, 4);
      expect(requestBodies[2]['previous_response_id'], 'resp-final');
      expect(
        (requestBodies[3]['input'] as List<dynamic>).single['call_id'],
        'call-search',
      );
      expect(followUpUpdates.last.responseId, 'resp-answer');
      final updatedThread = await repository.load(scope);
      expect(updatedThread?.lastResponseId, 'resp-answer');
      final updatedMessages = await repository.messages(updatedThread!.id);
      expect(updatedMessages.map((message) => message.role), [
        'assistant',
        'user',
        'assistant',
      ]);
    },
  );

  test(
    'Chat Completions agent supports DeepSeek tools and local history',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(database.close);
      addTearDown(server.close);
      await database.insertParagraphs(const [
        Paragraph(
          id: 'paragraph-deepseek',
          chapterId: 'chapter-deepseek',
          bookId: 'book-deepseek',
          paragraphIndex: 0,
          content: 'The lighthouse beam disappears during the storm.',
        ),
      ]);
      final requestPaths = <String>[];
      final requestBodies = <Map<String, dynamic>>[];
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        requestPaths.add(request.uri.path);
        requestBodies.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        final isToolTurn = requestCount.isOdd;
        if (isToolTurn) {
          final followUp = requestCount == 3;
          final responseId = followUp ? 'chat-question-tool' : 'chat-tool';
          final callId = followUp ? 'chat-call-search' : 'chat-call-read';
          final toolName = followUp ? 'search_transcript' : 'read_transcript';
          final arguments = followUp
              ? {'query': 'lighthouse', 'limit': 4}
              : {'cursor': 0, 'max_characters': 12000};
          request.response.write(
            _sse({
              'id': responseId,
              'choices': [
                {
                  'index': 0,
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': callId,
                        'type': 'function',
                        'function': {
                          'name': toolName,
                          'arguments': jsonEncode(arguments),
                        },
                      },
                    ],
                  },
                  'finish_reason': 'tool_calls',
                },
              ],
            }),
          );
        } else {
          final followUp = requestCount == 4;
          request.response.write(
            _sse({
              'id': followUp ? 'chat-answer' : 'chat-final',
              'choices': [
                {
                  'index': 0,
                  'delta': {
                    'content': followUp
                        ? 'The lighthouse creates the central mystery. [P1]'
                        : 'Summary\nThe lighthouse fails in a storm. [P1]\n\n'
                              'Key points\n• Its beam disappears. [P1]',
                  },
                  'finish_reason': 'stop',
                },
              ],
            }),
          );
        }
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      const scope = AiContentScope(
        type: AiScopeType.chapter,
        id: 'chapter-deepseek',
        parentId: 'book-deepseek',
        title: 'The Lighthouse',
        parentTitle: 'Test Book',
      );
      final repository = AiThreadRepository(database);
      final service = AiAssistantService(
        transcriptTools: AiTranscriptTools(database),
        threads: repository,
        configurationLoader: () async => AiServiceConfiguration(
          baseUrl: 'http://${server.address.host}:${server.port}',
          apiKey: 'deepseek-test-key',
          modelId: 'deepseek-v4-flash',
          protocol: AiApiProtocol.chatCompletions,
          disableThinking: true,
        ),
      );

      final summaryUpdates = await service
          .summarize(scope, languageCode: 'en')
          .toList();
      expect(summaryUpdates.last.type, AiAgentUpdateType.completed);
      expect(requestPaths, ['/chat/completions', '/chat/completions']);
      expect(requestBodies.first['tool_choice'], 'required');
      expect(requestBodies.first['thinking'], {'type': 'disabled'});
      expect(
        requestBodies.first['tools'][0]['function']['name'],
        'read_transcript',
      );
      final toolMessages = requestBodies[1]['messages'] as List<dynamic>;
      expect(toolMessages[2]['role'], 'assistant');
      expect(toolMessages[3]['role'], 'tool');
      expect(toolMessages[3]['content'], contains('"reference":"P1"'));

      final followUpUpdates = await service
          .ask(scope, 'Why is the lighthouse important?', languageCode: 'en')
          .toList();
      expect(followUpUpdates.last.responseId, 'chat-answer');
      expect(requestCount, 4);
      final historyMessages = requestBodies[2]['messages'] as List<dynamic>;
      expect(
        historyMessages.any(
          (message) =>
              message['role'] == 'assistant' &&
              (message['content'] as String).contains('lighthouse fails'),
        ),
        isTrue,
      );
      expect(
        (historyMessages.last['content'] as String),
        contains('Why is the lighthouse important?'),
      );
    },
  );
}

String _sse(Map<String, dynamic> payload) => 'data: ${jsonEncode(payload)}\n\n';
