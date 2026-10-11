import 'package:flutter/material.dart';

import '../services/speech_service.dart';

class VoiceIconButton extends StatelessWidget {

  final Function(String) onResult;
  final String fieldName;

  final VoidCallback? beforeListening;

  const VoiceIconButton({
    super.key,
    required this.fieldName,
    required this.onResult,
    this.beforeListening,
  });

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder(

      valueListenable: SpeechService.activeField,

      builder: (_, activeField, __) {

        bool listening = activeField == fieldName;

        return Tooltip(
          message: listening
              ? "Stop Recording"
              : "Start Recording",
          child: IconButton(
            icon: Icon(
              listening
                  ? Icons.stop_circle
                  : Icons.mic,
              color: listening
                  ? Colors.red
                  : Colors.blue,
            ),
            onPressed: () async {

              beforeListening?.call();

              await SpeechService.toggleListening(
                fieldName,
                (text) {
                  onResult(text);
                },
              );
            },
          ),
        );
      }
    );

  }

}