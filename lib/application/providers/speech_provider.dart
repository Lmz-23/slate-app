import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

final speechToTextProvider = Provider<SpeechToText>((ref) {
  return SpeechToText();
});

final isListeningProvider = StateProvider<bool>((ref) => false);

final lastWordsProvider = StateProvider<String>((ref) => '');

final partialWordsProvider = StateProvider<String>((ref) => '');

final speechProvider = Provider((ref) {
  return SpeechService(ref.watch(speechToTextProvider), ref);
});

class SpeechService {
  final SpeechToText _stt;
  final Ref _ref;
  String _lastWords = '';

  SpeechService(this._stt, this._ref);

  Future<bool> initialize() async {
    return await _stt.initialize();
  }

  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
  }) async {
    _ref.read(isListeningProvider.notifier).state = true;
    _ref.read(lastWordsProvider.notifier).state = '';
    _ref.read(partialWordsProvider.notifier).state = '';
    _lastWords = '';

    // Start listening with continuous results
    await _stt.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        _lastWords = words;
        _ref.read(lastWordsProvider.notifier).state = words;
        _ref.read(partialWordsProvider.notifier).state = words;
        onResult(words);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'es_ES',
      cancelOnError: false,
      partialResults: true,
    );

    // Update partial results periodically while listening
    _updatePartialResults(onPartialResult);
  }

  void _updatePartialResults(Function(String)? onPartialResult) async {
    while (_ref.read(isListeningProvider)) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_lastWords.isNotEmpty && _lastWords != _ref.read(partialWordsProvider)) {
        _ref.read(partialWordsProvider.notifier).state = _lastWords;
        onPartialResult?.call(_lastWords);
      }
    }
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _ref.read(isListeningProvider.notifier).state = false;
    _ref.read(partialWordsProvider.notifier).state = '';
  }
}
