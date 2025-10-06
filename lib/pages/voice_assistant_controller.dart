// voice_assistant_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'RecipeScreen.dart';

class VoiceAssistantController extends GetxController {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool hasWelcomed = false;
  bool _isListening = false;
  bool _shouldKeepListening = false;
  Timer? _restartTimer;
  Completer<void>? _speechCompleter; // Track TTS completion

  // Track if user activated voice mode
  bool _isVoiceMode = false;
  bool get isVoiceMode => _isVoiceMode;

  // Recipe reading state
  bool _isRecipeMode = false;
  bool _isRecipeSpeaking = false;
  bool _isRecipePaused = false;
  bool _isRecipeListening = false;
  String _currentRecipeText = "";
  List<String> _recipeTextParts = [];
  int _currentRecipeIndex = 0;
  final double _speechRate = 0.5;

  bool get isListening => _isListening;
  bool get shouldKeepListening => _shouldKeepListening;
  bool get isRecipeListening => _isRecipeListening;
  bool get isRecipeSpeaking => _isRecipeSpeaking;
  bool get isRecipePaused => _isRecipePaused;

  @override
  void onInit() {
    super.onInit();
    _setupTTS();
    _initializeSpeech();
  }

  void _setupTTS() {
    _tts.setVolume(1.0);
    _tts.setSpeechRate(_speechRate);
    _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      // Complete the speech promise if it exists
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
        _speechCompleter = null;
      }

