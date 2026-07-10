import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/reading_level_estimator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('estimates CEFR-J level from sampled English vocabulary', () async {
    final text = [
      List.filled(85, 'about').join(' '),
      List.filled(15, 'abandon').join(' '),
    ].join(' ');

    final estimate = await ReadingLevelEstimator.instance.estimateEnglish([
      text,
    ]);

    expect(estimate, isNotNull);
    expect(estimate!.system, cefrJReadingLevelSystem);
    expect(estimate.code, 'B1');
    expect(estimate.source, estimatedReadingLevelSource);
  });

  test('returns null when too few known words are available', () async {
    final estimate = await ReadingLevelEstimator.instance.estimateEnglish([
      'qwertyzz qwertyzz qwertyzz',
    ]);

    expect(estimate, isNull);
  });

  test('finds CEFR-J level for a single dictionary term', () async {
    final estimate = await ReadingLevelEstimator.instance.levelForEnglishTerm(
      'abandon',
    );

    expect(estimate, isNotNull);
    expect(estimate!.code, 'B1');
    expect(estimate.source, cefrJVocabularyProfileSource);
  });
}
