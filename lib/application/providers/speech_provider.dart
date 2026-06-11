import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

final speechToTextProvider = Provider<SpeechToText>((ref) {
  return SpeechToText();
});

final speechAvailableProvider = FutureProvider<bool>((ref) async {
  final stt = ref.watch(speechToTextProvider);
  return await stt.initialize();
});

final isListeningProvider = StateProvider<bool>((ref) => false);

final lastWordsProvider = StateProvider<String>((ref) => '');

final speechProvider = Provider((ref) {
  return SpeechService(ref.watch(speechToTextProvider), ref);
});

class SpeechService {
  final SpeechToText _stt;
  final Ref _ref;

  SpeechService(this._stt, this._ref);

  Future<bool> initialize() async {
    return await _stt.initialize();
  }

  Future<void> startListening({required Function(String) onResult}) async {
    _ref.read(isListeningProvider.notifier).state = true;
    _ref.read(lastWordsProvider.notifier).state = '';

    await _stt.listen(
      onResult: (result) {
        _ref.read(lastWordsProvider.notifier).state = result.recognizedWords;
        onResult(result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'es_ES',
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _ref.read(isListeningProvider.notifier).state = false;
  }
}