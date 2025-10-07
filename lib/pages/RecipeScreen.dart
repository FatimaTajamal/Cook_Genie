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

  // State variable for the two-stage voice flow
  String? _clarificationQuery;
  List<String>? _suggestedRecipes; // Store the fetched suggestions

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
          await Future.delayed(const Duration(milliseconds: 500));
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
        await voiceController.startRecipeReading(_formatRecipe(recipe));
      }
    } else {
      if (widget.isVoiceActivated) {
         final voiceController = Get.find<VoiceAssistantController>();
         await voiceController.speak("I couldn't find a recipe for $query. Please try another name.");
         await Future.delayed(const Duration(milliseconds: 500));
         _listen();
      }
      
      setState(() {
        _recipe = null;
        _ttsText = "";
        _isLoading = false;
      });
    }
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
            String recognizedWords = val.recognizedWords.trim();
            final voiceController = Get.find<VoiceAssistantController>();

            setState(() {
              _controller.text = recognizedWords;
              _isListening = false;
              _isLoading = true;
            });

            await _speech.stop();
            
            // --- UPDATED TWO-STAGE LOGIC ---
            if (_clarificationQuery == null) {
              // STAGE 1: User said something like "Pasta"
              // Fetch actual recipe suggestions from Gemini
              setState(() {
                _clarificationQuery = recognizedWords;
              });

              // Fetch suggestions
              List<String> suggestions = await RecipeService.getRecipeSuggestions(recognizedWords);
              
              if (suggestions.isNotEmpty) {
                setState(() {
                  _suggestedRecipes = suggestions;
                  _isLoading = false;
                });

                // Build the speech text
                String clarificationText = "Here are some $recognizedWords recipes: ";
                clarificationText += suggestions.join(", ");
                clarificationText += ". Which one would you like?";
                
                await voiceController.speak(clarificationText);
                
                // Start listening again for the specific recipe
                await Future.delayed(const Duration(milliseconds: 500));
                _startListening();

              } else {
                // No suggestions found, ask user to try again
                setState(() {
                  _clarificationQuery = null;
                  _suggestedRecipes = null;
                  _isLoading = false;
                });
                
                await voiceController.speak(
                  "I couldn't find any $recognizedWords recipes. Please try another dish."
                );
                await Future.delayed(const Duration(milliseconds: 500));
                _startListening();
              }

            } else {
              // STAGE 2: User gave the specific recipe name
              String finalQuery = recognizedWords;
              
              // Reset state for next time
              _clarificationQuery = null;
              _suggestedRecipes = null;
              
              setState(() {
                _isLoading = true;
              });

              await _searchRecipe(finalQuery);
            }
            // --- END OF UPDATED TWO-STAGE LOGIC ---

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
      if (_clarificationQuery == null && _isLoading == false) {
         setState(() => _isListening = false);
      }
    }
  }

  void _onSpeechError(dynamic error) {
    setState(() {
      _isListening = false;
      _isLoading = false;
      _clarificationQuery = null;
      _suggestedRecipes = null;
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
                          (_isListening || controller.isListening)
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
              // Show suggested recipes during clarification
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
                          icon: const Icon(Icons.skip_previous, size: 30),
                          tooltip: "Previous section",
                          onPressed: controller.rewindRecipe,
                        ),
                        IconButton(
                          icon: Icon(
                            controller.isRecipeSpeaking ? Icons.pause : Icons.play_arrow,
                            size: 36,
                          ),
                          tooltip: controller.isRecipeSpeaking ? "Pause" : "Play",
                          onPressed: () {
                            if (controller.isRecipeSpeaking) {
                              _stopManualRecipeReading();
                            } else {
                              _startManualRecipeReading();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 30),
                          tooltip: "Next section",
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