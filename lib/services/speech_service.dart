import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static final SpeechToText _speech = SpeechToText();

  static final ValueNotifier<String?> activeField = ValueNotifier(null);

  static bool _initialized = false;

  static Future<bool> initialize() async {
    if (_initialized) return true;

    _initialized = await _speech.initialize(
      onStatus: (status) {
        print("Speech Status : $status");

        if (status == "done" ||
            status == "notListening") {
          activeField.value = null;
        }
      },
      onError: (error) {
        print("Speech Error : $error");
        activeField.value = null;
      },
    );

    return _initialized;
  }

  static Future<void> toggleListening(
      String fieldName,
      Function(String) onResult,
  ) async {

    bool available = await initialize();

    if (!available) return;

    // Stop if this same field is recording
    if (activeField.value == fieldName) {
      await _speech.stop();
      activeField.value = null;
      return;
    }

    // Stop any previous field
    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    activeField.value = fieldName;

    await _speech.listen(
      localeId: "en-US",
      partialResults: true,
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          onResult(result.recognizedWords);
        }

        if (result.finalResult) {
          activeField.value = null;
        }
      },
    );
  }
  static Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }

    activeField.value = null;
  }
}