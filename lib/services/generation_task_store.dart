import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../data/database/app_database.dart';

/// The two long-running generators share the same durable task vocabulary.
enum GenerationTaskKind { tts, whisper }

enum GenerationChunkStatus { pending, running, complete, failed }

class GenerationTaskSpec {
  final String id;
  final GenerationTaskKind kind;
  final String parentId;
  final String scopeId;
  final String contentFingerprint;
  final String configFingerprint;
  final String configJson;
  final int priority;

  const GenerationTaskSpec({
    required this.id,
    required this.kind,
    required this.parentId,
    required this.scopeId,
    required this.contentFingerprint,
    required this.configFingerprint,
    required this.configJson,
    this.priority = 0,
  });
}

class GenerationChunkSpec {
  final String id;
  final int chunkIndex;
  final String sourceKey;
  final int startMs;
  final int endMs;
  final String inputFingerprint;
  final int priority;
  final String? resultRef;

  const GenerationChunkSpec({
    required this.id,
    required this.chunkIndex,
    required this.sourceKey,
    required this.startMs,
    required this.endMs,
    required this.inputFingerprint,
    this.priority = 0,
    this.resultRef,
  });
}

/// Small persistence facade used by both TTS and Whisper.
///
/// A running row is deliberately reset to pending when a new foreground run
/// claims the task. This is the recovery path for a force-quit or OS kill:
/// completed chunks remain complete, while a chunk whose provider call was in
/// flight is retried safely.
class GenerationTaskStore {
  final AppDatabase database;

  const GenerationTaskStore(this.database);

