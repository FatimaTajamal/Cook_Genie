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
  bool _isAttemptingToStartRecipeListening = false;
  List<String> _recipeTextParts = [];
  int _currentRecipeIndex = 0;
  final double _speechRate = 0.5;
  bool get isRecipeSpeaking => _isRecipeSpeaking;
  bool get isRecipePaused => _isRecipePaused;
  // Home screen listening state
  bool _isHomeListening = false;
  bool get isHomeListening => _isHomeListening;
 
  // Home auto-restart control
  bool _homeAutoRestartEnabled = true;
@override
void onInit() {
  super.onInit();
  _setupTTS();
  _initializeSpeech();
 
  print("🚀 VoiceAssistantController initialized");
}
  // -------------------- Core Setup --------------------
Future<void> _setupTTS() async {
  print("🔧 Setting up TTS...");
 
  await _tts.setVolume(1.0);
  await _tts.setSpeechRate(_speechRate);
  await _tts.setPitch(1.0);
 
  // Set language (important for some platforms)
  await _tts.setLanguage("en-US");
 
  // Enable shared instance on iOS
  await _tts.setSharedInstance(true);
  print("✅ TTS basic settings configured");
  // CRITICAL: Set up completion handler AFTER awaitSpeakCompletion
  // This ensures the handler is properly registered
  _tts.setCompletionHandler(() {
    print("🎵 ===== TTS COMPLETION HANDLER FIRED =====");
    print(" _isRecipeMode: $_isRecipeMode");
    print(" _isRecipePaused: $_isRecipePaused");
    print(" _currentRecipeIndex: $_currentRecipeIndex / ${_recipeTextParts.length}");
   
    // Cancel monitoring timer if it exists
    _speechMonitorTimer?.cancel();
   
    // 1. Resolve synchronous speak() calls
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      print(" ✅ Completing speechCompleter");
      _speechCompleter!.complete();
      _speechCompleter = null;
    }
    // 2. Auto-advance in recipe mode
    if (_isRecipeMode && !_isRecipePaused) {
      print(" 🔄 Auto-advancing recipe via completion handler...");
      _handleSpeechCompletion();
    } else {
      print(" ⏸️ Not auto-advancing (recipe paused or not in recipe mode)");
    }
  });
  _tts.setStartHandler(() {
    print("🎤 ===== TTS START HANDLER FIRED =====");
    if (_isRecipeMode) {
      _isRecipeSpeaking = true;
      update();
      print(" ✅ Set _isRecipeSpeaking = true");
    }
  });
  _tts.setErrorHandler((msg) {
    print("❌ ===== TTS ERROR HANDLER FIRED: $msg =====");
   
    // Cancel monitoring
    _speechMonitorTimer?.cancel();
   
    // Complete with error if speech fails
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
      _speechCompleter = null;
    }
   
    _isRecipeSpeaking = false;
   
    // Try to continue to next part even if there was an error
    if (_isRecipeMode && !_isRecipePaused) {
      if (_currentRecipeIndex < _recipeTextParts.length - 1) {
        _currentRecipeIndex++;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isRecipeMode && !_isRecipePaused) {
            _speakRecipe();
          }
        });
      }
    }
   
    update();
  });
 
  print("✅ TTS handlers configured");
}
void _initializeSpeech() {
  _speech.initialize(
    onStatus: (status) {
      print("🎙️ Speech status: $status");
      if (status == "listening") {
        _isListening = true;
        update();
      } else if (status == "notListening" || status == "done") {
        final wasListening = _isListening;
        _isListening = false;
        update();
       
        // Only restart if we were actually listening and are still in the right mode
        if (wasListening && !_isAttemptingToStartRecipeListening) {
          if (_isRecipeMode) {
            Future.delayed(const Duration(milliseconds: 1000), _restartRecipeListening);
          } else if (_isHomeListening && _homeAutoRestartEnabled) {
            Future.delayed(const Duration(milliseconds: 1000), _restartHomeListening);
          }
        }
      }
    },
    onError: (error) {
      print("❌ Speech error: $error");
      final wasListening = _isListening;
      _isListening = false;
      _isAttemptingToStartRecipeListening = false;
      update();
     
      // Don't restart on "error_busy" - that means we're already trying to listen
      if (error.errorMsg != "error_busy" && wasListening) {
        if (_isRecipeMode) {
          Future.delayed(const Duration(milliseconds: 1500), _restartRecipeListening);
        } else if (_isHomeListening && _homeAutoRestartEnabled) {
          Future.delayed(const Duration(milliseconds: 1500), _restartHomeListening);
        }
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
  print("🎯 startRecipeReading called");
  print("Recipe text length: ${recipeText.length} characters");
  print("First 200 chars: ${recipeText.substring(0, recipeText.length > 200 ? 200 : recipeText.length)}");
 
  // Stop home listening if it's active
  await _speech.stop();
 
  // Stop any ongoing TTS
  await _tts.stop();
 
  // Small delay to ensure TTS is ready
  await Future.delayed(const Duration(milliseconds: 200));
  _isRecipeMode = true;
  _currentRecipeText = recipeText;
 
  _recipeTextParts = _smartSplitRecipe(recipeText);
 
  print("📊 Split results:");
  print("Total parts: ${_recipeTextParts.length}");
 
  if (_recipeTextParts.isEmpty) {
    print("❌ ERROR: No parts to read!");
    _isRecipeMode = false;
    return;
  }
 
  _currentRecipeIndex = 0;
  _isRecipePaused = false;
  print("🔊 About to speak first part...");
 
  // Don't await here - let it run asynchronously
  _speakRecipe();
 
  // Small delay before starting to listen
  await Future.delayed(const Duration(milliseconds: 500));
  // Start continuous listening for recipe commands
  _startRecipeListening();
}
 
List<String> _smartSplitRecipe(String text) {
  List<String> parts = [];
  List<String> lines = text.split('\n');
 
  String currentSection = '';
 
  for (String line in lines) {
    line = line.trim();
    if (line.isEmpty) continue;
   
    // Check if this is a header (section title)
    bool isHeader = line.endsWith(':') ||
                    line.toLowerCase().startsWith('ingredients') ||
                    line.toLowerCase().startsWith('instructions') ||
                    line.toLowerCase().contains('ingredients:') ||
                    line.toLowerCase().contains('instructions:');
   
    if (isHeader) {
      // Save any accumulated section before starting a new one
      if (currentSection.isNotEmpty) {
        parts.add(currentSection);
        currentSection = '';
      }
      parts.add(line);
    }
    // Handle numbered steps or bullet points
    else if (RegExp(r'^\d+[\.\)]\s+|^-\s+|^•\s+|^step\s+\d+:', caseSensitive: false).hasMatch(line)) {
      // Each numbered step becomes its own part
      if (currentSection.isNotEmpty) {
        parts.add(currentSection);
        currentSection = '';
      }
     
      // Split long steps by sentences
      if (line.length > 150 && line.contains(RegExp(r'[.!?]'))) {
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
    // Regular lines (ingredients, etc.)
    else {
      // For ingredient lists, keep them separate
      if (currentSection.isNotEmpty) {
        // If current section is getting long, split it
        if (currentSection.length > 100) {
          parts.add(currentSection);
          currentSection = line;
        } else {
          currentSection += ' ' + line;
        }
      } else {
        currentSection = line;
      }
    }
  }
 
  // Add any remaining section
  if (currentSection.isNotEmpty) {
    parts.add(currentSection);
  }
 
  // Debug output
  print("🔍 Recipe split into ${parts.length} parts:");
  for (int i = 0; i < parts.length && i < 5; i++) {
    print("Part $i: ${parts[i].substring(0, parts[i].length > 50 ? 50 : parts[i].length)}...");
  }
 
  return parts.where((p) => p.trim().isNotEmpty).toList();
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
  if (_isListening || !_isRecipeMode || _isAttemptingToStartRecipeListening) {
    print("⏭️ Skipping recipe listening start (already listening or attempting)");
    return;
  }
  _isAttemptingToStartRecipeListening = true;
  bool available = await _speech.isAvailable;
  if (!available) {
    print("⚠️ Speech not available, retrying...");
    _isAttemptingToStartRecipeListening = false;
    Future.delayed(const Duration(milliseconds: 1000), _restartRecipeListening);
    return;
  }
  // Stop any existing listening before starting new
  await _speech.stop();
  await Future.delayed(const Duration(milliseconds: 300));
  _isListening = true;
  _isAttemptingToStartRecipeListening = false;
  update();
  try {
    await _speech.listen(
      onResult: (val) {
        if (val.finalResult) {
          final command = val.recognizedWords.toLowerCase();
          print("🎤 Recipe mode heard: $command");
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
    print("❌ Error starting recipe listening: $e");
    _isListening = false;
    _isAttemptingToStartRecipeListening = false;
    Future.delayed(const Duration(milliseconds: 1000), _restartRecipeListening);
  }
}
void _restartRecipeListening() {
  if (_isRecipeMode && !_isListening && !_isAttemptingToStartRecipeListening) {
    print("🔄 Restarting recipe listening...");
    Future.delayed(const Duration(milliseconds: 800), _startRecipeListening);
  }
}
Timer? _speechMonitorTimer;
Future<void> _speakRecipe() async {
  print("🎤 _speakRecipe called");
  print(" _isRecipeMode: $_isRecipeMode");
  print(" _currentRecipeIndex: $_currentRecipeIndex");
  print(" _recipeTextParts.length: ${_recipeTextParts.length}");
 
  if (!_isRecipeMode || _currentRecipeIndex >= _recipeTextParts.length) {
    print("⚠️ Ending recipe - reached end or not in recipe mode");
    if (_isRecipeMode) {
      stopRecipeReading();
    }
    return;
  }
  final textToRead = _recipeTextParts[_currentRecipeIndex];
  print("📢 Speaking part $_currentRecipeIndex: '$textToRead'");
  print(" Text length: ${textToRead.length} characters");
 
  // Set speaking state BEFORE calling speak
  _isRecipeSpeaking = true;
  update();
 
  // Cancel any existing monitor
  _speechMonitorTimer?.cancel();
 
  try {
    // Use awaitSpeakCompletion to actually wait for it to finish
    var result = await _tts.speak(textToRead);
    print("✅ TTS speak() returned: $result");
   
    // Wait for it to actually complete
    await _tts.awaitSpeakCompletion(true);
    print("✅ TTS awaitSpeakCompletion finished");
   
    // If completion handler didn't fire, manually advance
    if (_isRecipeMode && !_isRecipePaused && _isRecipeSpeaking) {
      print("⚠️ Completion handler didn't fire - manually advancing");
      _handleSpeechCompletion();
    }
   
  } catch (e) {
    print("❌ Error in TTS speak: $e");
    _isRecipeSpeaking = false;
    update();
   
    // Try next part on error
    if (_currentRecipeIndex < _recipeTextParts.length - 1) {
      _currentRecipeIndex++;
      Future.delayed(const Duration(milliseconds: 500), _speakRecipe);
    }
  }
}
void _startSpeechMonitoring() {
  print("👀 Starting speech monitoring...");
 
  int consecutiveNotSpeakingCount = 0;
  int checkCount = 0;
 
  // Check every 800ms if TTS is still speaking
  _speechMonitorTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
    if (!_isRecipeMode) {
      print("⛔ Stopping monitor - not in recipe mode");
      timer.cancel();
      return;
    }
   
    checkCount++;
   
    // Check if TTS is still speaking
    // awaitSpeakCompletion returns 1 when speaking, 0 when done
    int speakingStatus = await _tts.awaitSpeakCompletion(false);
    bool isSpeaking = speakingStatus == 1;
   
    print("📊 Monitor check #$checkCount - Speaking: $isSpeaking, Status: $speakingStatus");
   
    if (!isSpeaking && _isRecipeSpeaking) {
      consecutiveNotSpeakingCount++;
      print(" ⏱️ Not speaking count: $consecutiveNotSpeakingCount/2");
     
      // Only trigger completion after 2 consecutive "not speaking" checks
      // This prevents false positives
      if (consecutiveNotSpeakingCount >= 2) {
        print("✅ Monitoring confirmed completion!");
        timer.cancel();
        _handleSpeechCompletion();
      }
    } else if (isSpeaking) {
      if (consecutiveNotSpeakingCount > 0) {
        print(" 🔄 Reset counter - still speaking");
      }
      consecutiveNotSpeakingCount = 0;
    }
   
    // Timeout after 30 seconds (safety)
    if (checkCount > 37) {
      print("⏰ Monitor timeout - forcing completion");
      timer.cancel();
      _handleSpeechCompletion();
    }
  });
}
void _handleSpeechCompletion() {
  print("🔚 _handleSpeechCompletion called");
 
  if (!_isRecipeMode || _isRecipePaused) {
    print(" ⏸️ Not advancing (paused or not in recipe mode)");
    return;
  }
 
  _isRecipeSpeaking = false;
 
  if (_currentRecipeIndex < _recipeTextParts.length - 1) {
    _currentRecipeIndex++;
    print(" ➡️ Moving to part $_currentRecipeIndex");
   
    // Increased delay to let TTS fully reset
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_isRecipeMode && !_isRecipePaused) {
        _speakRecipe();
      }
    });
  } else {
    print(" 🏁 Recipe finished");
    stopRecipeReading();
  }
 
  update();
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
 // Replace your existing fastForwardRecipe and rewindRecipe methods with these:

void fastForwardRecipe() {
  if (!_isRecipeMode) return;
  
  print("⏩ Fast forward pressed - current index: $_currentRecipeIndex");
  
  // Check if we can move forward
  if (_currentRecipeIndex < _recipeTextParts.length - 1) {
    // Cancel monitoring timer
    _speechMonitorTimer?.cancel();
    
    // Move to next section
    _currentRecipeIndex++;
    print("➡️ Moving to part $_currentRecipeIndex");
    
    // Stop current speech and start new one
    _isRecipeSpeaking = false;
    _isRecipePaused = false;
    
    _tts.stop().then((_) {
      // Add a delay to ensure TTS has fully stopped
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isRecipeMode) {
          _speakRecipe();
        }
      });
    });
  } else {
    // Already at the last section
    print("🏁 Already at last section");
    _tts.stop().then((_) {
      _isRecipeSpeaking = false;
      _isRecipePaused = true;
      update();
      speak("That was the last step. Say 'repeat' to hear it again, or 'stop' to finish.");
    });
  }
}

void rewindRecipe() {
  if (!_isRecipeMode) return;
  
  print("⏪ Rewind pressed - current index: $_currentRecipeIndex");
  
  // Cancel monitoring timer
  _speechMonitorTimer?.cancel();
  
  if (_currentRecipeIndex > 0) {
    // Move to previous section
    _currentRecipeIndex--;
    print("⬅️ Moving to part $_currentRecipeIndex");
  } else {
    // Already at first section, just replay it
    print("🔁 Already at first section, replaying");
  }
  
  // Stop current speech and start new one
  _isRecipeSpeaking = false;
  _isRecipePaused = false;
  
  _tts.stop().then((_) {
    // Add a delay to ensure TTS has fully stopped
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isRecipeMode) {
        _speakRecipe();
      }
    });
  });
}

