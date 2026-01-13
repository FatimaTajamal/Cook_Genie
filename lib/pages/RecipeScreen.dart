import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'firestore_saved_recipes_service.dart';
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

  String? _clarificationQuery;
  List<String>? _suggestedRecipes;
  bool _awaitingReadyConfirmation = false;

  bool _waitingForInitialRecipeName = false;

  // --- THEME CONSTANTS (match your other screens) ---
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

@override
void initState() {
  super.initState();

  final voiceController = Get.find<VoiceAssistantController>();

  // Stop any home listening/speech
  voiceController.stopAllSpeechRecognition();
  voiceController.stopHomeListening();
  voiceController.disableHomeAutoRestart();

  if (widget.isVoiceActivated) {
    if (widget.initialRecipe != null) {
      _recipe = widget.initialRecipe;
      _hasSearched = true;
      _ttsText = _formatRecipe(_recipe!);
      _isFavorite = widget.savedRecipes.any((r) => r['name'] == _recipe!['name']);

      voiceController.startRecipeReading(_formatRecipe(_recipe!));
    } else {
      _waitingForInitialRecipeName = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await voiceController.speak(
          "Please say the name of the dish you want to search for.",
        );
        // CHANGED: Reduced delay from 1500ms to 300ms for faster microphone activation
        await Future.delayed(const Duration(milliseconds: 300));
        _initializeAndStartVoiceSearch();
      });
    }
  } else {
    if (widget.initialRecipe != null) {
      _recipe = widget.initialRecipe;
      _hasSearched = true;
      _ttsText = _formatRecipe(_recipe!);
      _isFavorite = widget.savedRecipes.any((r) => r['name'] == _recipe!['name']);
    }
  }
}


  @override
  void dispose() {
    final voiceController = Get.find<VoiceAssistantController>();
    voiceController.stopRecipeReading();

    voiceController.enableHomeAutoRestart();
    voiceController.startHomeListening(savedRecipes: widget.savedRecipes);

    if (widget.isVoiceActivated) {
      voiceController.resetVoiceMode();
    }

    _recipeNameSpeech.stop();
    _readyConfirmationSpeech.stop();

    _clarificationQuery = null;
    _suggestedRecipes = null;
    _awaitingReadyConfirmation = false;
    _isRecipeNameListening = false;
    _waitingForInitialRecipeName = false;

    _controller.dispose();
    super.dispose();
  }

  // ---------- UI HELPERS ----------
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF2A1246),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ---------- LOGIC (UNCHANGED) ----------
  Future<void> _searchRecipe(String query) async {
    setState(() {
      _hasSearched = true;
      _isLoading = true;
    });

    final recipe = await RecipeService.getRecipe(query);

    if (recipe != null) {
      setState(() {
        _recipe = recipe;
        _isFavorite = widget.savedRecipes.any((r) => r['name'] == recipe['name']);
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

    await voiceController.speak(essentialsText);
    await voiceController.speak("Say ready when you want to begin cooking.");

    await Future.delayed(const Duration(milliseconds: 1000));

    if (_awaitingReadyConfirmation && mounted) {
      _initializeAndStartReadyListening();
    }
  }

  Map<String, dynamic> _extractDetailedEssentials(Map<String, dynamic> recipe) {
    final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
    final instructions = recipe['instructions'] as List<dynamic>? ?? [];

    List<String> keyIngredients = [];
    for (int i = 0; i < (ingredients.length > 8 ? 8 : ingredients.length); i++) {
      final ingredient = ingredients[i];
      keyIngredients.add(ingredient['name']);
    }

    String estimatedTime;
    if (instructions.length <= 5) {
      estimatedTime = "15 to 20 minutes";
    } else if (instructions.length <= 10) {
      estimatedTime = "30 to 45 minutes";
    } else {
      estimatedTime = "45 minutes to 1 hour";
    }

    String difficulty;
    if (instructions.length <= 5 && ingredients.length <= 8) {
      difficulty = "Easy";
    } else if (instructions.length <= 10 && ingredients.length <= 12) {
      difficulty = "Medium";
    } else {
      difficulty = "Advanced";
    }

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

  // Debug: Print the entire recipe structure
  print("📋 Formatting recipe:");
  print("Recipe keys: ${recipe.keys.toList()}");
  print("Recipe name: ${recipe['name']}");
  
  buffer.writeln('Recipe: ${recipe['name']}');
  buffer.writeln();
  
  // Debug ingredients
  print("Ingredients type: ${recipe['ingredients'].runtimeType}");
  print("Ingredients length: ${(recipe['ingredients'] as List?)?.length ?? 0}");
  
  buffer.writeln('Ingredients:');
  final ingredients = recipe['ingredients'] as List? ?? [];
  
  if (ingredients.isEmpty) {
    print("⚠️ WARNING: No ingredients found!");
  }
  
  for (var ingredient in ingredients) {
    print("Ingredient: $ingredient (${ingredient.runtimeType})");
    
    // Handle different ingredient formats
    if (ingredient is Map) {
      final name = ingredient['name'] ?? '';
      final quantity = ingredient['quantity'] ?? '';
      buffer.writeln('$name - $quantity');
    } else if (ingredient is String) {
      buffer.writeln(ingredient);
    }
  }

  buffer.writeln();
  
  // Debug instructions
  print("Instructions type: ${recipe['instructions'].runtimeType}");
  print("Instructions length: ${(recipe['instructions'] as List?)?.length ?? 0}");
  
  buffer.writeln('Instructions:');
  final instructions = recipe['instructions'] as List? ?? [];
  
  if (instructions.isEmpty) {
    print("⚠️ WARNING: No instructions found!");
  }
  
  for (int i = 0; i < instructions.length; i++) {
    print("Instruction $i: ${instructions[i]}");
    buffer.writeln('${i + 1}. ${instructions[i]}');
  }

  final result = buffer.toString();
  
  // Print the complete formatted text
  print("📝 Complete formatted recipe:");
  print("═" * 50);
  print(result);
  print("═" * 50);
  print("Total length: ${result.length} characters");
  print("Total lines: ${result.split('\n').length}");
  
  return result;
}

  Future<void> _toggleFavorite() async {
    if (_recipe == null) return;

    try {
      final isAlreadySaved = await FirestoreSavedRecipesService.isRecipeSaved(_recipe!['name'] ?? '');
      if (isAlreadySaved) {
        await FirestoreSavedRecipesService.removeRecipe(_recipe!);
        setState(() => _isFavorite = false);
        _showSnack('Removed ${_recipe!['name']} from saved recipes.');
      } else {
        await FirestoreSavedRecipesService.saveRecipe(_recipe!);
        setState(() => _isFavorite = true);
        _showSnack('Saved ${_recipe!['name']} to your recipes!');
      }
    } catch (e) {
      _showSnack('Error saving recipe: $e');
    }
  }

  Future<void> _initializeAndStartVoiceSearch() async {
    if (kIsWeb) {
      _initializeRecipeNameSpeech();
      return;
    }

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showSnack('Microphone permission denied');
        return;
      }
    }

    _initializeRecipeNameSpeech();
  }

  Future<void> _initializeRecipeNameSpeech() async {
    if (_recipeNameSpeechInitialized) {
      _startVoiceSearchListening();
      return;
    }

    bool available = await _recipeNameSpeech.initialize(
      onStatus: (val) {
        if (val == 'listening') {
          if (mounted) setState(() => _isRecipeNameListening = true);
        } else if (val == 'notListening' || val == 'done') {
          final wasListening = _isRecipeNameListening;
          if (mounted) setState(() => _isRecipeNameListening = false);
          if (wasListening && mounted) _autoRestartRecipeNameListening();
        }
      },
      onError: (val) {
        final wasListening = _isRecipeNameListening;
        if (mounted) setState(() => _isRecipeNameListening = false);
        if (wasListening && mounted) _autoRestartRecipeNameListening();
      },
    );

    if (available) {
      _recipeNameSpeechInitialized = true;
      _startVoiceSearchListening();
    } else {
      Future.delayed(const Duration(milliseconds: 500), _initializeRecipeNameSpeech);
    }
  }

  void _autoRestartRecipeNameListening() {
    bool shouldRestart =
        _waitingForInitialRecipeName || (_recipe == null && !_awaitingReadyConfirmation);

    if (!_isRecipeNameListening && shouldRestart && mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        bool stillShouldRestart =
            _waitingForInitialRecipeName || (_recipe == null && !_awaitingReadyConfirmation);
        if (!_isRecipeNameListening && stillShouldRestart && mounted) {
          _startVoiceSearchListening();
        }
      });
    }
  }

  void _startVoiceSearchListening() async {
    if (!mounted || _isRecipeNameListening || !_recipeNameSpeechInitialized) return;
    if (_recipe != null || _awaitingReadyConfirmation) return;

    await _recipeNameSpeech.stop();
    await Future.delayed(const Duration(milliseconds: 300));

    bool available = await _recipeNameSpeech.isAvailable;
    if (!available) {
      Future.delayed(const Duration(milliseconds: 500), _autoRestartRecipeNameListening);
      return;
    }

    setState(() => _isRecipeNameListening = true);

    try {
      _recipeNameSpeech.listen(
        onResult: (val) async {
          if (val.finalResult) {
            String recognizedWords = val.recognizedWords.trim().toLowerCase();

            setState(() {
              _controller.text = recognizedWords;
              _isLoading = true;
            });

            if (_clarificationQuery == null) {
              _waitingForInitialRecipeName = false;

              setState(() => _clarificationQuery = recognizedWords);

              List<String> suggestions =
                  await RecipeService.getRecipeSuggestions(recognizedWords);

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

                await Future.delayed(const Duration(milliseconds: 500));
                if (!mounted) return;
                setState(() => _isRecipeNameListening = false);
                _autoRestartRecipeNameListening();
              } else {
                setState(() {
                  _clarificationQuery = null;
                  _suggestedRecipes = null;
                  _isLoading = false;
                });

                final voiceController = Get.find<VoiceAssistantController>();
                await voiceController.speak(
                  "I couldn't find any $recognizedWords recipes. Please try another dish.",
                );

                _waitingForInitialRecipeName = true;

                await Future.delayed(const Duration(milliseconds: 500));
                if (!mounted) return;
                setState(() => _isRecipeNameListening = false);
                _autoRestartRecipeNameListening();
              }
            } else {
              String finalQuery = recognizedWords;

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

              if (!matchFound && _suggestedRecipes != null && _suggestedRecipes!.isNotEmpty) {
                for (String suggestion in _suggestedRecipes!) {
                  List<String> suggestionWords = suggestion.toLowerCase().split(' ');
                  List<String> recognizedWordsList = recognizedWords.split(' ');

                  int matchCount = 0;
                  for (String word in recognizedWordsList) {
                    if (suggestionWords.contains(word)) matchCount++;
                  }

                  if (matchCount >= 2 ||
                      (recognizedWordsList.length == 1 && matchCount >= 1)) {
                    finalQuery = suggestion;
                    matchFound = true;
                    break;
                  }
                }
              }

              await _recipeNameSpeech.stop();
              if (!mounted) return;
              setState(() {
                _isRecipeNameListening = false;
                _waitingForInitialRecipeName = false;
              });

              _clarificationQuery = null;
              _suggestedRecipes = null;

              setState(() => _isLoading = true);

              await _searchRecipe(finalQuery);
            }
          } else {
            if (mounted) setState(() => _controller.text = val.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );

      _startListeningMonitor();
    } catch (e) {
      if (mounted) setState(() => _isRecipeNameListening = false);
      Future.delayed(const Duration(milliseconds: 500), _autoRestartRecipeNameListening);
    }
  }

  void _startListeningMonitor() {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;

      bool shouldBeListening =
          _waitingForInitialRecipeName || (_recipe == null && !_awaitingReadyConfirmation);

      if (shouldBeListening && _isRecipeNameListening) {
        bool isActuallyListening = await _recipeNameSpeech.isListening;
        if (!isActuallyListening) {
          if (!mounted) return;
          setState(() => _isRecipeNameListening = false);
          _autoRestartRecipeNameListening();
        } else {
          _startListeningMonitor();
        }
      }
    });
  }

 Future<void> _initializeAndStartReadyListening() async {
  if (_readySpeechInitialized) {
    _startReadyConfirmationListening();
    return;
  }

  bool available = await _readyConfirmationSpeech.initialize(
    onStatus: (val) {
      print("🎙️ Ready speech status: $val");
      if (val == 'listening') {
        // Listening started
      } else if (val == 'notListening' || val == 'done') {
        // CHANGED: Added auto-restart logic for persistent listening
        if (_awaitingReadyConfirmation && mounted) {
          print("🔄 Ready listening stopped, will auto-restart");
          _autoRestartReadyListening();
        }
      }
    },
    onError: (val) {
      print("❌ Ready speech error: $val");
      // CHANGED: Added auto-restart on error
      if (_awaitingReadyConfirmation && mounted) {
        _autoRestartReadyListening();
      }
    },
  );

  if (available) {
    _readySpeechInitialized = true;
    _startReadyConfirmationListening();
  } else {
    print("⚠️ Ready speech not available, retrying...");
    Future.delayed(const Duration(milliseconds: 500), _initializeAndStartReadyListening);
  }
}

  void _autoRestartReadyListening() {
  print("🔄 Auto-restart ready listening check...");
  print("   _awaitingReadyConfirmation: $_awaitingReadyConfirmation");
  print("   mounted: $mounted");
  
  if (_awaitingReadyConfirmation && mounted) {
    print("   ✅ Scheduling restart in 300ms");
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_awaitingReadyConfirmation && mounted) {
        print("   🎙️ Restarting ready listening now");
        _startReadyConfirmationListening();
      }
    });
  } else {
    print("   ⏭️ Not restarting - conditions not met");
  }
}


  void _startReadyConfirmationListening() async {
  print("🎯 _startReadyConfirmationListening called");
  print("   _awaitingReadyConfirmation: $_awaitingReadyConfirmation");
  print("   _readySpeechInitialized: $_readySpeechInitialized");
  print("   mounted: $mounted");
  
  if (!mounted || !_awaitingReadyConfirmation || !_readySpeechInitialized) {
    print("   ⏭️ Skipping - conditions not met");
    return;
  }

  // ADDED: Stop any existing listening first for clean state
  await _readyConfirmationSpeech.stop();
  await Future.delayed(const Duration(milliseconds: 200));

  bool available = await _readyConfirmationSpeech.isAvailable;
  if (!available) {
    print("   ⚠️ Speech not available, will retry");
    Future.delayed(const Duration(milliseconds: 500), _autoRestartReadyListening);
    return;
  }

  print("   🎙️ Starting to listen for 'ready'...");

  try {
    await _readyConfirmationSpeech.listen(
      onResult: (val) async {
        if (val.finalResult) {
          String recognizedWords = val.recognizedWords.trim().toLowerCase();
          final voiceController = Get.find<VoiceAssistantController>();

          print("🎤 Ready mode heard: $recognizedWords");

          if (!mounted) return;
          setState(() => _controller.text = recognizedWords);

          if (_awaitingReadyConfirmation && recognizedWords.contains("ready")) {
            print("✅ 'Ready' detected! Starting recipe reading...");
            
            setState(() => _awaitingReadyConfirmation = false);
            await _readyConfirmationSpeech.stop();

            await voiceController.startRecipeReading(_formatRecipe(_recipe!));
          }
          // If we're still waiting and it wasn't "ready", listening will auto-restart via onStatus
        } else {
          // Partial results
          if (mounted) setState(() => _controller.text = val.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 60),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.confirmation,
    );
    
    // ADDED: Start monitoring to ensure listening continues
    _startReadyListeningMonitor();
    
  } catch (e) {
    print("❌ Error starting ready listening: $e");
    Future.delayed(const Duration(milliseconds: 500), _autoRestartReadyListening);
  }
}

void _startReadyListeningMonitor() {
  Future.delayed(const Duration(milliseconds: 2000), () async {
    if (!mounted || !_awaitingReadyConfirmation) {
      print("👀 Ready monitor - stopping (not mounted or not awaiting)");
      return;
    }

    bool isActuallyListening = await _readyConfirmationSpeech.isListening;
    print("👀 Ready listening monitor - isListening: $isActuallyListening");
    
    if (!isActuallyListening && _awaitingReadyConfirmation) {
      print("   ⚠️ Not actually listening, restarting...");
      _autoRestartReadyListening();
    } else if (isActuallyListening) {
      // Continue monitoring
      print("   ✅ Still listening, continue monitoring");
      _startReadyListeningMonitor();
    }
  });
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

  // ---------- UI BUILD ----------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final voiceController = Get.find<VoiceAssistantController>();
        voiceController.stopRecipeReading();

        voiceController.enableHomeAutoRestart();
        voiceController.startHomeListening(savedRecipes: widget.savedRecipes);

        if (widget.isVoiceActivated) {
          voiceController.resetVoiceMode();
        }

        _recipeNameSpeech.stop();
        _readyConfirmationSpeech.stop();

        return true;
      },
      child: Scaffold(
        backgroundColor: _bgTop,
        appBar: AppBar(
          backgroundColor: const Color(0xFF120A22),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'CookGenie',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          foregroundColor: Colors.white,
          actions: [
            if (_recipe != null)
              IconButton(
                tooltip: _isFavorite ? "Saved" : "Save",
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFavorite ? _accent : Colors.white.withOpacity(0.85),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            _bgGradient(),
            _bgStars(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.initialRecipe == null) _searchRow(),
                    if (widget.initialRecipe == null) const SizedBox(height: 12),

                    _voiceStatusPill(),
                    const SizedBox(height: 12),

                    if (_awaitingReadyConfirmation && _recipe != null)
                      _essentialsCard(),
                    if (_awaitingReadyConfirmation && _recipe != null)
                      const SizedBox(height: 12),

                    if (_suggestedRecipes != null && _suggestedRecipes!.isNotEmpty)
                      _suggestionsCard(),
                    if (_suggestedRecipes != null && _suggestedRecipes!.isNotEmpty)
                      const SizedBox(height: 12),

                    Expanded(child: _content()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (!_hasSearched) {
      return Center(
        child: Text(
          'Search for a recipe to begin.',
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w600),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }

    if (_recipe == null) {
      return Center(
        child: Text(
          'No recipe found.',
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700),
        ),
      );
    }

    return _buildRecipeDetailsThemed();
  }

  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  _accent2.withOpacity(0.20),
                  _accent.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              cursorColor: _accent,
              decoration: InputDecoration(
                hintText: "e.g., chicken biryani",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onSubmitted: _searchRecipe,
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: _isRecipeNameListening ? 66 : 58,
          height: _isRecipeNameListening ? 66 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isRecipeNameListening ? Colors.redAccent : _accent,
            boxShadow: _isRecipeNameListening
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.55),
                      spreadRadius: 6,
                      blurRadius: 14,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: _accent.withOpacity(0.35),
                      spreadRadius: 2,
                      blurRadius: 14,
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _initializeAndStartVoiceSearch,
            child: Icon(
              _isRecipeNameListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _voiceStatusPill() {
    return GetBuilder<VoiceAssistantController>(
      builder: (controller) {
        final shouldShow =
            controller.isRecipeSpeaking || controller.isRecipePaused || _isRecipeNameListening || _awaitingReadyConfirmation;

        if (!shouldShow) return const SizedBox.shrink();

        final bool activeListening = _isRecipeNameListening || _awaitingReadyConfirmation;

        final text = _awaitingReadyConfirmation
            ? "Listening for 'ready'..."
            : _isRecipeNameListening
                ? (_clarificationQuery != null
                    ? "Listening for specific recipe..."
                    : "Listening for dish type...")
                : "Voice active";

        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: activeListening ? _accent.withOpacity(0.16) : Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activeListening ? Icons.mic_rounded : Icons.graphic_eq_rounded,
                  size: 16,
                  color: activeListening ? _accent : Colors.white.withOpacity(0.65),
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: activeListening ? Colors.white.withOpacity(0.92) : Colors.white.withOpacity(0.70),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _essentialsCard() {
    final essentials = _extractDetailedEssentials(_recipe!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            _accent2.withOpacity(0.16),
            const Color(0xFF2A1246).withOpacity(0.30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Essentials • ${_recipe!['name']}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5),
          ),
          const SizedBox(height: 10),
          ..._buildEssentialsDisplayThemed(essentials),
          const SizedBox(height: 10),
          Text(
            "🎤 Say 'ready' when you want to begin cooking",
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            _accent2.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Suggested $_clarificationQuery recipes",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          ..._suggestedRecipes!.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                "• $r",
                style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Say the recipe name you want",
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEssentialsDisplayThemed(Map<String, dynamic> essentials) {
    return [
      _essentialRow(Icons.restaurant_menu_rounded, "Ingredients", "${essentials['ingredientCount']} items"),
      const SizedBox(height: 8),
      _essentialRow(Icons.access_time_rounded, "Time", essentials['estimatedTime']),
      const SizedBox(height: 8),
      _essentialRow(Icons.signal_cellular_alt_rounded, "Difficulty", essentials['difficulty']),
      const SizedBox(height: 8),
      _essentialRow(Icons.people_alt_rounded, "Servings", essentials['servings']),
      const SizedBox(height: 8),
      _essentialRow(Icons.shopping_basket_rounded, "Key items", essentials['keyIngredients']),
    ];
  }

  Widget _essentialRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _accent),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.78), height: 1.25),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.92)),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeDetailsThemed() {
    final name = (_recipe!['name'] ?? 'Recipe').toString();

    final imageUrl = (_recipe!['image_url'] ?? '').toString();
    final ingredients = (_recipe!['ingredients'] as List? ?? []);
    final instructions = (_recipe!['instructions'] as List? ?? []);

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // Title card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.06),
                _accent2.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFavorite ? _accent : Colors.white.withOpacity(0.7),
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Image
        if (imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              imageUrl,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 210,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  '⚠️ Image failed to load',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        if (imageUrl.isNotEmpty) const SizedBox(height: 12),

        _sectionHeader("Ingredients"),
        const SizedBox(height: 8),
        ...ingredients.map<Widget>((i) {
          final n = (i is Map ? i['name'] : '').toString();
          final q = (i is Map ? i['quantity'] : '').toString();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Text(
                "$n — $q",
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700),
              ),
            ),
          );
        }).toList(),

        const SizedBox(height: 14),
        _sectionHeader("Instructions"),
        const SizedBox(height: 8),
        ...instructions.asMap().entries.map<Widget>((entry) {
          final idx = entry.key + 1;
          final text = entry.value.toString();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.06),
                    _accent2.withOpacity(0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Text(
                      "$idx",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(color: Colors.white.withOpacity(0.80), height: 1.25, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        const SizedBox(height: 14),
        _voiceControlsCard(),
        const SizedBox(height: 14),
        _addToGroceryButton(),
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.92),
        fontWeight: FontWeight.w900,
        fontSize: 14.5,
      ),
    );
  }

  Widget _voiceControlsCard() {
    return GetBuilder<VoiceAssistantController>(
      builder: (controller) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, size: 30),
                color: Colors.white.withOpacity(0.85),
                tooltip: "Back",
                onPressed: controller.rewindRecipe,
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  if (controller.isRecipeSpeaking) {
                    _stopManualRecipeReading();
                  } else {
                    _startManualRecipeReading();
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent,
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    controller.isRecipeSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.forward_10_rounded, size: 30),
                color: Colors.white.withOpacity(0.85),
                tooltip: "Skip",
                onPressed: controller.fastForwardRecipe,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _addToGroceryButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          if (_recipe == null) return;

          final ingredientNames = (_recipe!['ingredients'] as List)
              .map<String>((i) => '${i['name']} - ${i['quantity']}')
              .toList();

          final groceryController = Get.find<GroceryController>();
          groceryController.addItems(ingredientNames);

          _showSnack("Ingredients added to your grocery list");
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text(
          "Add to Grocery List",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.2),
        ),
      ),
    );
  }

  // ---------- BACKGROUND ----------
  Widget _bgGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgMid, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _bgStars() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 22,
            top: 110,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.06), size: 28),
          ),
          Positioned(
            right: 18,
            top: 160,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.05), size: 34),
          ),
          Positioned(
            right: 60,
            top: 380,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.05), size: 26),
          ),
        ],
      ),
    );
  }
}