  Future<GenerationTask> ensureTask({
    required GenerationTaskSpec spec,
    required List<GenerationChunkSpec> chunks,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await database.getGenerationTask(spec.id);
    if (existing == null) {
      await database.upsertGenerationTask(
        GenerationTasksCompanion(
          id: Value(spec.id),
          kind: Value(spec.kind.name),
          parentId: Value(spec.parentId),
          scopeId: Value(spec.scopeId),
          contentFingerprint: Value(spec.contentFingerprint),
          configFingerprint: Value(spec.configFingerprint),
          configJson: Value(spec.configJson),
          status: Value(GenerationChunkStatus.pending.name),
          priority: Value(spec.priority),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    } else if (existing.status == GenerationChunkStatus.running.name) {
      await database.updateGenerationTask(
        spec.id,
        status: GenerationChunkStatus.pending.name,
        error: null,
      );
    }

    final current = {
      for (final chunk in await database.getGenerationTaskChunks(spec.id))
        chunk.id: chunk,
    };
    for (final specChunk in chunks) {
      final old = current[specChunk.id];
      final inputChanged =
          old != null && old.inputFingerprint != specChunk.inputFingerprint;
      if (old == null || inputChanged) {
        await database.upsertGenerationTaskChunk(
          GenerationTaskChunksCompanion(
            id: Value(specChunk.id),
            taskId: Value(spec.id),
            chunkIndex: Value(specChunk.chunkIndex),
            sourceKey: Value(specChunk.sourceKey),
            startMs: Value(specChunk.startMs),
            endMs: Value(specChunk.endMs),
            inputFingerprint: Value(specChunk.inputFingerprint),
            status: Value(GenerationChunkStatus.pending.name),
            priority: Value(specChunk.priority),
            resultRef: specChunk.resultRef == null
                ? const Value.absent()
                : Value(specChunk.resultRef),
            updatedAt: Value(now),
          ),
        );
        continue;
      }

      // A completed row is not enough by itself: the caller verifies the
      // referenced file/result and can reset it with resetChunk if it vanished.
      final recoveredStatus = old.status == GenerationChunkStatus.running.name
          ? GenerationChunkStatus.pending.name
          : old.status;
      await database.upsertGenerationTaskChunk(
        GenerationTaskChunksCompanion(
          id: Value(old.id),
          taskId: Value(old.taskId),
          chunkIndex: Value(specChunk.chunkIndex),
          sourceKey: Value(specChunk.sourceKey),
          startMs: Value(specChunk.startMs),
          endMs: Value(specChunk.endMs),
          inputFingerprint: Value(old.inputFingerprint),
          status: Value(recoveredStatus),
          attempts: Value(old.attempts),
          priority: Value(specChunk.priority),
          resultRef: old.resultRef == null
              ? const Value.absent()
              : Value(old.resultRef),
          resultJson: old.resultJson == null
              ? const Value.absent()
              : Value(old.resultJson),
          error: old.error == null ? const Value.absent() : Value(old.error),
          updatedAt: Value(old.updatedAt),
          startedAt: old.startedAt == null
              ? const Value.absent()
              : Value(old.startedAt),
          completedAt: old.completedAt == null
              ? const Value.absent()
              : Value(old.completedAt),
        ),
      );
    }

    final refreshed = await database.getGenerationTask(spec.id);
    if (refreshed == null) throw StateError('无法持久化生成任务 ${spec.id}');
    return refreshed;
  }

  Future<List<GenerationTaskChunk>> chunks(String taskId) {
    return database.getGenerationTaskChunks(taskId);
  }

  Future<void> startTask(String taskId, {int priority = 0}) {
    return database.updateGenerationTask(
      taskId,
      status: GenerationChunkStatus.running.name,
      priority: priority,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      error: null,
    );
  }

  Future<void> completeTask(String taskId) {
    return database.updateGenerationTask(
      taskId,
      status: GenerationChunkStatus.complete.name,
      completedAt: DateTime.now().millisecondsSinceEpoch,
      error: null,
    );
  }

  Future<void> failTask(String taskId, Object error) {
    return database.updateGenerationTask(
      taskId,
      status: GenerationChunkStatus.failed.name,
      error: error.toString(),
    );
  }

  Future<GenerationTaskChunk> startChunk(String chunkId) async {
    final chunk = await database.getGenerationTaskChunk(chunkId);
    if (chunk == null) throw StateError('找不到生成分片 $chunkId');
    await database.updateGenerationTaskChunk(
      chunkId,
      status: GenerationChunkStatus.running.name,
      attempts: chunk.attempts + 1,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      error: null,
    );
    return chunk;
  }

  Future<void> completeChunk(
    String chunkId, {
    String? resultRef,
    String? resultJson,
  }) {
    return database.updateGenerationTaskChunk(
      chunkId,
      status: GenerationChunkStatus.complete.name,
      resultRef: resultRef,
      resultJson: resultJson,
      completedAt: DateTime.now().millisecondsSinceEpoch,
      error: null,
    );
  }

  Future<void> failChunk(String chunkId, Object error) {
    return database.updateGenerationTaskChunk(
      chunkId,
      status: GenerationChunkStatus.failed.name,
      error: error.toString(),
    );
  }

  Future<void> resetChunk(String chunkId) {
    return database.updateGenerationTaskChunk(
      chunkId,
      status: GenerationChunkStatus.pending.name,
      resultRef: '',
      resultJson: '',
      error: null,
    );
  }
}

String generationFingerprint(Iterable<String> parts) {
  final source = parts.map((part) => '${part.length}:$part').join('\u001f');
  return sha256.convert(utf8.encode(source)).toString();
}

String generationTaskId({
  required GenerationTaskKind kind,
  required String parentId,
  required String scopeId,
  required String contentFingerprint,
  required String configFingerprint,
}) {
  return '${kind.name}:${generationFingerprint([parentId, scopeId, contentFingerprint, configFingerprint])}';
}

String ttsConfigJson({
  required String providerId,
  required String voiceId,
  required double speed,
  String providerConfiguration = '',
}) {
  return jsonEncode({
    'providerId': providerId,
    'voiceId': voiceId,
    'speed': speed,
    if (providerConfiguration.isNotEmpty)
      'providerConfiguration': providerConfiguration,
  });
}
