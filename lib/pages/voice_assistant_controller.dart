// voice_assistant_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'RecipeScreen.dart'; // Ensure this path is correct

class VoiceAssistantController extends GetxController {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  // State
  bool hasWelcomed = false;

  // TTS/Speech States
  bool _isListening = false;
  bool get isListening => _isListening;

  Completer<void>? _speechCompleter; // Tracks TTS completion for synchronous calls

  // Global Voice Mode
  bool _isVoiceMode = false;
  bool get isVoiceMode => _isVoiceMode;

  // Recipe Reading State
  bool _isRecipeMode = false;
  bool _isRecipeSpeaking = false;
  bool _isRecipePaused = false;
  String _currentRecipeText = "";
  List<String> _recipeTextParts = [];
  int _currentRecipeIndex = 0;
  final double _speechRate = 0.5;

  bool get isRecipeSpeaking => _isRecipeSpeaking;
  bool get isRecipePaused => _isRecipePaused;

  // Home screen listening state
  bool _isHomeListening = false;
  bool get isHomeListening => _isHomeListening;

  @override
  void onInit() {
    super.onInit();
    _setupTTS();
    _initializeSpeech();
  }

  // -------------------- Core Setup --------------------

  void _setupTTS() {
    _tts.setVolume(1.0);
    _tts.setSpeechRate(_speechRate);
    _tts.setPitch(1.0);

    // Handles completion of any TTS call (synchronous or recipe mode)
    _tts.setCompletionHandler(() {
      // 1. Resolve synchronous speak() calls
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
        _speechCompleter = null;
      }

      // 2. Auto-advance in recipe mode
      if (_isRecipeMode && !_isRecipePaused) {
        _isRecipeSpeaking = false;

        if (_currentRecipeIndex < _recipeTextParts.length - 1) {
          _currentRecipeIndex++;
          _speakRecipe(); // Continue to next part
        } else {
          // Finished reading the entire recipe
          stopRecipeReading();
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
      _isRecipeSpeaking = false;
      update();
    });
  }

  void _initializeSpeech() {
    _speech.initialize(
      onStatus: (status) {
        print("Speech status: $status");
        if (status == "listening") {
          _isListening = true;
          update();
        } else if (status == "notListening" || status == "done") {
          _isListening = false;
          update();
          
          // Restart listening if necessary
          if (_isRecipeMode) {
            _restartRecipeListening();
          } else if (_isHomeListening) {
            _restartHomeListening();
          }
        }
      },
      onError: (error) {
        print("Speech error: $error");
        _isListening = false;
        update();
        
        // Restart listening on error
        if (_isRecipeMode) {
          _restartRecipeListening();
        } else if (_isHomeListening) {
          _restartHomeListening();
        }
      },
    );
  }

  // -------------------- TTS/Speaking Methods --------------------

  /// Speaks text and waits for completion if not in recipe mode.
  Future<void> speak(String text) async {
    // If we are already speaking, stop first.
    await _tts.stop();

    if (_isRecipeMode) {
      // In recipe mode, we don't block the UI, just speak.
      await _tts.speak(text);
      return;
    }
    
    // For non-recipe mode, use completer to enforce sequence (e.g., Q&A flow)
    _speechCompleter = Completer<void>();
    
    await _tts.speak(text);
    
    // Wait for the speech to complete or timeout
    // Using a timeout in case the completion handler fails on some platforms
    await _speechCompleter!.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }
  
  /// Immediately stops any ongoing Text-to-Speech operation.
  Future<void> stopSpeaking() async {
    await _tts.stop();
    
    // Resolve any pending completer
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
      _speechCompleter = null;
    }

    _isRecipeSpeaking = false;
    update();
  }

  // -------------------- Recipe Reading Mode --------------------

  Future<void> startRecipeReading(String recipeText) async {
    // Stop home listening if it's active
    _speech.stop();

    _isRecipeMode = true;
    _currentRecipeText = recipeText;
    
    _recipeTextParts = _smartSplitRecipe(recipeText);
    _currentRecipeIndex = 0;
    _isRecipePaused = false;

    await _speakRecipe();

    // Start continuous listening for recipe commands
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
      // Further split long instruction lines by sentence, especially if numbered
      else if (line.contains(RegExp(r'[.!?]')) || RegExp(r'^\d+[\.\)]\s+|^step\s+\d+:', caseSensitive: false).hasMatch(line)) { 
        // This regex splits based on sentence-ending punctuation followed by space,
        // which helps break up long instructions into digestible chunks.
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
    _isRecipeSpeaking = false;
    _isRecipePaused = false;

    _tts.stop();
    _speech.stop();
    _isListening = false;
    
    // Complete any pending speech
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
      _speechCompleter = null;
    }
    
    update();
  }

