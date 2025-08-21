import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'RecipeSearch.dart';
import 'grocery_list_screen.dart';

class RecipeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes;
  final Map<String, dynamic>? initialRecipe;

  const RecipeScreen({
    super.key,
    required this.savedRecipes,
    this.initialRecipe,
  });

  @override
  _RecipeScreenState createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  late stt.SpeechToText _speech;

  bool _isSpeaking = false;
  bool _isListening = false;
  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isFavorite = false;

  String _ttsText = "";
  final double _speechRate = 0.5;
  int _currentTextIndex = 0;
  List<String> _formattedTextParts = [];

  Map<String, dynamic>? _recipe;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts.setVolume(1.0);
    _tts.setSpeechRate(_speechRate);
    _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });

    if (widget.initialRecipe != null) {
      _recipe = widget.initialRecipe;
      _hasSearched = true;
      _ttsText = _formatRecipe(_recipe!);
      _formattedTextParts = _ttsText.split(RegExp(r'(?<=[.!?])\s+'));
      _currentTextIndex = 0;
      _isFavorite = widget.savedRecipes.any(
        (r) => r['name'] == _recipe!['name'],
      );
    }
  }

  @override
  void dispose() {
    _tts.stop();
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
        _formattedTextParts = _ttsText.split(RegExp(r'(?<=[.!?])\s+'));
        _currentTextIndex = 0;
        _isLoading = false;
      });
    } else {
      setState(() {
        _recipe = null;
        _ttsText = "";
        _formattedTextParts.clear();
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

  void _playTTS() {
    if (_currentTextIndex < _formattedTextParts.length) {
      final textToRead = _formattedTextParts
          .sublist(_currentTextIndex)
          .join(' ');
      _tts.speak(textToRead);
      setState(() => _isSpeaking = true);
    }
  }

  void _pauseTTS() {
    _tts.stop();
    setState(() => _isSpeaking = false);
  }

  void _rewind() {
    if (_currentTextIndex > 0) {
      _currentTextIndex--;
      _tts.stop().then((_) => _playTTS());
    }
  }

  void _fastForward() {
    if (_currentTextIndex < _formattedTextParts.length - 1) {
      _currentTextIndex++;
      _tts.stop().then((_) => _playTTS());
    }
  }

  void _toggleFavorite() {
    if (_recipe == null) return;

    final ingredientNames =
        _recipe!['ingredients']
            .map<String>((i) => i['name'].toString())
            .toList();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Cook Genie')),
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
                      boxShadow:
                          _isListening
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
            Expanded(
              child:
                  _hasSearched
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
                  color: _isFavorite ? Color.fromARGB(255, 168, 85, 236) : null,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ✅ Updated to check for 'image_url' instead of 'image'
          if (_recipe!['image_url'] != null &&
              _recipe!['image_url'].toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _recipe!['image_url'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) =>
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
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.fast_rewind),
                  onPressed: _rewind,
                ),
                IconButton(
                  icon: Icon(_isSpeaking ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    _isSpeaking ? _pauseTTS() : _playTTS();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.fast_forward),
                  onPressed: _fastForward,
                ),
              ],
            ),
          ),
          Center(
            child: ElevatedButton(
              onPressed: () {
                final ingredientNames =
                    _recipe!['ingredients']
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
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:permission_handler/permission_handler.dart';
// import 'RecipeSearch.dart';
// import 'saved_recipes_screen.dart';

// class RecipeScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> savedRecipes;
//   final Map<String, dynamic>? initialRecipe; // NEW

//   const RecipeScreen({
//     Key? key,
//     required this.savedRecipes,
//     this.initialRecipe,
//   }) : super(key: key);

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

//   String _ttsText = "";
//   double _speechRate = 0.5;
//   int _currentTextIndex = 0;
//   List<String> _formattedTextParts = [];

//   Map<String, dynamic>? _recipe;

//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _tts.setVolume(1.0);
//     _tts.setSpeechRate(_speechRate);
//     _tts.setPitch(1.0);
//     _tts.setCompletionHandler(() {
//       setState(() => _isSpeaking = false);
//     });

//     // NEW: Preload recipe if passed from category tap
//     if (widget.initialRecipe != null) {
//       _recipe = widget.initialRecipe;
//       _hasSearched = true;
//       _ttsText = _formatRecipe(_recipe!);
//       _formattedTextParts = _ttsText.split(RegExp(r'(?<=[.!?])\s+'));
//       _currentTextIndex = 0;
//       _isFavorite = widget.savedRecipes.any((r) => r['name'] == _recipe!['name']);
//     }
//   }

//   @override
//   void dispose() {
//     _tts.stop();
//     _controller.dispose();
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
//         _isFavorite = widget.savedRecipes.any((r) => r['name'] == recipe['name']);
//         _ttsText = _formatRecipe(recipe);
//         _formattedTextParts = _ttsText.split(RegExp(r'(?<=[.!?])\s+'));
//         _currentTextIndex = 0;
//         _isLoading = false;
//       });
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
//     setState(() => _isSpeaking = false);
//   }

//   void _rewind() {
//     if (_currentTextIndex > 0) {
//       _currentTextIndex--;
//       _tts.stop().then((_) => _playTTS());
//     }
//   }

//   void _fastForward() {
//     if (_currentTextIndex < _formattedTextParts.length - 1) {
//       _currentTextIndex++;
//       _tts.stop().then((_) => _playTTS());
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
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Cook Genie'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             if (widget.initialRecipe == null)
//   Row(
//     children: [
//       Expanded(
//         child: TextField(
//           controller: _controller,
//           decoration: const InputDecoration(
//             labelText: "Enter recipe name",
//             border: OutlineInputBorder(),
//           ),
//           onSubmitted: _searchRecipe,
//         ),
//       ),
//       const SizedBox(width: 10),
//       AnimatedContainer(
//         duration: const Duration(milliseconds: 500),
//         width: _isListening ? 70 : 60,
//         height: _isListening ? 70 : 60,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: _isListening ? Colors.redAccent : Colors.blue,
//           boxShadow: _isListening
//               ? [
//                   BoxShadow(
//                     color: Colors.redAccent.withOpacity(0.6),
//                     spreadRadius: 8,
//                     blurRadius: 12,
//                   )
//                 ]
//               : [],
//         ),
//         child: GestureDetector(
//           onTap: _listen,
//           child: Icon(
//             _isListening ? Icons.mic : Icons.mic_none,
//             color: Colors.white,
//             size: 30,
//           ),
//         ),
//       ),
//     ],
//   ),

//             const SizedBox(height: 16),
//             Expanded(
//               child: _hasSearched
//                   ? _isLoading
//                       ? const Center(child: CircularProgressIndicator())
//                       : _recipe != null
//                           ? _buildRecipeDetails()
//                           : const Center(child: Text('No recipe found.'))
//                   : const Center(child: Text('Search for a recipe to begin.')),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRecipeDetails() {
//   return SingleChildScrollView(
//     padding: const EdgeInsets.only(bottom: 24), // Add extra bottom padding
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Expanded(
//               child: Text(
//                 'Recipe: ${_recipe!['name']}',
//                 style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//             IconButton(
//               icon: Icon(
//                 _isFavorite ? Icons.favorite : Icons.favorite_border,
//                 color: _isFavorite ? Colors.red : null,
//               ),
//               onPressed: _toggleFavorite,
//             ),
//           ],
//         ),

//         const SizedBox(height: 10),

//         // ✅ Show recipe image if available
//         if (_recipe!['image'] != null && _recipe!['image'].toString().isNotEmpty)
//           ClipRRect(
//             borderRadius: BorderRadius.circular(12),
//             child: Image.network(
//               _recipe!['image'],
//               height: 200,
//               width: double.infinity,
//               fit: BoxFit.cover,
//               errorBuilder: (context, error, stackTrace) => const Text('⚠️ Image failed to load'),
//             ),
//           ),

//         const SizedBox(height: 10),

//         const Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
//         ..._recipe!['ingredients'].map<Widget>((i) {
//           return Padding(
//             padding: const EdgeInsets.symmetric(vertical: 2),
//             child: Text(
//               '${i['name']} - ${i['quantity']}',
//               style: const TextStyle(fontSize: 16),
//               softWrap: true,
//             ),
//           );
//         }).toList(),

//         const SizedBox(height: 10),

//         const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
//         ..._recipe!['instructions'].map<Widget>((s) {
//           return Padding(
//             padding: const EdgeInsets.symmetric(vertical: 2),
//             child: Text(
//               s,
//               style: const TextStyle(fontSize: 16),
//               softWrap: true,
//             ),
//           );
//         }).toList(),

//         const SizedBox(height: 20),

//         Center(
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(icon: const Icon(Icons.fast_rewind), onPressed: _rewind),
//               IconButton(
//                 icon: Icon(_isSpeaking ? Icons.pause : Icons.play_arrow),
//                 onPressed: () {
//                   _isSpeaking ? _pauseTTS() : _playTTS();
//                 },
//               ),
//               IconButton(icon: const Icon(Icons.fast_forward), onPressed: _fastForward),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
// }
// }
