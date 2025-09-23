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
  bool _shouldKeepListening = false; // Flag to control continuous listening
  Timer? _restartTimer;
  
  bool get isListening => _isListening;
  bool get shouldKeepListening => _shouldKeepListening;

  @override
  void onInit() {
    super.onInit();
    _setupTTS();
    _initializeSpeech();
  }

  void _initializeSpeech() {
    _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status, Current route: ${Get.currentRoute}, Should keep listening: $_shouldKeepListening');
        
        if (status == "notListening" || status == "done") {
          _isListening = false;
          update(); // Update UI if you're using GetBuilder
          
          // Always restart if we should keep listening, regardless of route check
          if (_shouldKeepListening) {
            print('Scheduling restart after status: $status');
            _scheduleRestart();
          }
        } else if (status == "listening") {
          _isListening = true;
          update();
        }
      },
      onError: (error) {
        print('Speech error: $error, Should keep listening: $_shouldKeepListening');
        _isListening = false;
        update();
        
        // Always restart on error if we should keep listening
        if (_shouldKeepListening) {
          print('Scheduling restart after error: $error');
          _scheduleRestart();
        }
      },
    );
  }

  void _setupTTS() {
    _tts.setVolume(1.0);
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
    _tts.awaitSpeakCompletion(true);
  }

  void _handleRouteChange() {
    if (Get.currentRoute == '/') {
      // We're on home page - start continuous listening
      enableContinuousListening();
    } else {
      // We're on another page - stop listening
      disableContinuousListening();
    }
  }

  /// Call this method when returning to the home page (from any navigation)
  void onHomePageReturned({List<Map<String, dynamic>>? savedRecipes}) {
    print('Returned to home page - checking if should restart listening');
    if (Get.currentRoute == '/' || Get.currentRoute == '/main') {
      enableContinuousListening(savedRecipes: savedRecipes);
    }
  }

  /// Call this method when entering the home page
  void onHomePageEntered({List<Map<String, dynamic>>? savedRecipes}) {
    print('Home page entered - enabling continuous listening');
    enableContinuousListening(savedRecipes: savedRecipes);
  }

  /// Call this method when leaving the home page
  void onHomePageLeft() {
    print('Home page left - disabling continuous listening');
    disableContinuousListening();
  }

  /// Enable continuous listening (call this when entering home page)
  void enableContinuousListening({List<Map<String, dynamic>>? savedRecipes}) {
    print('Enabling continuous listening - Current state: listening=$_isListening, shouldKeep=$_shouldKeepListening');
    
    // Clean state before enabling
    _cancelRestartTimer();
    stopListening();
    
    // Enable continuous listening
    _shouldKeepListening = true;
    
    // Start listening after a brief delay to ensure clean state
    Timer(const Duration(milliseconds: 300), () {
      if (_shouldKeepListening) {
        print('Starting fresh listening session');
        _startListeningSession(savedRecipes: savedRecipes);
      }
    });
  }

  /// Disable continuous listening (call this when leaving home page)
  void disableContinuousListening() {
    print('Disabling continuous listening');
    _shouldKeepListening = false;
    _cancelRestartTimer();
    stopListening();
  }

  void _startListeningSession({List<Map<String, dynamic>>? savedRecipes}) async {
    if (_isListening) {
      print('Already listening, skipping start');
      return;
    }
    
    if (!_shouldKeepListening) {
      print('Should not keep listening, aborting start');
      return;
    }

    bool available = await _speech.isAvailable;
    if (!available) {
      print('Speech not available, scheduling retry');
      // If speech not available, try again after delay
      _scheduleRestart(savedRecipes: savedRecipes);
      return;
    }

    print('Starting listening session');
    _isListening = true;
    update();

    try {
      _speech.listen(
        onResult: (val) {
          print('Speech result: ${val.recognizedWords}, final: ${val.finalResult}');
          if (val.finalResult) {
            final command = val.recognizedWords.toLowerCase();
            print('Final recognized command: "$command"');
            
            if (command.contains("search")) {
              print('Search command detected, navigating to RecipeScreen');
              
              // Disable continuous listening to prevent conflicts
              _shouldKeepListening = false;
              stopListening();
              _cancelRestartTimer();
              
              // Navigate to recipe screen and handle return
              if (savedRecipes != null) {
                // Use a small delay to ensure speech recognition has stopped
                Timer(const Duration(milliseconds: 500), () {
                  print('Navigating to RecipeScreen...');
                  Get.to(() => RecipeScreen(savedRecipes: savedRecipes))?.then((_) {
                    // This runs when returning from RecipeScreen
                    print('Returned from RecipeScreen - restarting microphone');
                    // Use a delay before restarting to ensure clean state
                    Timer(const Duration(milliseconds: 500), () {
                      enableContinuousListening(savedRecipes: savedRecipes);
                    });
                  });
                });
              } else {
                print('No saved recipes available for navigation');
                // If no recipes, still need to restart listening
                Timer(const Duration(milliseconds: 1000), () {
                  enableContinuousListening();
                });
              }
            }
          }
        },
        listenFor: const Duration(seconds: 30), // Longer duration
        partialResults: true,
        pauseFor: const Duration(seconds: 5), // Longer pause detection
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation, // Better for continuous listening
      );
    } catch (e) {
      print('Exception starting speech recognition: $e');
      _isListening = false;
      update();
      if (_shouldKeepListening) {
        _scheduleRestart(savedRecipes: savedRecipes);
      }
    }
  }

  void _scheduleRestart({List<Map<String, dynamic>>? savedRecipes}) {
    _cancelRestartTimer();
    
    // Use a longer delay to allow speech recognition to fully reset
    _restartTimer = Timer(const Duration(milliseconds: 2000), () {
      if (_shouldKeepListening) {
        print('Timer triggered - attempting restart');
        _startListeningSession(savedRecipes: savedRecipes);
      } else {
        print('Timer triggered but shouldKeepListening is false');
      }
    });
  }

  void _cancelRestartTimer() {
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  Future<void> speak(String text, {bool listenAfter = false, List<Map<String, dynamic>>? savedRecipes}) async {
    // Temporarily stop listening while speaking
    bool wasListening = _shouldKeepListening;
    if (wasListening) {
      _shouldKeepListening = false;
      stopListening();
    }

    await _tts.stop();
    await _tts.speak(text);

    if (listenAfter && wasListening) {
      // Re-enable continuous listening after speaking
      await _tts.awaitSpeakCompletion(true);
      _shouldKeepListening = true;
      _startListeningSession(savedRecipes: savedRecipes);
    }
  }

  /// Force restart listening (useful for debugging or manual restart)
  void forceRestartListening({List<Map<String, dynamic>>? savedRecipes}) {
    print('Force restarting listening');
    stopListening();
    _cancelRestartTimer();
    
    if (_shouldKeepListening) {
      Timer(const Duration(milliseconds: 1000), () {
        _startListeningSession(savedRecipes: savedRecipes);
      });
    }
  }

  /// Stop mic completely
  void stopListening() {
    if (_isListening) {
      print('Stopping listening');
      _speech.stop();
      _isListening = false;
      update();
    }
  }

  // Legacy methods for backward compatibility
  @Deprecated('Use enableContinuousListening instead')
  void startListeningOnHome({List<Map<String, dynamic>>? savedRecipes}) {
    enableContinuousListening(savedRecipes: savedRecipes);
  }

  @Deprecated('Use enableContinuousListening instead')
  void restartListening({List<Map<String, dynamic>>? savedRecipes}) {
    if (Get.currentRoute == "/") {
      enableContinuousListening(savedRecipes: savedRecipes);
    }
  }

  @override
  void onClose() {
    disableContinuousListening();
    _tts.stop();
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
//     print('Enabling continuous listening');
//     _shouldKeepListening = true;
//     if (!_isListening) {
//       print('Not currently listening, starting session');
//       _startListeningSession(savedRecipes: savedRecipes);
//     } else {
//       print('Already listening, continuous mode enabled');
//     }
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
//           if (val.finalResult) {
//             final command = val.recognizedWords.toLowerCase();
//             print('Recognized command: $command');
            
//             if (command.contains("search")) {
//               print('Search command detected, navigating to RecipeScreen');
//               // Navigate to recipe screen
//               if (savedRecipes != null) {
//                 Get.to(() => RecipeScreen(savedRecipes: savedRecipes));
//               } else {
//                 print('No saved recipes available for navigation');
//               }
//               // Microphone will be stopped by RecipeScreen when it loads
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
//     print('Enabling continuous listening');
//     _shouldKeepListening = true;
//     if (!_isListening) {
//       print('Not currently listening, starting session');
//       _startListeningSession(savedRecipes: savedRecipes);
//     } else {
//       print('Already listening, continuous mode enabled');
//     }
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
//           if (val.finalResult) {
//             final command = val.recognizedWords.toLowerCase();
//             print('Recognized command: $command');
            
//             if (command.contains("search")) {
//               // Stop continuous listening and navigate
//               disableContinuousListening();
//               if (savedRecipes != null) {
//                 Get.to(() => RecipeScreen(savedRecipes: savedRecipes));
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
