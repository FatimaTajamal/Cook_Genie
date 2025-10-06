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
  final bool isVoiceActivated; // Flag to know if voice mode is active

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

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    final voiceController = Get.find<VoiceAssistantController>();
    
    // ✅ Stop home page listening when entering recipe screen
    voiceController.onHomePageLeft();

    // ✅ Only activate voice features if voice mode is on
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
            "Please say the recipe name you want to search.",
          );
          await Future.delayed(const Duration(milliseconds: 500));
          _listen();
        });
      }
    } else {
      // Manual mode - just show the initial recipe if provided
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
    
    // ✅ Re-enable home page listening when leaving recipe screen
    voiceController.enableContinuousListening(savedRecipes: widget.savedRecipes);
    
    // Reset voice mode when leaving screen
    if (widget.isVoiceActivated) {
      voiceController.resetVoiceMode();
    }

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

      // ✅ Only read recipe if in voice mode
      if (widget.isVoiceActivated) {
        final voiceController = Get.find<VoiceAssistantController>();
        await voiceController.startRecipeReading(_formatRecipe(recipe));
      }
    } else {
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
            setState(() {
              _controller.text = val.recognizedWords;
              _isListening = false;
              _isLoading = true;
            });

            await _speech.stop();
            await _searchRecipe(val.recognizedWords);
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
      setState(() => _isListening = false);
    }
  }

  void _onSpeechError(dynamic error) {
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final voiceController = Get.find<VoiceAssistantController>();
        voiceController.stopRecipeReading();
        
        // ✅ Re-enable home page listening when back button pressed
        voiceController.enableContinuousListening(savedRecipes: widget.savedRecipes);
        
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
              // ✅ Only show voice status if in voice mode
              if (widget.isVoiceActivated)
                GetBuilder<VoiceAssistantController>(
                  builder: (controller) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: controller.isRecipeListening 
                            ? Colors.green.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            controller.isRecipeListening ? Icons.mic : Icons.mic_off,
                            color: controller.isRecipeListening ? Colors.green : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            controller.isRecipeListening 
                                ? "Voice commands active (say 'pause' or 'play')"
                                : "Voice commands inactive",
                            style: TextStyle(
                              color: controller.isRecipeListening ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (widget.isVoiceActivated) const SizedBox(height: 16),
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
          // ✅ Only show playback controls if in voice mode
          if (widget.isVoiceActivated)
            GetBuilder<VoiceAssistantController>(
              builder: (controller) {
                return Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fast_rewind),
                        onPressed: controller.rewindRecipe,
                      ),
                      IconButton(
                        icon: Icon(controller.isRecipeSpeaking ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          if (controller.isRecipeSpeaking) {
                            controller.pauseRecipe();
                          } else {
                            controller.resumeRecipe();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.fast_forward),
                        onPressed: controller.fastForwardRecipe,
                      ),
                    ],
                  ),
                );
              },
            ),
          Center(
            child: ElevatedButton(
              onPressed: () {
                final ingredientNames = _recipe!['ingredients']
                    .map<String>((i) => i['name'].toString())
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








// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:get/get.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:permission_handler/permission_handler.dart';

// import 'RecipeSearch.dart';
// import 'grocery_list_screen.dart';
// import 'voice_assistant_controller.dart';

// class RecipeScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> savedRecipes;
//   final Map<String, dynamic>? initialRecipe;

//   const RecipeScreen({
//     super.key,
//     required this.savedRecipes,
//     this.initialRecipe,
//   });

//   @override
//   _RecipeScreenState createState() => _RecipeScreenState();
// }

// class _RecipeScreenState extends State<RecipeScreen> {
//   final TextEditingController _controller = TextEditingController();
//   final FlutterTts _tts = FlutterTts();
//   late stt.SpeechToText _speech;

//   bool _isSpeaking = false;
//   bool _isListening = false;
//   bool _hasSearched = false;
//   bool _isLoading = false;
//   bool _isFavorite = false;
//   bool _isPaused = false;

//   String _ttsText = "";
//   final double _speechRate = 0.5;
//   int _currentTextIndex = 0;
//   List<String> _formattedTextParts = [];
//   Map<String, dynamic>? _recipe;

//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _setupTTS();

//     final voiceController = Get.find<VoiceAssistantController>();

//     // 🔴 Stop Home mic
//     voiceController.onHomePageLeft();

//     // 🟢 Enable mic only for RecipeScreen
//     voiceController.enableContinuousListening(savedRecipes: widget.savedRecipes);

//     if (widget.initialRecipe != null) {
//       _recipe = widget.initialRecipe;
//       _hasSearched = true;
//       _ttsText = _formatRecipe(_recipe!);
//       _formattedTextParts = _ttsText.split(RegExp(r'(?<=[.!?])\s+'));
//       _currentTextIndex = 0;
//       _isFavorite = widget.savedRecipes.any(
//         (r) => r['name'] == _recipe!['name'],
//       );

//       // Speak recipe automatically
//       voiceController.speak(_formatRecipe(_recipe!));
//     } else {
//       WidgetsBinding.instance.addPostFrameCallback((_) async {
//         await voiceController.speak(
//           "Please say the recipe name you want to search.",
//         );
//         await Future.delayed(const Duration(milliseconds: 500));
//         _listen();
//       });
//     }
//   }

//   void _setupTTS() {
//     _tts.setVolume(1.0);
//     _tts.setSpeechRate(_speechRate);
//     _tts.setPitch(1.0);

//     _tts.setCompletionHandler(() {
//       setState(() {
//         _isSpeaking = false;
//         _isPaused = false;
//       });
//     });

//     _tts.setStartHandler(() {
//       setState(() => _isSpeaking = true);
//     });
//   }

//   @override
//   void dispose() {
//     _tts.stop();
//     _controller.dispose();

//     // 🔴 Disable mic when leaving screen
//     final voiceController = Get.find<VoiceAssistantController>();
//     voiceController.disableContinuousListening();

//     super.dispose();
//   }

//   Future<void> _searchRecipe(String query) async {
//     setState(() {
//       _hasSearched = true;
//       _isLoading = true;
//     });

//     final recipe = await RecipeService.getRecipe(query);

//     if (recipe != null) {
//       setState(() {
//         _recipe = recipe;
//         _isFavorite = widget.savedRecipes.any(
//           (r) => r['name'] == recipe['name'],
//         );
//         _ttsText = _formatRecipe(recipe);
//         _formattedTextParts = _ttsText.split(RegExp(r'(?<=[.!?])\s+'));
//         _currentTextIndex = 0;
//         _isLoading = false;
//       });

//       final voiceController = Get.find<VoiceAssistantController>();
//       await voiceController.speak(_formatRecipe(recipe));
//     } else {
//       setState(() {
//         _recipe = null;
//         _ttsText = "";
//         _formattedTextParts.clear();
//         _isLoading = false;
//       });
//     }
//   }

//   String _formatRecipe(Map<String, dynamic> recipe) {
//     final buffer = StringBuffer();

//     buffer.writeln('Recipe: ${recipe['name']}');
//     buffer.writeln('Ingredients:');
//     for (var ingredient in recipe['ingredients']) {
//       buffer.writeln('${ingredient['name']} - ${ingredient['quantity']}');
//     }

//     buffer.writeln('Instructions:');
//     for (var step in recipe['instructions']) {
//       buffer.writeln(step);
//     }

//     return buffer.toString();
//   }

//   void _playTTS() {
//     if (_currentTextIndex < _formattedTextParts.length) {
//       final textToRead = _formattedTextParts.sublist(_currentTextIndex).join(' ');
//       _tts.speak(textToRead);
//       setState(() => _isSpeaking = true);
//     }
//   }

//   void _pauseTTS() {
//     _tts.stop();
//     setState(() {
//       _isSpeaking = false;
//       _isPaused = true;
//     });
//   }

//   void _resumeTTS() {
//     if (_isPaused) {
//       _playTTS();
//       setState(() => _isPaused = false);
//     }
//   }

//   void _rewind() {
//     if (_currentTextIndex > 0) {
//       _currentTextIndex--;
//       _tts.stop().then((_) {
//         _playTTS();
//         setState(() => _isPaused = false);
//       });
//     }
//   }

//   void _fastForward() {
//     if (_currentTextIndex < _formattedTextParts.length - 1) {
//       _currentTextIndex++;
//       _tts.stop().then((_) {
//         _playTTS();
//         setState(() => _isPaused = false);
//       });
//     }
//   }

//   void _toggleFavorite() {
//     if (_recipe == null) return;

//     setState(() {
//       if (_isFavorite) {
//         widget.savedRecipes.removeWhere((r) => r['name'] == _recipe!['name']);
//         _isFavorite = false;
//       } else {
//         widget.savedRecipes.add(_recipe!);
//         _isFavorite = true;
//       }
//     });
//   }

//   Future<void> _listen() async {
//     if (kIsWeb) {
//       _startListening();
//       return;
//     }

//     var status = await Permission.microphone.status;
//     if (!status.isGranted) {
//       status = await Permission.microphone.request();
//       if (!status.isGranted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Microphone permission denied')),
//         );
//         return;
//       }
//     }

//     _startListening();
//   }

//   void _startListening() async {
//     if (_speech.isListening) {
//       await _speech.stop();
//       setState(() => _isListening = false);
//       return;
//     }

//     bool available = await _speech.initialize(
//       onStatus: (val) => _onSpeechStatus(val),
//       onError: (val) => _onSpeechError(val),
//     );

//     if (available) {
//       setState(() => _isListening = true);

//       _speech.listen(
//         onResult: (val) async {
//           if (val.finalResult) {
//             setState(() {
//               _controller.text = val.recognizedWords;
//               _isListening = false;
//               _isLoading = true;
//             });

//             await _speech.stop();
//             await _searchRecipe(val.recognizedWords);
//           } else {
//             setState(() {
//               _controller.text = val.recognizedWords;
//             });
//           }
//         },
//         listenFor: const Duration(seconds: 5),
//         pauseFor: const Duration(seconds: 3),
//       );
//     }
//   }

//   void _onSpeechStatus(String status) {
//     if (status == 'done') {
//       setState(() => _isListening = false);
//     }
//   }

//   void _onSpeechError(dynamic error) {
//     setState(() => _isListening = false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         _tts.stop();
//         return true;
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Cook Genie'),
//         ),
//         body: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               if (widget.initialRecipe == null)
//                 Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _controller,
//                         decoration: const InputDecoration(
//                           labelText: "Enter recipe name",
//                           border: OutlineInputBorder(),
//                         ),
//                         onSubmitted: _searchRecipe,
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     AnimatedContainer(
//                       duration: const Duration(milliseconds: 500),
//                       width: _isListening ? 70 : 60,
//                       height: _isListening ? 70 : 60,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: _isListening ? Colors.redAccent : Colors.blue,
//                         boxShadow: _isListening
//                             ? [
//                                 BoxShadow(
//                                   color: Colors.redAccent.withOpacity(0.6),
//                                   spreadRadius: 8,
//                                   blurRadius: 12,
//                                 ),
//                               ]
//                             : [],
//                       ),
//                       child: GestureDetector(
//                         onTap: _listen,
//                         child: Icon(
//                           _isListening ? Icons.mic : Icons.mic_none,
//                           color: Colors.white,
//                           size: 30,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               const SizedBox(height: 16),
//               Expanded(
//                 child: _hasSearched
//                     ? _isLoading
//                         ? const Center(child: CircularProgressIndicator())
//                         : _recipe != null
//                             ? _buildRecipeDetails()
//                             : const Center(child: Text('No recipe found.'))
//                     : const Center(
//                         child: Text('Search for a recipe to begin.'),
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildRecipeDetails() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.only(bottom: 24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Text(
//                   'Recipe: ${_recipe!['name']}',
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               IconButton(
//                 icon: Icon(
//                   _isFavorite ? Icons.favorite : Icons.favorite_border,
//                   color: _isFavorite
//                       ? const Color.fromARGB(255, 168, 85, 236)
//                       : null,
//                 ),
//                 onPressed: _toggleFavorite,
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           if (_recipe!['image_url'] != null &&
//               _recipe!['image_url'].toString().isNotEmpty)
//             ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: Image.network(
//                 _recipe!['image_url'],
//                 height: 200,
//                 width: double.infinity,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stackTrace) =>
//                     const Text('⚠️ Image failed to load'),
//               ),
//             ),
//           const SizedBox(height: 10),
//           const Text(
//             'Ingredients:',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           ..._recipe!['ingredients'].map<Widget>((i) {
//             return Padding(
//               padding: const EdgeInsets.symmetric(vertical: 2),
//               child: Text(
//                 '${i['name']} - ${i['quantity']}',
//                 style: const TextStyle(fontSize: 16),
//                 softWrap: true,
//               ),
//             );
//           }).toList(),
//           const SizedBox(height: 10),
//           const Text(
//             'Instructions:',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           ..._recipe!['instructions'].map<Widget>((s) {
//             return Padding(
//               padding: const EdgeInsets.symmetric(vertical: 2),
//               child: Text(
//                 s,
//                 style: const TextStyle(fontSize: 16),
//                 softWrap: true,
//               ),
//             );
//           }).toList(),
//           const SizedBox(height: 20),
//           Center(
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.fast_rewind),
//                   onPressed: _rewind,
//                 ),
//                 IconButton(
//                   icon: Icon(_isSpeaking ? Icons.pause : Icons.play_arrow),
//                   onPressed: () {
//                     if (_isSpeaking) {
//                       _pauseTTS();
//                     } else if (_isPaused) {
//                       _resumeTTS();
//                     } else {
//                       _playTTS();
//                     }
//                   },
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.fast_forward),
//                   onPressed: _fastForward,
//                 ),
//               ],
//             ),
//           ),
//           Center(
//             child: ElevatedButton(
//               onPressed: () {
//                 final ingredientNames = _recipe!['ingredients']
//                     .map<String>((i) => i['name'].toString())
//                     .toList();

//                 final groceryController = Get.find<GroceryController>();
//                 groceryController.addItems(ingredientNames);

//                 Get.snackbar(
//                   "Success",
//                   "Ingredients added to your grocery list",
//                   snackPosition: SnackPosition.BOTTOM,
//                 );
//               },
//               child: const Text("Add to Grocery List"),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }