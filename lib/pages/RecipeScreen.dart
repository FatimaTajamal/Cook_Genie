import 'package:flutter/foundation.dart' show kIsWeb;
import 'firestore_saved_recipes_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import 'RecipeSearch.dart';
import 'grocery_list_screen.dart';
import 'voice_assistant_controller.dart';


class RecipeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes;
  final Map<String, dynamic>? initialRecipe;
  final bool isVoiceActivated;

  const RecipeScreen({
    super.key,
    required this.savedRecipes,
    this.initialRecipe,
    this.isVoiceActivated = false,
  });

  @override
  _RecipeScreenState createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _recipeNameSpeech = stt.SpeechToText();
  final stt.SpeechToText _readyConfirmationSpeech = stt.SpeechToText();

  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isFavorite = false;
  bool _isRecipeNameListening = false;
  bool _recipeNameSpeechInitialized = false;
  bool _readySpeechInitialized = false;

  String _ttsText = "";
  Map<String, dynamic>? _recipe;

  // State variable for the multi-stage voice flow
  String? _clarificationQuery;
  List<String>? _suggestedRecipes;
  bool _awaitingReadyConfirmation = false;
  
  // NEW: Track if we should enable continuous listening for initial prompt
  bool _waitingForInitialRecipeName = false;

  @override
  void initState() {
    super.initState();

    final voiceController = Get.find<VoiceAssistantController>();
    
    // CRITICAL: Completely stop the voice controller's speech instance
    voiceController.stopAllSpeechRecognition();
    voiceController.stopHomeListening();
    voiceController.disableHomeAutoRestart();

    if (widget.isVoiceActivated) {
      if (widget.initialRecipe != null) {
        _recipe = widget.initialRecipe;
        _hasSearched = true;
        _ttsText = _formatRecipe(_recipe!);
        _isFavorite = widget.savedRecipes.any(
          (r) => r['name'] == _recipe!['name'],
        );

        voiceController.startRecipeReading(_formatRecipe(_recipe!));
      } else {
        // NEW: Set flag to enable continuous listening
        _waitingForInitialRecipeName = true;
        
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await voiceController.speak(
            "Please say the name of the dish you want to search for.",
          );
          // Wait for TTS to complete, then start listening
          await Future.delayed(const Duration(milliseconds: 1500));
          print("🎤 Starting voice search after initial prompt...");
          _initializeAndStartVoiceSearch();
        });
      }
    } else {
      if (widget.initialRecipe != null) {
        _recipe = widget.initialRecipe;
        _hasSearched = true;
        _ttsText = _formatRecipe(_recipe!);
        _isFavorite = widget.savedRecipes.any(
          (r) => r['name'] == _recipe!['name'],
        );
      }
    }
  }

  @override
  void dispose() {
    final voiceController = Get.find<VoiceAssistantController>();
    voiceController.stopRecipeReading();
    
    // Re-enable home auto-restart and start home listening
    voiceController.enableHomeAutoRestart();
    voiceController.startHomeListening(savedRecipes: widget.savedRecipes);
    
    if (widget.isVoiceActivated) {
      voiceController.resetVoiceMode();
    }

    // Stop all listening sessions
    _recipeNameSpeech.stop();
    _readyConfirmationSpeech.stop();

    // Reset clarification state
    _clarificationQuery = null;
    _suggestedRecipes = null;
    _awaitingReadyConfirmation = false;
    _isRecipeNameListening = false;
    _waitingForInitialRecipeName = false;

    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchRecipe(String query) async {
    setState(() {
      _hasSearched = true;
      _isLoading = true;
    });

    final recipe = await RecipeService.getRecipe(query);

    if (recipe != null) {
      setState(() {
        _recipe = recipe;
        _isFavorite = widget.savedRecipes.any(
          (r) => r['name'] == recipe['name'],
        );
        _ttsText = _formatRecipe(recipe);
        _isLoading = false;
      });

      if (widget.isVoiceActivated) {
        final voiceController = Get.find<VoiceAssistantController>();
        await _presentEssentialsAndWaitForReady(recipe, voiceController);
      }
    } else {
      if (widget.isVoiceActivated) {
         final voiceController = Get.find<VoiceAssistantController>();
         await voiceController.speak("I couldn't find a recipe for $query. Please try another name.");
         await Future.delayed(const Duration(milliseconds: 1500));
         print("🔄 Restarting voice search after recipe not found...");
         _startVoiceSearchListening();
      }
      
      setState(() {
        _recipe = null;
        _ttsText = "";
        _isLoading = false;
      });
    }
  }

  Future<void> _presentEssentialsAndWaitForReady(
    Map<String, dynamic> recipe,
    VoiceAssistantController voiceController,
  ) async {
    final essentials = _extractDetailedEssentials(recipe);
    
    String essentialsText = "Here are the essentials for ${recipe['name']}: ";
    essentialsText += "You will need ${essentials['ingredientCount']} main ingredients, ";
    essentialsText += "which include ${essentials['keyIngredients']}. ";
    essentialsText += "The recipe takes approximately ${essentials['estimatedTime']}. ";
    
    setState(() {
      _awaitingReadyConfirmation = true;
    });
    
    // Speak the essentials first - await ensures it completes
    await voiceController.speak(essentialsText);
    
    // Now say "Say ready when you want to begin cooking" separately
    await voiceController.speak("Say ready when you want to begin cooking.");
    
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Start continuous listening for "ready"
    if (_awaitingReadyConfirmation && mounted) {
      print("🎤 Starting ready confirmation listening...");
      _initializeAndStartReadyListening();
    }
  }

  Map<String, dynamic> _extractDetailedEssentials(Map<String, dynamic> recipe) {
    final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
    final instructions = recipe['instructions'] as List<dynamic>? ?? [];
    
    // Get first 8 key ingredients
    List<String> keyIngredients = [];
    for (int i = 0; i < (ingredients.length > 8 ? 8 : ingredients.length); i++) {
      final ingredient = ingredients[i];
      keyIngredients.add(ingredient['name']);
    }
    
    // Estimate time based on instruction count
    String estimatedTime;
    if (instructions.length <= 5) {
      estimatedTime = "15 to 20 minutes";
    } else if (instructions.length <= 10) {
      estimatedTime = "30 to 45 minutes";
    } else {
      estimatedTime = "45 minutes to 1 hour";
    }
    
    // Determine difficulty level
    String difficulty;
    if (instructions.length <= 5 && ingredients.length <= 8) {
      difficulty = "Easy";
    } else if (instructions.length <= 10 && ingredients.length <= 12) {
      difficulty = "Medium";
    } else {
      difficulty = "Advanced";
    }
    
    // Estimate servings (default assumption)
    String servings = ingredients.length > 10 ? "4-6 people" : "2-4 people";
    
    return {
      'ingredientCount': ingredients.length,
      'keyIngredients': keyIngredients.join(", "),
      'estimatedTime': estimatedTime,
      'ingredients': keyIngredients,
      'difficulty': difficulty,
      'servings': servings,
    };
  }

  String _formatRecipe(Map<String, dynamic> recipe) {
    final buffer = StringBuffer();

    buffer.writeln('Recipe: ${recipe['name']}');
    buffer.writeln('Ingredients:');
    for (var ingredient in recipe['ingredients']) {
      buffer.writeln('${ingredient['name']} - ${ingredient['quantity']}');
    }

    buffer.writeln('Instructions:');
    for (var step in recipe['instructions']) {
      buffer.writeln(step);
    }

    return buffer.toString();
  }

Future<void> _toggleFavorite() async {
  if (_recipe == null) return;

  try {
    final isAlreadySaved = await FirestoreSavedRecipesService.isRecipeSaved(_recipe!['name'] ?? '');
    if (isAlreadySaved) {
      await FirestoreSavedRecipesService.removeRecipe(_recipe!);
      setState(() => _isFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${_recipe!['name']} from saved recipes.')),
      );
    } else {
      await FirestoreSavedRecipesService.saveRecipe(_recipe!);
      setState(() => _isFavorite = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${_recipe!['name']} to your recipes!')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving recipe: $e')),
    );
  }
}


  // Initialize and start voice search
  Future<void> _initializeAndStartVoiceSearch() async {
    if (kIsWeb) {
      _initializeRecipeNameSpeech();
      return;
    }

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }
    }

    _initializeRecipeNameSpeech();
  }

  // Initialize speech recognizer for recipe names (only once)
  Future<void> _initializeRecipeNameSpeech() async {
    if (_recipeNameSpeechInitialized) {
      print("✅ Speech already initialized, starting listening...");
      _startVoiceSearchListening();
      return;
    }

    bool available = await _recipeNameSpeech.initialize(
      onStatus: (val) {
        print("========== Voice search status: $val ==========");
        if (val == 'listening') {
          if (mounted) {
            setState(() {
              _isRecipeNameListening = true;
            });
          }
        } else if (val == 'notListening' || val == 'done') {
          print("🔄 Status changed to $val, will restart...");
          
          // Set flag BEFORE calling setState
          final wasListening = _isRecipeNameListening;
          
          if (mounted) {
            setState(() {
              _isRecipeNameListening = false;
            });
          }
          
          // Trigger restart AFTER setState completes
          if (wasListening && mounted) {
            print("🔄 Calling auto-restart from onStatus");
            _autoRestartRecipeNameListening();
          }
        }
      },
      onError: (val) {
        print("❌ Voice search error: $val");
        
        // Set flag BEFORE calling setState
        final wasListening = _isRecipeNameListening;
        
        if (mounted) {
          setState(() {
            _isRecipeNameListening = false;
          });
        }
        
        // Trigger restart AFTER setState completes
        if (wasListening && mounted) {
          print("🔄 Calling auto-restart from onError");
          _autoRestartRecipeNameListening();
        }
      },
    );

    if (available) {
      print("✅ Speech recognizer initialized successfully");
      _recipeNameSpeechInitialized = true;
      _startVoiceSearchListening();
    } else {
      print("❌ Speech recognizer not available");
      // Retry initialization after delay
      Future.delayed(const Duration(milliseconds: 500), _initializeRecipeNameSpeech);
    }
  }

  // UPDATED: Auto-restart logic matching voice controller pattern exactly
  void _autoRestartRecipeNameListening() {
    // Restart if:
    // 1. We're waiting for initial recipe name (before any search), OR
    // 2. No recipe found yet and not waiting for ready confirmation
    bool shouldRestart = _waitingForInitialRecipeName || 
                        (_recipe == null && !_awaitingReadyConfirmation);
    
    print("🔍 Auto-restart check: shouldRestart=$shouldRestart, isListening=$_isRecipeNameListening, mounted=$mounted");
    
    if (!_isRecipeNameListening && shouldRestart && mounted) {
      print("🔄 Auto-restarting recipe name listening in 300ms...");
      // Use Future.delayed matching the voice controller pattern (300ms)
      Future.delayed(const Duration(milliseconds: 300), () {
        // Re-check conditions inside the delayed callback
        bool stillShouldRestart = _waitingForInitialRecipeName || 
                                  (_recipe == null && !_awaitingReadyConfirmation);
        print("🔍 Delayed restart check: stillShouldRestart=$stillShouldRestart, isListening=$_isRecipeNameListening, mounted=$mounted");
        
        if (!_isRecipeNameListening && stillShouldRestart && mounted) {
          print("✅ Conditions met, calling _startVoiceSearchListening()");
          _startVoiceSearchListening();
        } else {
          print("❌ Conditions not met, skipping restart");
        }
      });
    } else {
      print("⏸️ Not restarting - conditions not met");
    }
  }

  // Start listening for recipe names (can be called repeatedly)
  void _startVoiceSearchListening() async {
    if (!mounted || _isRecipeNameListening || !_recipeNameSpeechInitialized) {
      print("⚠️ Cannot start listening: mounted=$mounted, isListening=$_isRecipeNameListening, initialized=$_recipeNameSpeechInitialized");
      return;
    }
    
    // Don't start if we already have a recipe or waiting for ready
    if (_recipe != null || _awaitingReadyConfirmation) {
      print("⏸️ Not starting - recipe exists or awaiting confirmation");
      return;
    }

    // CRITICAL: Stop any existing listening session first
    print("🛑 Stopping any existing speech session...");
    await _recipeNameSpeech.stop();
    
    // Longer delay to ensure stop completes and avoid error_busy
    await Future.delayed(const Duration(milliseconds: 300));

    // Check if speech is available before starting
    bool available = await _recipeNameSpeech.isAvailable;
    if (!available) {
      print("⚠️ Speech not available, retrying...");
      Future.delayed(const Duration(milliseconds: 500), _autoRestartRecipeNameListening);
      return;
    }
    
    print("🎤 Starting voice search listening...");
    
    setState(() {
      _isRecipeNameListening = true;
    });
    
    try {
      // Use unawaited - don't wait for listen to complete
      _recipeNameSpeech.listen(
        onResult: (val) async {
          print("📝 onResult called - finalResult: ${val.finalResult}, words: ${val.recognizedWords}");
          
          if (val.finalResult) {
            String recognizedWords = val.recognizedWords.trim().toLowerCase();
            print("✅ Final result received: $recognizedWords");

            setState(() {
              _controller.text = recognizedWords;
              _isLoading = true;
            });
            
            if (_clarificationQuery == null) {
              // STAGE 1: User said something like "Pasta"
              // Disable initial waiting flag once we get first input
              _waitingForInitialRecipeName = false;
              
              setState(() {
                _clarificationQuery = recognizedWords;
              });

              List<String> suggestions = await RecipeService.getRecipeSuggestions(recognizedWords);
              
              if (suggestions.isNotEmpty) {
                setState(() {
                  _suggestedRecipes = suggestions;
                  _isLoading = false;
                });

                final voiceController = Get.find<VoiceAssistantController>();
                String clarificationText = "Here are some $recognizedWords recipes: ";
                clarificationText += suggestions.join(", ");
                clarificationText += ". Which one would you like?";
                
                await voiceController.speak(clarificationText);
                
                // Wait a bit for TTS, then restart
                await Future.delayed(const Duration(milliseconds: 500));
                print("🔄 Triggering manual restart after suggestions...");
                setState(() {
                  _isRecipeNameListening = false;
                });
                _autoRestartRecipeNameListening();

              } else {
                setState(() {
                  _clarificationQuery = null;
                  _suggestedRecipes = null;
                  _isLoading = false;
                });
                
                final voiceController = Get.find<VoiceAssistantController>();
                await voiceController.speak(
                  "I couldn't find any $recognizedWords recipes. Please try another dish."
                );
                
                // Re-enable initial waiting for continuous listening
                _waitingForInitialRecipeName = true;
                
                // Wait a bit for TTS, then restart
                await Future.delayed(const Duration(milliseconds: 500));
                print("🔄 Triggering manual restart after no results...");
                setState(() {
                  _isRecipeNameListening = false;
                });
                _autoRestartRecipeNameListening();
              }

            } else {
              // STAGE 2: User gave the specific recipe name from suggestions
              String finalQuery = recognizedWords;
              
              // Check if the user's input matches one of the suggestions
              bool matchFound = false;
              if (_suggestedRecipes != null) {
                for (String suggestion in _suggestedRecipes!) {
                  if (recognizedWords.contains(suggestion.toLowerCase()) || 
                      suggestion.toLowerCase().contains(recognizedWords)) {
                    finalQuery = suggestion;
                    matchFound = true;
                    break;
                  }
                }
              }
              
              // If no match found, try using the recognized words directly
              if (!matchFound && _suggestedRecipes != null && _suggestedRecipes!.isNotEmpty) {
                // Try to find partial match
                for (String suggestion in _suggestedRecipes!) {
                  List<String> suggestionWords = suggestion.toLowerCase().split(' ');
                  List<String> recognizedWordsList = recognizedWords.split(' ');
                  
                  // Check if at least 2 words match
                  int matchCount = 0;
                  for (String word in recognizedWordsList) {
                    if (suggestionWords.contains(word)) {
                      matchCount++;
                    }
                  }
                  
                  if (matchCount >= 2 || (recognizedWordsList.length == 1 && matchCount >= 1)) {
                    finalQuery = suggestion;
                    matchFound = true;
                    break;
                  }
                }
              }
              
              // Now we need to stop because we found the recipe
              print("Stopping speech - recipe found");
              await _recipeNameSpeech.stop();
              setState(() {
                _isRecipeNameListening = false;
                _waitingForInitialRecipeName = false; // Disable continuous listening
              });
              
              _clarificationQuery = null;
              _suggestedRecipes = null;
              
              setState(() {
                _isLoading = true;
              });

              await _searchRecipe(finalQuery);
            }
          } else {
            setState(() {
              _controller.text = val.recognizedWords;
            });
          }
        },
        onSoundLevelChange: (level) {
          // Optional: visual feedback for sound level
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
      
      // Start polling to check if listening stopped
      _startListeningMonitor();
      
    } catch (e) {
      print("❌ Exception in listen call: $e");
      if (mounted) {
        setState(() {
          _isRecipeNameListening = false;
        });
      }
      // Restart on exception
      Future.delayed(const Duration(milliseconds: 500), _autoRestartRecipeNameListening);
    }
  }
  
  // NEW: Monitor listening status and restart when it stops
  void _startListeningMonitor() {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      
      // Check if we're supposed to be listening
      bool shouldBeListening = _waitingForInitialRecipeName || 
                               (_recipe == null && !_awaitingReadyConfirmation);
      
      if (shouldBeListening && _isRecipeNameListening) {
        // Check if actually listening
        bool isActuallyListening = await _recipeNameSpeech.isListening;
        print("🔍 Monitor check - shouldListen: $shouldBeListening, flagSet: $_isRecipeNameListening, actuallyListening: $isActuallyListening");
        
        if (!isActuallyListening) {
          // Listening stopped but flag is still true
          print("⚠️ Listening stopped unexpectedly! Restarting...");
          setState(() {
            _isRecipeNameListening = false;
          });
          _autoRestartRecipeNameListening();
        } else {
          // Still listening, check again later
          _startListeningMonitor();
        }
      }
    });
  }

  // Initialize and start ready confirmation listening
  Future<void> _initializeAndStartReadyListening() async {
    if (_readySpeechInitialized) {
      print("✅ Ready speech already initialized, starting listening...");
      _startReadyConfirmationListening();
      return;
    }

    bool available = await _readyConfirmationSpeech.initialize(
      onStatus: (val) {
        print("========== Ready confirmation status: $val ==========");
        if (val == 'notListening' || val == 'done') {
          // Auto-restart like home page does
          _autoRestartReadyListening();
        }
      },
      onError: (val) {
        print("❌ Ready confirmation error: $val");
        // Auto-restart on error like home page does
        _autoRestartReadyListening();
      },
    );

    if (available) {
      print("✅ Ready speech recognizer initialized");
      _readySpeechInitialized = true;
      _startReadyConfirmationListening();
    } else {
      print("❌ Ready speech recognizer not available");
      Future.delayed(const Duration(milliseconds: 500), _initializeAndStartReadyListening);
    }
  }

  // Auto-restart logic for ready confirmation
  void _autoRestartReadyListening() {
    if (_awaitingReadyConfirmation && mounted) {
      print("🔄 Auto-restarting ready confirmation listening...");
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_awaitingReadyConfirmation && mounted) {
          _startReadyConfirmationListening();
        }
      });
    }
  }

  // Start listening for "ready" (can be called repeatedly)
  void _startReadyConfirmationListening() async {
    if (!mounted || !_awaitingReadyConfirmation || !_readySpeechInitialized) {
      print("⚠️ Cannot start ready listening: mounted=$mounted, awaiting=$_awaitingReadyConfirmation, initialized=$_readySpeechInitialized");
      return;
    }

    // Check if speech is available before starting
    bool available = await _readyConfirmationSpeech.isAvailable;
    if (!available) {
      print("⚠️ Ready speech not available, retrying...");
      Future.delayed(const Duration(milliseconds: 500), _autoRestartReadyListening);
      return;
    }

    print("🎤 Starting ready confirmation listening...");
    
    try {
      await _readyConfirmationSpeech.listen(
        onResult: (val) async {
          if (val.finalResult) {
            String recognizedWords = val.recognizedWords.trim().toLowerCase();
            final voiceController = Get.find<VoiceAssistantController>();

            print("Recognized in ready mode: $recognizedWords");

            setState(() {
              _controller.text = recognizedWords;
            });

            if (_awaitingReadyConfirmation && recognizedWords.contains("ready")) {
              // Only stop when we hear "ready"
              setState(() {
                _awaitingReadyConfirmation = false;
              });
              
              await _readyConfirmationSpeech.stop();
              
              // Start reading the full recipe
              await voiceController.startRecipeReading(_formatRecipe(_recipe!));
            }
            // If not "ready", the onStatus callback will auto-restart
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 60), // CHANGED from 3 to 60 to match voice controller
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      print("❌ Exception in ready listen call: $e");
      // The onError callback will handle restart
      Future.delayed(const Duration(milliseconds: 500), _autoRestartReadyListening);
    }
  }

  void _startManualRecipeReading() {
    if (_recipe == null) return;
    
    final voiceController = Get.find<VoiceAssistantController>();
    voiceController.startRecipeReading(_formatRecipe(_recipe!));
  }

  void _stopManualRecipeReading() {
    final voiceController = Get.find<VoiceAssistantController>();
    voiceController.stopRecipeReading();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final voiceController = Get.find<VoiceAssistantController>();
        voiceController.stopRecipeReading();
        
        // Re-enable home auto-restart and start home listening
        voiceController.enableHomeAutoRestart();
        voiceController.startHomeListening(savedRecipes: widget.savedRecipes);
        
        if (widget.isVoiceActivated) {
          voiceController.resetVoiceMode();
        }
        
        // Stop listening sessions
        _recipeNameSpeech.stop();
        _readyConfirmationSpeech.stop();
        
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cook Genie'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.initialRecipe == null)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          labelText: "Enter recipe name",
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: _searchRecipe,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: _isRecipeNameListening ? 70 : 60,
                      height: _isRecipeNameListening ? 70 : 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecipeNameListening ? Colors.redAccent : Colors.blue,
                        boxShadow: _isRecipeNameListening
                            ? [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.6),
                                  spreadRadius: 8,
                                  blurRadius: 12,
                                ),
                              ]
                            : [],
                      ),
                      child: GestureDetector(
                        onTap: _initializeAndStartVoiceSearch,
                        child: Icon(
                          _isRecipeNameListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              GetBuilder<VoiceAssistantController>(
                builder: (controller) {
                  if (!controller.isRecipeSpeaking && !controller.isRecipePaused && !_isRecipeNameListening && !_awaitingReadyConfirmation) {
                    return const SizedBox.shrink();
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (_isRecipeNameListening || _awaitingReadyConfirmation)
                          ? Colors.green.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (_isRecipeNameListening || _awaitingReadyConfirmation) ? Icons.mic : Icons.mic_off,
                          color: (_isRecipeNameListening || _awaitingReadyConfirmation) ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _awaitingReadyConfirmation
                              ? "Listening for 'ready'..."
                              : _isRecipeNameListening
                                  ? _clarificationQuery != null
                                      ? "Listening for specific recipe..."
                                      : "Listening for dish type..."
                                  : "Voice commands inactive",
                          style: TextStyle(
                            color: (_isRecipeNameListening || _awaitingReadyConfirmation) ? Colors.green : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_awaitingReadyConfirmation && _recipe != null)
                SizedBox(
                  height: 220,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Recipe Essentials for ${_recipe!['name']}:",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._buildEssentialsDisplay(_extractDetailedEssentials(_recipe!)),
                          const SizedBox(height: 12),
                          const Text(
                            "🎤 Say 'ready' when you want to begin cooking",
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_suggestedRecipes != null && _suggestedRecipes!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Suggested $_clarificationQuery recipes:",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(_suggestedRecipes!.map((recipe) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text("• $recipe", style: const TextStyle(fontSize: 13)),
                      )).toList()),
                      const SizedBox(height: 8),
                      const Text(
                        "Say the recipe name you want",
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _hasSearched
                    ? _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _recipe != null
                            ? _buildRecipeDetails()
                            : const Center(child: Text('No recipe found.'))
                    : const Center(
                        child: Text('Search for a recipe to begin.'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEssentialsDisplay(Map<String, dynamic> essentials) {
    return [
      _buildEssentialRow(Icons.restaurant_menu, 
        "Ingredients", "${essentials['ingredientCount']} items needed"),
      const SizedBox(height: 8),
      _buildEssentialRow(Icons.access_time, 
        "Time", essentials['estimatedTime']),
      const SizedBox(height: 8),
      _buildEssentialRow(Icons.signal_cellular_alt, 
        "Difficulty", essentials['difficulty']),
      const SizedBox(height: 8),
      _buildEssentialRow(Icons.people, 
        "Servings", essentials['servings']),
      const SizedBox(height: 8),
      _buildEssentialRow(Icons.shopping_basket, 
        "Key Items", essentials['keyIngredients']),
    ];
  }

  Widget _buildEssentialRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Recipe: ${_recipe!['name']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite
                      ? const Color.fromARGB(255, 168, 85, 236)
                      : null,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_recipe!['image_url'] != null &&
              _recipe!['image_url'].toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _recipe!['image_url'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Text('⚠️ Image failed to load'),
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'Ingredients:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ..._recipe!['ingredients'].map<Widget>((i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${i['name']} - ${i['quantity']}',
                style: const TextStyle(fontSize: 16),
                softWrap: true,
              ),
            );
          }).toList(),
          const SizedBox(height: 10),
          const Text(
            'Instructions:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ..._recipe!['instructions'].map<Widget>((s) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                s,
                style: const TextStyle(fontSize: 16),
                softWrap: true,
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
          GetBuilder<VoiceAssistantController>(
            builder: (controller) {
              return Column(
                children: [
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10, size: 30),
                          tooltip: "back",
                          onPressed: controller.rewindRecipe,
                        ),
                        IconButton(
                          icon: Icon(
                            controller.isRecipeSpeaking ? Icons.stop : Icons.play_arrow,
                            size: 36,
                          ),
                          tooltip: controller.isRecipeSpeaking ? "pause" : "play",
                          onPressed: () {
                            if (controller.isRecipeSpeaking) {
                              _stopManualRecipeReading();
                            } else {
                              _startManualRecipeReading();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10, size: 30),
                          tooltip: "Skip",
                          onPressed: controller.fastForwardRecipe,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: () {
                final ingredientNames = _recipe!['ingredients']
                    .map<String>((i) => '${i['name']} - ${i['quantity']}')
                    .toList();

                final groceryController = Get.find<GroceryController>();
                groceryController.addItems(ingredientNames);

                Get.snackbar(
                  "Success",
                  "Ingredients added to your grocery list",
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              child: const Text("Add to Grocery List"),
            ),
          ),
        ],
      ),
    );
  }
}