  void _startRecipeListening() async {
    if (_isListening || !_isRecipeMode) return;

    bool available = await _speech.isAvailable;
    if (!available) {
      Future.delayed(const Duration(milliseconds: 500), _restartRecipeListening);
      return;
    }

    _isListening = true;
    update();

    try {
      await _speech.listen(
        onResult: (val) {
          if (val.finalResult) {
            final command = val.recognizedWords.toLowerCase();
            print("Recipe mode heard: $command");

            if (command.contains("stop") || command.contains("pause")) {
              pauseRecipe();
            } else if (command.contains("start") || command.contains("resume") || command.contains("continue")) {
              resumeRecipe();
            } else if (command.contains("next") || command.contains("forward")) {
              fastForwardRecipe();
            } else if (command.contains("back") || command.contains("previous") || command.contains("rewind")) {
              rewindRecipe();
            } else if (command.contains("repeat") || command.contains("again")) {
              repeatCurrentSection();
            }
          }
        },
        listenFor: const Duration(seconds: 60),
        partialResults: true,
        pauseFor: const Duration(seconds: 60),
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      print("Error starting recipe listening: $e");
      _isListening = false;
      Future.delayed(const Duration(milliseconds: 500), _restartRecipeListening);
    }
  }

  void _restartRecipeListening() {
    if (_isRecipeMode && !_isListening) {
      Future.delayed(const Duration(milliseconds: 300), _startRecipeListening);
    }
  }

  Future<void> _speakRecipe() async {
    if (!_isRecipeMode || _currentRecipeIndex >= _recipeTextParts.length) {
      // End of recipe reached, handles cases where completion handler didn't fire
      if (_isRecipeMode) {
        stopRecipeReading();
      }
      return;
    }

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
    } else if (_isRecipeMode) {
      // Repeat the first section if already at the start
      repeatCurrentSection();
    }
  }

  void fastForwardRecipe() {
    if (_isRecipeMode && _currentRecipeIndex < _recipeTextParts.length - 1) {
      _currentRecipeIndex++;
      _tts.stop().then((_) => _speakRecipe());
    } else if (_isRecipeMode) {
      // Optionally speak a message indicating the end of the recipe
      stopSpeaking().then((_) => speak("That was the last step. Say 'repeat' to hear it again, or 'stop' to finish."));
    }
  }

  void repeatCurrentSection() {
    if (_isRecipeMode) {
      _tts.stop().then((_) => _speakRecipe());
    }
  }

  // -------------------- Home Page Listening --------------------

  void startHomeListening({List<Map<String, dynamic>>? savedRecipes}) async {
    if (_isRecipeMode || _isHomeListening) return;

    _isHomeListening = true;
    _startHomeListeningSession(savedRecipes: savedRecipes);
  }

  void stopHomeListening() {
    _isHomeListening = false;
    if (!_isRecipeMode) {
      _speech.stop();
      _isListening = false;
      update();
    }
  }

  void _startHomeListeningSession({List<Map<String, dynamic>>? savedRecipes}) async {
    if (_isListening || _isRecipeMode || !_isHomeListening) return;

    bool available = await _speech.isAvailable;
    if (!available) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _restartHomeListening(savedRecipes: savedRecipes);
      });
      return;
    }

    _isListening = true;
    update();

    try {
      await _speech.listen(
        onResult: (val) {
          if (val.finalResult) {
             final command = val.recognizedWords.toLowerCase();
             print("Home mode heard: $command");

             if (command.contains("search") || command.contains("find")) {
               // Activate voice mode and navigate to RecipeScreen
               _isVoiceMode = true;
               _isHomeListening = false;
               _speech.stop();
               _isListening = false;

               Get.to(() => RecipeScreen(
                 savedRecipes: savedRecipes ?? [],
                 isVoiceActivated: true,
               ));
             }
          }
        },
        listenFor: const Duration(seconds: 60),
        partialResults: true,
        pauseFor: const Duration(seconds: 60),
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      print("Error starting home listening: $e");
      _isListening = false;
      Future.delayed(const Duration(milliseconds: 500), () {
        _restartHomeListening(savedRecipes: savedRecipes);
      });
    }
  }

  void _restartHomeListening({List<Map<String, dynamic>>? savedRecipes}) {
    if (_isHomeListening && !_isListening && !_isRecipeMode) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _startHomeListeningSession(savedRecipes: savedRecipes);
      });
    }
  }

  // -------------------- Legacy/Utility Methods --------------------

  void resetVoiceMode() {
    _isVoiceMode = false;
    update();
  }

  // Legacy methods for backward compatibility, now aliasing to new methods
  void enableContinuousListening({List<Map<String, dynamic>>? savedRecipes}) {
    startHomeListening(savedRecipes: savedRecipes);
  }

  void disableContinuousListening() {
    stopHomeListening();
  }

  void startListeningOnHome({List<Map<String, dynamic>>? savedRecipes}) {
    startHomeListening(savedRecipes: savedRecipes);
  }

  void restartListening({List<Map<String, dynamic>>? savedRecipes}) {
    startHomeListening(savedRecipes: savedRecipes);
  }

  void onHomePageLeft() {
    stopHomeListening();
  }

  void stopListening() {
    if (_isRecipeMode) {
      // Don't stop listening in recipe mode unless explicitly stopped
      return;
    }
    stopHomeListening();
  }

  @override
  void onClose() {
    stopRecipeReading();
    stopHomeListening();
    _tts.stop();
    
    // Clean up any pending completers
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
      _speechCompleter = null;
    }
    
    super.onClose();
  }
}