void repeatCurrentSection() {
  if (!_isRecipeMode) return;
  
  print("🔁 Repeat pressed - current index: $_currentRecipeIndex");
  
  // Cancel monitoring timer
  _speechMonitorTimer?.cancel();
  
  // Stop current speech and replay same section
  _isRecipeSpeaking = false;
  _isRecipePaused = false;
  
  _tts.stop().then((_) {
    // Add a delay to ensure TTS has fully stopped
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isRecipeMode) {
        _speakRecipe();
      }
    });
  });
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
  void disableHomeAutoRestart() {
    _homeAutoRestartEnabled = false;
    print("🚫 Home auto-restart disabled");
  }
  void enableHomeAutoRestart() {
    _homeAutoRestartEnabled = true;
    print("✅ Home auto-restart enabled");
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
    if (_isHomeListening && !_isListening && !_isRecipeMode && _homeAutoRestartEnabled) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _startHomeListeningSession(savedRecipes: savedRecipes);
      });
    } else if (!_homeAutoRestartEnabled) {
      print("⏸️ Home restart skipped - auto-restart disabled");
    }
  }
  // -------------------- Legacy/Utility Methods --------------------
  void resetVoiceMode() {
    _isVoiceMode = false;
    update();
  }
  // Add this method to VoiceAssistantController
void stopAllSpeechRecognition() {
  _speech.stop();
  _isListening = false;
  _isHomeListening = false;
  _isRecipeMode = false;
  print("🛑 All speech recognition stopped");
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