      if (_isRecipeMode && !_isRecipePaused) {
        _isRecipeSpeaking = false;

        if (_currentRecipeIndex < _recipeTextParts.length - 1) {
          _currentRecipeIndex++;
          _speakRecipe();
        }

        update();
      }
    });

    _tts.setStartHandler(() {
      if (_isRecipeMode) {
        _isRecipeSpeaking = true;
        update();
      }
    });

    _tts.setErrorHandler((msg) {
      // Complete with error if speech fails
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
        _speechCompleter = null;
      }
    });
  }

  void _initializeSpeech() {
    _speech.initialize(
      onStatus: (status) {
        if (status == "notListening" || status == "done") {
          if (_isRecipeMode) {
            _isRecipeListening = false;
            if (_shouldKeepListening) _scheduleRecipeListeningRestart();
          } else {
            _isListening = false;
            if (_shouldKeepListening) _scheduleRestart();
          }
          update();
        } else if (status == "listening") {
          if (_isRecipeMode) {
            _isRecipeListening = true;
          } else {
            _isListening = true;
          }
          update();
        }
      },
      onError: (_) {
        if (_isRecipeMode) {
          _isRecipeListening = false;
          if (_shouldKeepListening) _scheduleRecipeListeningRestart();
        } else {
          _isListening = false;
          if (_shouldKeepListening) _scheduleRestart();
        }
        update();
      },
    );
  }

  // -------------------- Recipe Reading Mode --------------------

  Future<void> startRecipeReading(String recipeText) async {
    _isRecipeMode = true;
    _currentRecipeText = recipeText;
    
    _recipeTextParts = _smartSplitRecipe(recipeText);
    _currentRecipeIndex = 0;
    _isRecipePaused = false;

    await _speakRecipe();

    _shouldKeepListening = true;
    _startRecipeListening();
  }
  
  List<String> _smartSplitRecipe(String text) {
    List<String> parts = [];
    List<String> lines = text.split('\n');
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      bool isHeader = line.endsWith(':') || 
                     line.toLowerCase().startsWith('ingredients') || 
                     line.toLowerCase().startsWith('instructions');
      
      if (isHeader) {
        parts.add(line);
      } 
      else if (RegExp(r'^\d+[\.\)]\s+|^step\s+\d+:', caseSensitive: false).hasMatch(line)) {
        if (line.contains(RegExp(r'[.!?]'))) {
          List<String> sentences = line.split(RegExp(r'(?<=[.!?])\s+'));
          for (String sentence in sentences) {
            sentence = sentence.trim();
            if (sentence.isNotEmpty) {
              parts.add(sentence);
            }
          }
        } else {
          parts.add(line);
        }
      }
      else if (line.contains(RegExp(r'[.!?]'))) {
        List<String> sentences = line.split(RegExp(r'(?<=[.!?])\s+'));
        for (String sentence in sentences) {
          sentence = sentence.trim();
          if (sentence.isNotEmpty) {
            parts.add(sentence);
          }
        }
      } 
      else {
        parts.add(line);
      }
    }
    
    return parts.where((p) => p.isNotEmpty).toList();
  }

  void stopRecipeReading() {
    _isRecipeMode = false;
    _shouldKeepListening = false;
    _isRecipeSpeaking = false;
    _isRecipePaused = false;
    _isRecipeListening = false;

    _tts.stop();
    _speech.stop();
    _cancelRestartTimer();
    
    // Complete any pending speech
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
      _speechCompleter = null;
    }
    
    update();
  }

  void _startRecipeListening() async {
    if (_isRecipeListening || !_isRecipeMode || !_shouldKeepListening) return;

    bool available = await _speech.isAvailable;
    if (!available) {
      _scheduleRecipeListeningRestart();
      return;
    }

    _isRecipeListening = true;
    update();

    try {
      _speech.listen(
        onResult: (val) {
          final command = val.recognizedWords.toLowerCase();
          print("Recipe mode heard: $command");

          if (command.contains("pause") || command.contains("stop")) {
            pauseRecipe();
          } else if (command.contains("play") || command.contains("start")) {
            resumeRecipe();
          }
        },
        listenFor: const Duration(seconds: 30),
        partialResults: true,
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (_) {
      _isRecipeListening = false;
      if (_shouldKeepListening) _scheduleRecipeListeningRestart();
    }
  }

  Future<void> _speakRecipe() async {
    if (!_isRecipeMode || _currentRecipeIndex >= _recipeTextParts.length) return;

    final textToRead = _recipeTextParts[_currentRecipeIndex];
    await _tts.speak(textToRead);
  }

  void pauseRecipe() {
    if (_isRecipeMode && _isRecipeSpeaking && !_isRecipePaused) {
      _isRecipePaused = true;
      _tts.stop();
      _isRecipeSpeaking = false;
      update();
    }
  }

  void resumeRecipe() {
    if (_isRecipeMode && _isRecipePaused) {
      _isRecipePaused = false;
      _speakRecipe();
    }
  }

  void rewindRecipe() {
    if (_isRecipeMode && _currentRecipeIndex > 0) {
      _currentRecipeIndex--;
      _tts.stop().then((_) => _speakRecipe());
    }
  }

  void fastForwardRecipe() {
    if (_isRecipeMode && _currentRecipeIndex < _recipeTextParts.length - 1) {
      _currentRecipeIndex++;
      _tts.stop().then((_) => _speakRecipe());
    }
  }

  void repeatCurrentSection() {
    if (_isRecipeMode) {
      _tts.stop().then((_) => _speakRecipe());
    }
  }

  void _scheduleRecipeListeningRestart() {
    _cancelRestartTimer();
    _restartTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_shouldKeepListening && _isRecipeMode) {
        _startRecipeListening();
      }
    });
  }

  // -------------------- Home Page Listening --------------------

  void enableContinuousListening({List<Map<String, dynamic>>? savedRecipes}) {
    if (_isRecipeMode) return;

    _cancelRestartTimer();
    stopListening();

    _shouldKeepListening = true;
    Timer(const Duration(milliseconds: 300), () {
      if (_shouldKeepListening && !_isRecipeMode) {
        _startListeningSession(savedRecipes: savedRecipes);
      }
    });
  }

  void disableContinuousListening() {
    _shouldKeepListening = false;
    _cancelRestartTimer();
    stopListening();
  }

  void _startListeningSession({List<Map<String, dynamic>>? savedRecipes}) async {
    if (_isListening || _isRecipeMode || !_shouldKeepListening) return;

    bool available = await _speech.isAvailable;
    if (!available) {
      _scheduleRestart(savedRecipes: savedRecipes);
      return;
    }

    _isListening = true;
    update();

    try {
      _speech.listen(
        onResult: (val) {
          final command = val.recognizedWords.toLowerCase();
          print("Home mode heard: $command");

          if (command.contains("search")) {
            // Activate voice mode when "search" is said
            _isVoiceMode = true;
            _shouldKeepListening = false;
            stopListening();
            _cancelRestartTimer();

            if (savedRecipes != null) {
              Get.to(() => RecipeScreen(
                savedRecipes: savedRecipes,
                isVoiceActivated: true,
              ));
            } else {
              Get.to(() => RecipeScreen(
                savedRecipes: [],
                isVoiceActivated: true,
              ));
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        partialResults: true,
        pauseFor: const Duration(seconds: 5),
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (_) {
      _isListening = false;
      if (_shouldKeepListening) _scheduleRestart(savedRecipes: savedRecipes);
    }
  }

  void _scheduleRestart({List<Map<String, dynamic>>? savedRecipes}) {
    _cancelRestartTimer();
    _restartTimer = Timer(const Duration(seconds: 2), () {
      if (_shouldKeepListening && !_isRecipeMode) {
        _startListeningSession(savedRecipes: savedRecipes);
      }
    });
  }

  void _cancelRestartTimer() {
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  // Updated speak method that properly waits for TTS completion
  Future<void> speak(String text) async {
    if (_isRecipeMode) {
      await _tts.speak(text);
      return;
    }

    // Stop any ongoing listening
    bool wasListening = _shouldKeepListening;
    if (wasListening) {
      _shouldKeepListening = false;
      stopListening();
    }

    await _tts.stop();
    
    // Create a completer to wait for speech completion
    _speechCompleter = Completer<void>();
    
    await _tts.speak(text);
    
    // Wait for the speech to complete
    await _speechCompleter!.future;

    // Restart listening if it was active before
    if (wasListening) {
      _shouldKeepListening = true;
      _startListeningSession();
    }
  }

  // Reset voice mode (call when user manually navigates)
  void resetVoiceMode() {
    _isVoiceMode = false;
    update();
  }

  // Legacy methods
  void startListeningOnHome({List<Map<String, dynamic>>? savedRecipes}) {
    enableContinuousListening(savedRecipes: savedRecipes);
  }

  void restartListening({List<Map<String, dynamic>>? savedRecipes}) {
    enableContinuousListening(savedRecipes: savedRecipes);
  }

  void onHomePageLeft() {
    disableContinuousListening();
  }

  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
      update();
    }
    if (_isRecipeListening) {
      _speech.stop();
      _isRecipeListening = false;
      update();
    }
  }

  @override
  void onClose() {
    stopRecipeReading();
    disableContinuousListening();
    _tts.stop();
    
    // Clean up any pending completers
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
      _speechCompleter = null;
    }
    
    super.onClose();
  }
}







// // voice_assistant_controller.dart
// import 'dart:async';
// import 'package:get/get.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'RecipeScreen.dart';

// class VoiceAssistantController extends GetxController {
//   final FlutterTts _tts = FlutterTts();
//   final stt.SpeechToText _speech = stt.SpeechToText();

//   bool hasWelcomed = false; // Only used by HomeScreen
//   bool _isListening = false;
//   bool _shouldKeepListening = false; // Flag for home listening
//   Timer? _restartTimer;

//   // Recipe reading state
//   bool _isRecipeMode = false;
//   bool _isRecipeSpeaking = false;
//   bool _isRecipePaused = false;
//   bool _isRecipeListening = false;
//   String _currentRecipeText = "";
//   List<String> _recipeTextParts = [];
//   int _currentRecipeIndex = 0;
//   final double _speechRate = 0.5;

//   bool get isListening => _isListening;
//   bool get shouldKeepListening => _shouldKeepListening;
//   bool get isRecipeListening => _isRecipeListening;
//   bool get isRecipeSpeaking => _isRecipeSpeaking;
//   bool get isRecipePaused => _isRecipePaused;

//   @override
//   void onInit() {
//     super.onInit();
//     _setupTTS();
//     _initializeSpeech();
//   }

//   void _setupTTS() {
//     _tts.setVolume(1.0);
//     _tts.setSpeechRate(_speechRate);
//     _tts.setPitch(1.0);

//     _tts.setCompletionHandler(() {
//       if (_isRecipeMode) {
//         _isRecipeSpeaking = false;
//         _isRecipePaused = false;

//         // ✅ Move to next part automatically
//         if (_currentRecipeIndex < _recipeTextParts.length - 1) {
//           _currentRecipeIndex++;
//           _speakRecipe();
//         }

//         update();
//       }
//     });

//     _tts.setStartHandler(() {
//       if (_isRecipeMode) {
//         _isRecipeSpeaking = true;
//         update();
//       }
//     });
//   }

//   void _initializeSpeech() {
//     _speech.initialize(
//       onStatus: (status) {
//         if (status == "notListening" || status == "done") {
//           if (_isRecipeMode) {
//             _isRecipeListening = false;
//             if (_shouldKeepListening) _scheduleRecipeListeningRestart();
//           } else {
//             _isListening = false;
//             if (_shouldKeepListening) _scheduleRestart();
//           }
//           update();
//         } else if (status == "listening") {
//           if (_isRecipeMode) {
//             _isRecipeListening = true;
//           } else {
//             _isListening = true;
//           }
//           update();
//         }
//       },
//       onError: (_) {
//         if (_isRecipeMode) {
//           _isRecipeListening = false;
//           if (_shouldKeepListening) _scheduleRecipeListeningRestart();
//         } else {
//           _isListening = false;
//           if (_shouldKeepListening) _scheduleRestart();
//         }
//         update();
//       },
//     );
//   }

//   // -------------------- Recipe Reading Mode --------------------

//   Future<void> startRecipeReading(String recipeText) async {
//     _isRecipeMode = true;
//     _currentRecipeText = recipeText;
//     _recipeTextParts = recipeText.split(RegExp(r'(?<=[.!?])\s+'));
//     _currentRecipeIndex = 0;
//     _isRecipePaused = false;

//     await _speakRecipe();

//     _shouldKeepListening = true;
//     _startRecipeListening();
//   }

//   void stopRecipeReading() {
//     _isRecipeMode = false;
//     _shouldKeepListening = false;
//     _isRecipeSpeaking = false;
//     _isRecipePaused = false;
//     _isRecipeListening = false;

//     _tts.stop();
//     _speech.stop();
//     _cancelRestartTimer();
//     update();
//   }

//   void _startRecipeListening() async {
//     if (_isRecipeListening || !_isRecipeMode || !_shouldKeepListening) return;

//     bool available = await _speech.isAvailable;
//     if (!available) {
//       _scheduleRecipeListeningRestart();
//       return;
//     }

//     _isRecipeListening = true;
//     update();

//     try {
//       _speech.listen(
//         onResult: (val) {
//           final command = val.recognizedWords.toLowerCase();
//           print("Recipe mode heard: $command"); // 🔍 debug

//           if (command.contains("pause") || command.contains("stop")) {
//             pauseRecipe();
//           } else if (command.contains("resume") ||
//               command.contains("start") ||
//               command.contains("play") ||
//               command.contains("continue")) {
//             resumeRecipe();
//           } else if (command.contains("repeat") || command.contains("again")) {
//             repeatCurrentSection();
//           }
//         },
//         listenFor: const Duration(seconds: 30),
//         partialResults: true,
//         pauseFor: const Duration(seconds: 3),
//         cancelOnError: true,
//         listenMode: stt.ListenMode.confirmation,
//       );
//     } catch (_) {
//       _isRecipeListening = false;
//       if (_shouldKeepListening) _scheduleRecipeListeningRestart();
//     }
//   }

//   Future<void> _speakRecipe() async {
//     if (!_isRecipeMode || _currentRecipeIndex >= _recipeTextParts.length) return;

//     bool wasListening = _isRecipeListening;
//     if (wasListening) {
//       _speech.stop();
//       _isRecipeListening = false;
//     }

//     final textToRead = _recipeTextParts[_currentRecipeIndex];
//     await _tts.speak(textToRead);

//     if (wasListening && _shouldKeepListening && _isRecipeMode) {
//       Timer(const Duration(milliseconds: 500), _startRecipeListening);
//     }
//   }

//   void pauseRecipe() {
//     if (_isRecipeMode && _isRecipeSpeaking) {
//       _tts.stop(); // ✅ Stop current sentence, index not incremented
//       _isRecipeSpeaking = false;
//       _isRecipePaused = true;
//       update();
//     }
//   }

//   void resumeRecipe() {
//     if (_isRecipeMode && _isRecipePaused) {
//       _isRecipePaused = false;
//       _speakRecipe(); // ✅ continues from same index
//     }
//   }

//   void rewindRecipe() {
//     if (_isRecipeMode && _currentRecipeIndex > 0) {
//       _currentRecipeIndex--;
//       _tts.stop().then((_) => _speakRecipe());
//     }
//   }

//   void fastForwardRecipe() {
//     if (_isRecipeMode && _currentRecipeIndex < _recipeTextParts.length - 1) {
//       _currentRecipeIndex++;
//       _tts.stop().then((_) => _speakRecipe());
//     }
//   }

//   void repeatCurrentSection() {
//     if (_isRecipeMode) {
//       _tts.stop().then((_) => _speakRecipe()); // ✅ replay current part
//     }
//   }

//   void _scheduleRecipeListeningRestart() {
//     _cancelRestartTimer();
//     _restartTimer = Timer(const Duration(seconds: 2), () {
//       if (_shouldKeepListening && _isRecipeMode) {
//         _startRecipeListening();
//       }
//     });
//   }

//   // -------------------- Home Page Listening --------------------

//   void enableContinuousListening({List<Map<String, dynamic>>? savedRecipes}) {
//     if (_isRecipeMode) return; // don't conflict with recipe mode

//     _cancelRestartTimer();
//     stopListening();

//     _shouldKeepListening = true;
//     Timer(const Duration(milliseconds: 300), () {
//       if (_shouldKeepListening && !_isRecipeMode) {
//         _startListeningSession(savedRecipes: savedRecipes);
//       }
//     });
//   }

//   void disableContinuousListening() {
//     _shouldKeepListening = false;
//     _cancelRestartTimer();
//     stopListening();
//   }

//   void _startListeningSession({List<Map<String, dynamic>>? savedRecipes}) async {
//     if (_isListening || _isRecipeMode || !_shouldKeepListening) return;

//     bool available = await _speech.isAvailable;
//     if (!available) {
//       _scheduleRestart(savedRecipes: savedRecipes);
//       return;
//     }

//     _isListening = true;
//     update();

//     try {
//       _speech.listen(
//         onResult: (val) {
//           final command = val.recognizedWords.toLowerCase();
//           print("Home mode heard: $command"); // 🔍 debug

//           if (command.contains("search")) {
//             _shouldKeepListening = false;
//             stopListening();
//             _cancelRestartTimer();

//             if (savedRecipes != null) {
//               Get.to(() => RecipeScreen(savedRecipes: savedRecipes));
//             } else {
//               Get.to(() => RecipeScreen(savedRecipes: []));
//             }
//           }
//         },
//         listenFor: const Duration(seconds: 30),
//         partialResults: true,
//         pauseFor: const Duration(seconds: 5),
//         cancelOnError: true,
//         listenMode: stt.ListenMode.confirmation,
//       );
//     } catch (_) {
//       _isListening = false;
//       if (_shouldKeepListening) _scheduleRestart(savedRecipes: savedRecipes);
//     }
//   }

//   void _scheduleRestart({List<Map<String, dynamic>>? savedRecipes}) {
//     _cancelRestartTimer();
//     _restartTimer = Timer(const Duration(seconds: 2), () {
//       if (_shouldKeepListening && !_isRecipeMode) {
//         _startListeningSession(savedRecipes: savedRecipes);
//       }
//     });
//   }

//   void _cancelRestartTimer() {
//     _restartTimer?.cancel();
//     _restartTimer = null;
//   }

//   Future<void> speak(String text) async {
//     if (_isRecipeMode) {
//       await _tts.speak(text);
//       return;
//     }

//     bool wasListening = _shouldKeepListening;
//     if (wasListening) {
//       _shouldKeepListening = false;
//       stopListening();
//     }

//     await _tts.stop();
//     await _tts.speak(text);

//     if (wasListening) {
//       _shouldKeepListening = true;
//       _startListeningSession();
//     }
//   }

//   // Legacy methods (HomeScreen calls these)
//   void startListeningOnHome({List<Map<String, dynamic>>? savedRecipes}) {
//     enableContinuousListening(savedRecipes: savedRecipes);
//   }

//   void restartListening({List<Map<String, dynamic>>? savedRecipes}) {
//     enableContinuousListening(savedRecipes: savedRecipes);
//   }

//   void onHomePageLeft() {
//     disableContinuousListening();
//   }

//   void stopListening() {
//     if (_isListening) {
//       _speech.stop();
//       _isListening = false;
//       update();
//     }
//     if (_isRecipeListening) {
//       _speech.stop();
//       _isRecipeListening = false;
//       update();
//     }
//   }

//   @override
//   void onClose() {
//     stopRecipeReading();
//     disableContinuousListening();
//     _tts.stop();
//     super.onClose();
//   }
// }









// // voice_assistant_controller.dart
// import 'dart:async';
// import 'package:get/get.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'RecipeScreen.dart';


// class VoiceAssistantController extends GetxController {
//   final FlutterTts _tts = FlutterTts();
//   final stt.SpeechToText _speech = stt.SpeechToText();

//   bool hasWelcomed = false;
//   bool _isListening = false;
//   bool _shouldKeepListening = false; // Flag to control continuous listening
//   Timer? _restartTimer;
  
//   bool get isListening => _isListening;
//   bool get shouldKeepListening => _shouldKeepListening;

//   @override
//   void onInit() {
//     super.onInit();
//     _setupTTS();
//     _initializeSpeech();
//   }

//   void _initializeSpeech() {
//     _speech.initialize(
//       onStatus: (status) {
//         print('Speech status: $status, Current route: ${Get.currentRoute}, Should keep listening: $_shouldKeepListening');
        
//         if (status == "notListening" || status == "done") {
//           _isListening = false;
//           update(); // Update UI if you're using GetBuilder
          
//           // Always restart if we should keep listening, regardless of route check
//           if (_shouldKeepListening) {
//             print('Scheduling restart after status: $status');
//             _scheduleRestart();
//           }
//         } else if (status == "listening") {
//           _isListening = true;
//           update();
//         }
//       },
//       onError: (error) {
//         print('Speech error: $error, Should keep listening: $_shouldKeepListening');
//         _isListening = false;
//         update();
        
//         // Always restart on error if we should keep listening
//         if (_shouldKeepListening) {
//           print('Scheduling restart after error: $error');
//           _scheduleRestart();
//         }
//       },
//     );
//   }

//   void _setupTTS() {
//     _tts.setVolume(1.0);
//     _tts.setSpeechRate(0.5);
//     _tts.setPitch(1.0);
//     _tts.awaitSpeakCompletion(true);
//   }

//   void _handleRouteChange() {
//     if (Get.currentRoute == '/') {
//       // We're on home page - start continuous listening
//       enableContinuousListening();
//     } else {
//       // We're on another page - stop listening
//       disableContinuousListening();
//     }
//   }

//   /// Call this method when returning to the home page (from any navigation)
//   void onHomePageReturned({List<Map<String, dynamic>>? savedRecipes}) {
//     print('Returned to home page - checking if should restart listening');
//     if (Get.currentRoute == '/' || Get.currentRoute == '/main') {
//       enableContinuousListening(savedRecipes: savedRecipes);
//     }
//   }

//   /// Call this method when entering the home page
//   void onHomePageEntered({List<Map<String, dynamic>>? savedRecipes}) {
//     print('Home page entered - enabling continuous listening');
//     enableContinuousListening(savedRecipes: savedRecipes);
//   }

//   /// Call this method when leaving the home page
//   void onHomePageLeft() {
//     print('Home page left - disabling continuous listening');
//     disableContinuousListening();
//   }

//   /// Enable continuous listening (call this when entering home page)
//   void enableContinuousListening({List<Map<String, dynamic>>? savedRecipes}) {
//     print('Enabling continuous listening - Current state: listening=$_isListening, shouldKeep=$_shouldKeepListening');
    
//     // Clean state before enabling
//     _cancelRestartTimer();
//     stopListening();
    
//     // Enable continuous listening
//     _shouldKeepListening = true;
    
//     // Start listening after a brief delay to ensure clean state
//     Timer(const Duration(milliseconds: 300), () {
//       if (_shouldKeepListening) {
//         print('Starting fresh listening session');
//         _startListeningSession(savedRecipes: savedRecipes);
//       }
//     });
//   }

//   /// Disable continuous listening (call this when leaving home page)
//   void disableContinuousListening() {
//     print('Disabling continuous listening');
//     _shouldKeepListening = false;
//     _cancelRestartTimer();
//     stopListening();
//   }

//   void _startListeningSession({List<Map<String, dynamic>>? savedRecipes}) async {
//     if (_isListening) {
//       print('Already listening, skipping start');
//       return;
//     }
    
//     if (!_shouldKeepListening) {
//       print('Should not keep listening, aborting start');
//       return;
//     }

//     bool available = await _speech.isAvailable;
//     if (!available) {
//       print('Speech not available, scheduling retry');
//       // If speech not available, try again after delay
//       _scheduleRestart(savedRecipes: savedRecipes);
//       return;
//     }

//     print('Starting listening session');
//     _isListening = true;
//     update();

//     try {
//       _speech.listen(
//         onResult: (val) {
//           print('Speech result: ${val.recognizedWords}, final: ${val.finalResult}');
//           if (val.finalResult) {
//             final command = val.recognizedWords.toLowerCase();
//             print('Final recognized command: "$command"');
            
//             if (command.contains("search")) {
//               print('Search command detected, navigating to RecipeScreen');
              
//               // Disable continuous listening to prevent conflicts
//               _shouldKeepListening = false;
//               stopListening();
//               _cancelRestartTimer();
              
//               // Navigate to recipe screen and handle return
//               if (savedRecipes != null) {
//                 // Use a small delay to ensure speech recognition has stopped
//                 Timer(const Duration(milliseconds: 500), () {
//                   print('Navigating to RecipeScreen...');
//                   Get.to(() => RecipeScreen(savedRecipes: savedRecipes))?.then((_) {
//                     // This runs when returning from RecipeScreen
//                     print('Returned from RecipeScreen - restarting microphone');
//                     // Use a delay before restarting to ensure clean state
//                     Timer(const Duration(milliseconds: 500), () {
//                       enableContinuousListening(savedRecipes: savedRecipes);
//                     });
//                   });
//                 });
//               } else {
//                 print('No saved recipes available for navigation');
//                 // If no recipes, still need to restart listening
//                 Timer(const Duration(milliseconds: 1000), () {
//                   enableContinuousListening();
//                 });
//               }
//             }
//           }
//         },
//         listenFor: const Duration(seconds: 30), // Longer duration
//         partialResults: true,
//         pauseFor: const Duration(seconds: 5), // Longer pause detection
//         cancelOnError: true,
//         listenMode: stt.ListenMode.confirmation, // Better for continuous listening
//       );
//     } catch (e) {
//       print('Exception starting speech recognition: $e');
//       _isListening = false;
//       update();
//       if (_shouldKeepListening) {
//         _scheduleRestart(savedRecipes: savedRecipes);
//       }
//     }
//   }

//   void _scheduleRestart({List<Map<String, dynamic>>? savedRecipes}) {
//     _cancelRestartTimer();
    
//     // Use a longer delay to allow speech recognition to fully reset
//     _restartTimer = Timer(const Duration(milliseconds: 2000), () {
//       if (_shouldKeepListening) {
//         print('Timer triggered - attempting restart');
//         _startListeningSession(savedRecipes: savedRecipes);
//       } else {
//         print('Timer triggered but shouldKeepListening is false');
//       }
//     });
//   }

//   void _cancelRestartTimer() {
//     _restartTimer?.cancel();
//     _restartTimer = null;
//   }

//   Future<void> speak(String text, {bool listenAfter = false, List<Map<String, dynamic>>? savedRecipes}) async {
//     // Temporarily stop listening while speaking
//     bool wasListening = _shouldKeepListening;
//     if (wasListening) {
//       _shouldKeepListening = false;
//       stopListening();
//     }

//     await _tts.stop();
//     await _tts.speak(text);

//     if (listenAfter && wasListening) {
//       // Re-enable continuous listening after speaking
//       await _tts.awaitSpeakCompletion(true);
//       _shouldKeepListening = true;
//       _startListeningSession(savedRecipes: savedRecipes);
//     }
//   }

//   /// Force restart listening (useful for debugging or manual restart)
//   void forceRestartListening({List<Map<String, dynamic>>? savedRecipes}) {
//     print('Force restarting listening');
//     stopListening();
//     _cancelRestartTimer();
    
//     if (_shouldKeepListening) {
//       Timer(const Duration(milliseconds: 1000), () {
//         _startListeningSession(savedRecipes: savedRecipes);
//       });
//     }
//   }

//   /// Stop mic completely
//   void stopListening() {
//     if (_isListening) {
//       print('Stopping listening');
//       _speech.stop();
//       _isListening = false;
//       update();
//     }
//   }

//   // Legacy methods for backward compatibility
//   @Deprecated('Use enableContinuousListening instead')
//   void startListeningOnHome({List<Map<String, dynamic>>? savedRecipes}) {
//     enableContinuousListening(savedRecipes: savedRecipes);
//   }

//   @Deprecated('Use enableContinuousListening instead')
//   void restartListening({List<Map<String, dynamic>>? savedRecipes}) {
//     if (Get.currentRoute == "/") {
//       enableContinuousListening(savedRecipes: savedRecipes);
//     }
//   }

//   @override
//   void onClose() {
//     disableContinuousListening();
//     _tts.stop();
//     super.onClose();
//   }
// }
