import 'package:flutter/foundation.dart' show kIsWeb;
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
  late stt.SpeechToText _speech;

  bool _isListening = false;
  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isFavorite = false;

  String _ttsText = "";
  Map<String, dynamic>? _recipe;

  // State variable for the multi-stage voice flow
  String? _clarificationQuery;
  List<String>? _suggestedRecipes;
  bool _awaitingReadyConfirmation = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    final voiceController = Get.find<VoiceAssistantController>();
    
    voiceController.stopHomeListening();

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
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await voiceController.speak(
            "Please say the name of the dish you want to search for.",
          );
          await Future.delayed(const Duration(milliseconds: 2000));
          _listen();
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
    
    voiceController.startHomeListening(savedRecipes: widget.savedRecipes);
    
    if (widget.isVoiceActivated) {
      voiceController.resetVoiceMode();
    }

    // Reset clarification state
    _clarificationQuery = null;
    _suggestedRecipes = null;
    _awaitingReadyConfirmation = false;

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
         await Future.delayed(const Duration(milliseconds: 2000));
         _listen();
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
    
    // Speak the essentials first
    await voiceController.speak(essentialsText);
    
    // Wait a bit to ensure TTS is completely done
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Now say "Say ready when you want to begin cooking" separately
    await voiceController.speak("Say ready when you want to begin cooking.");
    
    // Wait for this second TTS to completely finish before starting mic
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (_awaitingReadyConfirmation && mounted) {
      _listenContinuously();
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

  void _toggleFavorite() {
    if (_recipe == null) return;

    setState(() {
      if (_isFavorite) {
        widget.savedRecipes.removeWhere((r) => r['name'] == _recipe!['name']);
        _isFavorite = false;
      } else {
        widget.savedRecipes.add(_recipe!);
        _isFavorite = true;
      }
    });
  }

  Future<void> _listen() async {
    if (kIsWeb) {
      _startListening();
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

    _startListening();
  }

  // New method for continuous listening during "ready" confirmation
  Future<void> _listenContinuously() async {
    if (kIsWeb) {
      _startContinuousListening();
      return;
    }

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        return;
      }
    }

    _startContinuousListening();
  }

  void _startContinuousListening() async {
    if (!mounted) return;
    
    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    bool available = await _speech.initialize(
      onStatus: (val) {
        print("Continuous listening status: $val");
        if (val == 'done' || val == 'notListening') {
          // Automatically restart listening if still waiting for ready
          if (_awaitingReadyConfirmation && mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_awaitingReadyConfirmation && mounted) {
                _startContinuousListening();
              }
            });
          }
        }
      },
      onError: (val) {
        print("Continuous listening error: $val");
        // Restart on error
        if (_awaitingReadyConfirmation && mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_awaitingReadyConfirmation && mounted) {
              _startContinuousListening();
            }
          });
        }
      },
    );

    if (available && _awaitingReadyConfirmation && mounted) {
      setState(() => _isListening = true);

      _speech.listen(
        onResult: (val) async {
          if (val.finalResult) {
            String recognizedWords = val.recognizedWords.trim().toLowerCase();
            final voiceController = Get.find<VoiceAssistantController>();

            print("Recognized in ready mode: $recognizedWords");

            setState(() {
              _controller.text = recognizedWords;
            });

            if (_awaitingReadyConfirmation) {
              if (recognizedWords.contains("ready")) {
                setState(() {
                  _awaitingReadyConfirmation = false;
                  _isListening = false;
                });
                
                await _speech.stop();
                
                // Start reading the full recipe
                await voiceController.startRecipeReading(_formatRecipe(_recipe!));
              } else {
                // Keep listening continuously - will auto-restart via status callback
                print("Did not detect 'ready', will continue listening");
              }
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
      );
    }
  }

  void _startListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (val) => _onSpeechStatus(val),
      onError: (val) => _onSpeechError(val),
    );

    if (available) {
      setState(() => _isListening = true);

      _speech.listen(
        onResult: (val) async {
          if (val.finalResult) {
            String recognizedWords = val.recognizedWords.trim().toLowerCase();
            final voiceController = Get.find<VoiceAssistantController>();

            setState(() {
              _controller.text = recognizedWords;
              _isListening = false;
              _isLoading = true;
            });

            await _speech.stop();
            
            if (_clarificationQuery == null) {
              // STAGE 1: User said something like "Pasta"
              setState(() {
                _clarificationQuery = recognizedWords;
              });

              List<String> suggestions = await RecipeService.getRecipeSuggestions(recognizedWords);
              
              if (suggestions.isNotEmpty) {
                setState(() {
                  _suggestedRecipes = suggestions;
                  _isLoading = false;
                });

                String clarificationText = "Here are some $recognizedWords recipes: ";
                clarificationText += suggestions.join(", ");
                clarificationText += ". Which one would you like?";
                
                await voiceController.speak(clarificationText);
                
                // Wait for TTS to finish before starting mic
                await Future.delayed(const Duration(milliseconds: 2000));
                _startListening();

              } else {
                setState(() {
                  _clarificationQuery = null;
                  _suggestedRecipes = null;
                  _isLoading = false;
                });
                
                await voiceController.speak(
                  "I couldn't find any $recognizedWords recipes. Please try another dish."
                );
                await Future.delayed(const Duration(milliseconds: 2000));
                _startListening();
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
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'done') {
      if (_clarificationQuery == null && _isLoading == false && !_awaitingReadyConfirmation) {
         setState(() => _isListening = false);
      }
    }
  }

  void _onSpeechError(dynamic error) {
    print("Speech error: $error");
    setState(() {
      _isListening = false;
      _isLoading = false;
    });
    
    // Don't reset states during ready confirmation
    if (!_awaitingReadyConfirmation) {
      setState(() {
        _clarificationQuery = null;
        _suggestedRecipes = null;
      });
    }
    // Continuous listening will auto-restart via its own error handler
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
        
        voiceController.startHomeListening(savedRecipes: widget.savedRecipes);
        
        if (widget.isVoiceActivated) {
          voiceController.resetVoiceMode();
        }
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
                      width: _isListening ? 70 : 60,
                      height: _isListening ? 70 : 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.redAccent : Colors.blue,
                        boxShadow: _isListening
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
                        onTap: _listen,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
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
                  if (!controller.isRecipeSpeaking && !controller.isRecipePaused && !(_isListening && widget.isVoiceActivated)) {
                    return const SizedBox.shrink();
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (_isListening || controller.isListening) 
                          ? Colors.green.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (_isListening || controller.isListening) ? Icons.mic : Icons.mic_off,
                          color: (_isListening || controller.isListening) ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _awaitingReadyConfirmation
                              ? "Waiting for 'ready' confirmation..."
                              : (_isListening || controller.isListening)
                                  ? _clarificationQuery != null
                                      ? "Listening for specific recipe..."
                                      : "Listening for dish type..."
                                  : "Voice commands inactive",
                          style: TextStyle(
                            color: (_isListening || controller.isListening) ? Colors.green : Colors.grey,
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