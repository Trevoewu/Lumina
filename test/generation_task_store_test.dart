import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/services/generation_task_store.dart';

void main() {
  test(
    'task and chunk identifiers are stable and running work is recoverable',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final store = GenerationTaskStore(database);
      final taskId = generationTaskId(
        kind: GenerationTaskKind.tts,
        parentId: 'book',
        scopeId: 'chapter',
        contentFingerprint: 'content-v1',
        configFingerprint: 'config-v1',
      );
      final spec = GenerationTaskSpec(
        id: taskId,
        kind: GenerationTaskKind.tts,
        parentId: 'book',
        scopeId: 'chapter',
        contentFingerprint: 'content-v1',
        configFingerprint: 'config-v1',
        configJson: '{}',
      );
      final chunks = [
        for (var index = 0; index < 2; index++)
          GenerationChunkSpec(
            id: '$taskId:$index',
            chunkIndex: index,
            sourceKey: 'p$index',
            startMs: 0,
            endMs: 0,
            inputFingerprint: 'paragraph-v$index',
          ),
      ];

      await store.ensureTask(spec: spec, chunks: chunks);
      await store.startTask(taskId);
      final started = await store.startChunk(chunks.first.id);
      expect(started.attempts, 0);
      await store.completeChunk(chunks.first.id, resultRef: 'chapter/p0.mp3');

      // A second foreground run resets only the in-flight chunk. The completed
      // result remains reusable and its attempt count is retained.
      await store.ensureTask(spec: spec, chunks: chunks);
      final task = await database.getGenerationTask(taskId);
      final persisted = await database.getGenerationTaskChunks(taskId);
      expect(task?.status, GenerationChunkStatus.pending.name);
      expect(persisted[0].status, GenerationChunkStatus.complete.name);
      expect(persisted[0].resultRef, 'chapter/p0.mp3');
      expect(persisted[0].attempts, 1);
      expect(persisted[1].status, GenerationChunkStatus.pending.name);
      expect(
        generationTaskId(
          kind: GenerationTaskKind.tts,
          parentId: 'book',
          scopeId: 'chapter',
          contentFingerprint: 'content-v1',
          configFingerprint: 'config-v1',
        ),
        taskId,
      );
    },
  );
}
