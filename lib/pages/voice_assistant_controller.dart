import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'RecipeScreen.dart';

class VoiceAssistantController extends GetxController {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool hasWelcomed = false;
  bool _isListening = false;

  @override
  void onInit() {
    super.onInit();
    _setupTTS();
  }

  void _setupTTS() {
    _tts.setVolume(1.0);
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
    _tts.awaitSpeakCompletion(true);
  }

  /// Speak and then automatically start listening if requested
  Future<void> speak(String text, {bool listenAfter = false}) async {
    await _tts.stop();
    await _tts.speak(text);

    if (listenAfter) {
      // wait until speaking finishes before listening
      _tts.setCompletionHandler(() {
        restartListening();
      });
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        print("Speech status: $val");
        if (val == "done" || val == "notListening") {
          _isListening = false;
        }
      },
      onError: (val) {
        print("Speech error: $val");
        _isListening = false;
      },
    );

    if (available) {
      print("🎤 Listening started...");
      _isListening = true;

      _speech.listen(
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 5),
        onResult: (val) {
          print("Heard: ${val.recognizedWords}");

          if (val.finalResult) {
            final command = val.recognizedWords.toLowerCase();

            if (command.contains("search")) {
              _speech.stop();
              _isListening = false;

              Get.to(() => RecipeScreen(savedRecipes: []));
            }
          }
        },
      );
    } else {
      print("⚠️ Speech not available");
    }
  }

  void restartListening() {
    if (!_isListening) {
      _startListening();
    }
  }
}
