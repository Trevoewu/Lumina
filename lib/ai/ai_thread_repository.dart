import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import 'ai_models.dart';
import 'transcript_tool.dart';

class AiThreadRepository {
  final AppDatabase database;
  final Uuid _uuid;

  AiThreadRepository(this.database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  Future<AiThread?> load(AiContentScope scope) =>
      database.getAiThread(scope.type.value, scope.id);

  Future<List<AiMessage>> messages(String threadId) =>
      database.getAiMessages(threadId);

  Future<AiThread> ensure({
    required AiTranscriptSnapshot snapshot,
    required String modelId,
  }) async {
    final scope = snapshot.scope;
    final existing = await load(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      final thread = AiThread(
        id: _uuid.v4(),
        scopeType: scope.type.value,
        scopeId: scope.id,
        scopeParentId: scope.parentId,
        contentFingerprint: snapshot.fingerprint,
        modelId: modelId,
        createdAt: now,
        updatedAt: now,
      );
      await database.upsertAiThread(thread);
      return thread;
    }
    if (existing.contentFingerprint == snapshot.fingerprint) {
      if (existing.modelId == modelId) return existing;
      final updated = AiThread(
        id: existing.id,
        scopeType: existing.scopeType,
        scopeId: existing.scopeId,
        scopeParentId: existing.scopeParentId,
        contentFingerprint: existing.contentFingerprint,
        summaryText: existing.summaryText,
        modelId: modelId,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      await database.upsertAiThread(updated);
      return updated;
    }

    await database.deleteAiMessages(existing.id);
    final refreshed = AiThread(
      id: existing.id,
      scopeType: scope.type.value,
      scopeId: scope.id,
      scopeParentId: scope.parentId,
      contentFingerprint: snapshot.fingerprint,
      modelId: modelId,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await database.upsertAiThread(refreshed);
    return refreshed;
  }

  Future<void> addUserMessage(AiThread thread, String content) {
    return database.insertAiMessage(
      AiMessage(
        id: _uuid.v4(),
        threadId: thread.id,
        role: 'user',
        kind: 'chat',
        content: content,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<AiThread> resetForSummary(AiThread thread, String modelId) async {
    await database.deleteAiMessages(thread.id);
    final reset = AiThread(
      id: thread.id,
      scopeType: thread.scopeType,
      scopeId: thread.scopeId,
      scopeParentId: thread.scopeParentId,
      contentFingerprint: thread.contentFingerprint,
      modelId: modelId,
      createdAt: thread.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await database.upsertAiThread(reset);
    return reset;
  }

  Future<void> saveAssistantMessage({
    required AiThread thread,
    required String content,
    required String responseId,
    required String modelId,
    bool isSummary = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (isSummary) {
      await database.deleteAiMessages(thread.id, kind: 'summary');
    }
    final citationLabels = extractAiCitations(
      content,
    ).map((citation) => citation.label).toList(growable: false);
    await database.insertAiMessage(
      AiMessage(
        id: _uuid.v4(),
        threadId: thread.id,
        role: 'assistant',
        kind: isSummary ? 'summary' : 'chat',
        content: content,
        citationsJson: citationLabels.isEmpty
            ? null
            : jsonEncode(citationLabels),
        responseId: responseId,
        createdAt: now,
      ),
    );
    await database.upsertAiThread(
      AiThread(
        id: thread.id,
        scopeType: thread.scopeType,
        scopeId: thread.scopeId,
        scopeParentId: thread.scopeParentId,
        contentFingerprint: thread.contentFingerprint,
        summaryText: isSummary ? content : thread.summaryText,
        remoteConversationId: thread.remoteConversationId,
        lastResponseId: responseId,
        modelId: modelId,
        createdAt: thread.createdAt,
        updatedAt: now,
      ),
    );
  }
}
