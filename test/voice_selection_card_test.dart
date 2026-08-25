import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/presentation/widgets/voice_selection_card.dart';
import 'package:lumina/tts/models/tts_voice.dart';

void main() {
  const english = TtsVoice(
    id: 'english',
    name: 'English',
    providerId: 'test',
    type: VoiceType.preset,
    providerVoiceId: 'english',
    languages: ['en-US'],
    createdAt: 1,
  );
  const chinese = TtsVoice(
    id: 'chinese',
    name: 'Chinese',
    providerId: 'test',
    type: VoiceType.preset,
    providerVoiceId: 'chinese',
    languages: ['zh-CN'],
    createdAt: 1,
  );

  test('book language defaults to a voice with the same base language', () {
    expect(voiceMatchingLanguage([english, chinese], 'zh'), same(chinese));
    expect(voiceMatchingLanguage([chinese, english], 'en-GB'), same(english));
  });

  test('language matching accepts names and multiple book languages', () {
    expect(
      voiceMatchingLanguage([english, chinese], 'fr, Chinese'),
      same(chinese),
    );
    expect(voiceMatchingLanguage([english], null), isNull);
  });
}
