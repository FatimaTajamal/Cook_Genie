import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SavedRecipesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes;
  final VoidCallback onBack;

  const SavedRecipesScreen({
    super.key,
    required this.savedRecipes,
    required this.onBack,
  });

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
 List<Map<String, dynamic>> _localSavedRecipes = [];


  @override
 @override
void initState() {
  super.initState();
  _loadSavedRecipes();
}

Future<void> _loadSavedRecipes() async {
  final prefs = await SharedPreferences.getInstance();
  List<String> savedRecipesJson = prefs.getStringList('saved_recipes') ?? [];

  setState(() {
    _localSavedRecipes = savedRecipesJson
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList();
  });
}


void _removeRecipe(int index) async {
  final prefs = await SharedPreferences.getInstance();

  final recipeToRemove = _localSavedRecipes[index];

  setState(() {
    _localSavedRecipes.removeAt(index);
  });

  // Remove from SharedPreferences by matching name
  List<String> savedRecipesJson = prefs.getStringList('saved_recipes') ?? [];

  savedRecipesJson.removeWhere((r) {
    final decoded = json.decode(r);
    return decoded['name'] == recipeToRemove['name'];
  });

  await prefs.setStringList('saved_recipes', savedRecipesJson);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Recipes"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: _localSavedRecipes.isEmpty
          ? const Center(
              child: Text(
                "No saved recipes yet!",
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _localSavedRecipes.length,
              itemBuilder: (context, index) {
                return SavedRecipeCard(
                  recipe: _localSavedRecipes[index],
                  onDelete: () => _removeRecipe(index),
                );
              },
            ),
    );
  }
}

class SavedRecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback onDelete;

  const SavedRecipeCard({
    super.key,
    required this.recipe,
    required this.onDelete,
  });

  @override
  State<SavedRecipeCard> createState() => _SavedRecipeCardState();
}

class _SavedRecipeCardState extends State<SavedRecipeCard> {
  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  bool _isPaused = false;
  int _currentPosition = 0;
  late String _fullText;
  final int _skipWords = 5;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _configureTts();
    _buildTextToSpeak();
  }

  void _configureTts() {
    _flutterTts.setLanguage('en-US');
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      setState(() {
        _currentPosition = start;
      });
    });

    _flutterTts.setCompletionHandler(() {
  if (mounted) {
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _currentPosition = 0;
    });
  }
});


    _flutterTts.setCancelHandler(() {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _currentPosition = 0;
      });
    });

    _flutterTts.setPauseHandler(() {
      setState(() {
        _isPlaying = false;
        _isPaused = true;
      });
    });

    _flutterTts.setContinueHandler(() {
      setState(() {
        _isPlaying = true;
        _isPaused = false;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _currentPosition = 0;
      });
    });
  }

  void _buildTextToSpeak() {
    String text = widget.recipe['name'] + '. ';
    if (widget.recipe['ingredients'] != null && widget.recipe['ingredients'].isNotEmpty) {
      text += 'Ingredients: ';
      text += widget.recipe['ingredients']
          .map<String>((i) => '${i['name']} ${i['quantity']}')
          .join(', ') + '. ';
    }
    if (widget.recipe['instructions'] != null && widget.recipe['instructions'].isNotEmpty) {
      text += 'Instructions: ';
      for (int i = 0; i < widget.recipe['instructions'].length; i++) {
        text += 'Step ${i + 1}: ${widget.recipe['instructions'][i]}. ';
      }
    }
    _fullText = text;
  }

  Future<void> _play() async {
    if (_isPaused) {
      await _flutterTts.speak(_fullText.substring(_currentPosition));
    } else {
      await _flutterTts.speak(_fullText);
    }
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
  }

  Future<void> _pause() async {
    await _flutterTts.pause();
    setState(() {
      _isPlaying = false;
      _isPaused = true;
    });
  }

  Future<void> _rewind() async {
    List<String> words = _fullText.split(' ');
    int currentWordIndex = 0;
    int count = 0;
    for (int i = 0; i < words.length; i++) {
      if (count >= _currentPosition) {
        currentWordIndex = i;
        break;
      }
      count += words[i].length + 1;
    }
    int newWordIndex = (currentWordIndex - _skipWords).clamp(0, words.length - 1);
    int newCharPos = 0;
    for (int i = 0; i < newWordIndex; i++) {
      newCharPos += words[i].length + 1;
    }
    await _flutterTts.stop();
    setState(() {
      _currentPosition = newCharPos;
    });
    await _flutterTts.speak(_fullText.substring(_currentPosition));
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
  }

  Future<void> _forward() async {
    List<String> words = _fullText.split(' ');
    int currentWordIndex = 0;
    int count = 0;
    for (int i = 0; i < words.length; i++) {
      if (count >= _currentPosition) {
        currentWordIndex = i;
        break;
      }
      count += words[i].length + 1;
    }
    int newWordIndex = (currentWordIndex + _skipWords).clamp(0, words.length - 1);
    int newCharPos = 0;
    for (int i = 0; i < newWordIndex; i++) {
      newCharPos += words[i].length + 1;
    }
    await _flutterTts.stop();
    setState(() {
      _currentPosition = newCharPos;
    });
    await _flutterTts.speak(_fullText.substring(_currentPosition));
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and delete
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.recipe['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.recipe['ingredients'] != null && widget.recipe['ingredients'].isNotEmpty) ...[
              const Text(
                "Ingredients:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              ...widget.recipe['ingredients']
                  .map<Widget>((i) => Text("- ${i['name']} (${i['quantity']})"))
                  .toList(),
              const SizedBox(height: 12),
            ],
            if (widget.recipe['instructions'] != null && widget.recipe['instructions'].isNotEmpty) ...[
              const Text(
                "Instructions:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              ...widget.recipe['instructions']
                  .map<Widget>((step) => Text("• $step"))
                  .toList(),
              const SizedBox(height: 12),
            ],
            // Playback Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, size: 28),
                  onPressed: _rewind,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                  ),
                  onPressed: _isPlaying ? _pause : _play,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.forward_10, size: 28),
                  onPressed: _forward,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}






// import 'package:flutter/material.dart';
// import 'package:flutter_tts/flutter_tts.dart';

// class SavedRecipesScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> savedRecipes;
//   final VoidCallback onBack;

//   const SavedRecipesScreen({
//     super.key,
//     required this.savedRecipes,
//     required this.onBack,
//   });

//   @override
//   State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
// }

// class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
//   late List<Map<String, dynamic>> _localSavedRecipes;

//   @override
//   void initState() {
//     super.initState();
//     _localSavedRecipes = List.from(widget.savedRecipes);
//   }

//   void _removeRecipe(int index) {
//     setState(() {
//       _localSavedRecipes.removeAt(index);
//       widget.savedRecipes.removeAt(index);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Saved Recipes"),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: widget.onBack,
//         ),
//       ),
//       body: _localSavedRecipes.isEmpty
//           ? const Center(
//               child: Text(
//                 "No saved recipes yet!",
//                 style: TextStyle(fontSize: 18),
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: _localSavedRecipes.length,
//               itemBuilder: (context, index) {
//                 return SavedRecipeCard(
//                   recipe: _localSavedRecipes[index],
//                   onDelete: () => _removeRecipe(index),
//                 );
//               },
//             ),
//     );
//   }
// }

// class SavedRecipeCard extends StatefulWidget {
//   final Map<String, dynamic> recipe;
//   final VoidCallback onDelete;

//   const SavedRecipeCard({
//     super.key,
//     required this.recipe,
//     required this.onDelete,
//   });

//   @override
//   State<SavedRecipeCard> createState() => _SavedRecipeCardState();
// }

// class _SavedRecipeCardState extends State<SavedRecipeCard> {
//   late FlutterTts _flutterTts;
//   bool _isPlaying = false;
//   bool _isPaused = false;
//   int _currentPosition = 0;
//   late String _fullText;
//   final int _skipWords = 5;

//   @override
//   void initState() {
//     super.initState();
//     _flutterTts = FlutterTts();
//     _configureTts();
//     _buildTextToSpeak();
//   }

//   void _configureTts() {
//     _flutterTts.setLanguage('en-US');
//     _flutterTts.setSpeechRate(0.5);
//     _flutterTts.setVolume(1.0);
//     _flutterTts.setPitch(1.0);

//     _flutterTts.setProgressHandler((String text, int start, int end, String word) {
//       setState(() {
//         _currentPosition = start;
//       });
//     });

//     _flutterTts.setCompletionHandler(() {
//   if (mounted) {
//     setState(() {
//       _isPlaying = false;
//       _isPaused = false;
//       _currentPosition = 0;
//     });
//   }
// });


//     _flutterTts.setCancelHandler(() {
//       setState(() {
//         _isPlaying = false;
//         _isPaused = false;
//         _currentPosition = 0;
//       });
//     });

//     _flutterTts.setPauseHandler(() {
//       setState(() {
//         _isPlaying = false;
//         _isPaused = true;
//       });
//     });

//     _flutterTts.setContinueHandler(() {
//       setState(() {
//         _isPlaying = true;
//         _isPaused = false;
//       });
//     });

//     _flutterTts.setErrorHandler((msg) {
//       setState(() {
//         _isPlaying = false;
//         _isPaused = false;
//         _currentPosition = 0;
//       });
//     });
//   }

//   void _buildTextToSpeak() {
//     String text = widget.recipe['name'] + '. ';
//     if (widget.recipe['ingredients'] != null && widget.recipe['ingredients'].isNotEmpty) {
//       text += 'Ingredients: ';
//       text += widget.recipe['ingredients']
//           .map<String>((i) => '${i['name']} ${i['quantity']}')
//           .join(', ') + '. ';
//     }
//     if (widget.recipe['instructions'] != null && widget.recipe['instructions'].isNotEmpty) {
//       text += 'Instructions: ';
//       for (int i = 0; i < widget.recipe['instructions'].length; i++) {
//         text += 'Step ${i + 1}: ${widget.recipe['instructions'][i]}. ';
//       }
//     }
//     _fullText = text;
//   }

//   Future<void> _play() async {
//     if (_isPaused) {
//       await _flutterTts.speak(_fullText.substring(_currentPosition));
//     } else {
//       await _flutterTts.speak(_fullText);
//     }
//     setState(() {
//       _isPlaying = true;
//       _isPaused = false;
//     });
//   }

//   Future<void> _pause() async {
//     await _flutterTts.pause();
//     setState(() {
//       _isPlaying = false;
//       _isPaused = true;
//     });
//   }

//   Future<void> _rewind() async {
//     List<String> words = _fullText.split(' ');
//     int currentWordIndex = 0;
//     int count = 0;
//     for (int i = 0; i < words.length; i++) {
//       if (count >= _currentPosition) {
//         currentWordIndex = i;
//         break;
//       }
//       count += words[i].length + 1;
//     }
//     int newWordIndex = (currentWordIndex - _skipWords).clamp(0, words.length - 1);
//     int newCharPos = 0;
//     for (int i = 0; i < newWordIndex; i++) {
//       newCharPos += words[i].length + 1;
//     }
//     await _flutterTts.stop();
//     setState(() {
//       _currentPosition = newCharPos;
//     });
//     await _flutterTts.speak(_fullText.substring(_currentPosition));
//     setState(() {
//       _isPlaying = true;
//       _isPaused = false;
//     });
//   }

//   Future<void> _forward() async {
//     List<String> words = _fullText.split(' ');
//     int currentWordIndex = 0;
//     int count = 0;
//     for (int i = 0; i < words.length; i++) {
//       if (count >= _currentPosition) {
//         currentWordIndex = i;
//         break;
//       }
//       count += words[i].length + 1;
//     }
//     int newWordIndex = (currentWordIndex + _skipWords).clamp(0, words.length - 1);
//     int newCharPos = 0;
//     for (int i = 0; i < newWordIndex; i++) {
//       newCharPos += words[i].length + 1;
//     }
//     await _flutterTts.stop();
//     setState(() {
//       _currentPosition = newCharPos;
//     });
//     await _flutterTts.speak(_fullText.substring(_currentPosition));
//     setState(() {
//       _isPlaying = true;
//       _isPaused = false;
//     });
//   }

//   @override
//   void dispose() {
//     _flutterTts.stop();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 4,
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Title and delete
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Expanded(
//                   child: Text(
//                     widget.recipe['name'],
//                     style: const TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.delete, color: Colors.red),
//                   onPressed: widget.onDelete,
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             if (widget.recipe['ingredients'] != null && widget.recipe['ingredients'].isNotEmpty) ...[
//               const Text(
//                 "Ingredients:",
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//               ),
//               const SizedBox(height: 4),
//               ...widget.recipe['ingredients']
//                   .map<Widget>((i) => Text("- ${i['name']} (${i['quantity']})"))
//                   .toList(),
//               const SizedBox(height: 12),
//             ],
//             if (widget.recipe['instructions'] != null && widget.recipe['instructions'].isNotEmpty) ...[
//               const Text(
//                 "Instructions:",
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//               ),
//               const SizedBox(height: 4),
//               ...widget.recipe['instructions']
//                   .map<Widget>((step) => Text("• $step"))
//                   .toList(),
//               const SizedBox(height: 12),
//             ],
//             // Playback Controls
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.replay_10, size: 28),
//                   onPressed: _rewind,
//                 ),
//                 const SizedBox(width: 16),
//                 IconButton(
//                   icon: Icon(
//                     _isPlaying ? Icons.pause : Icons.play_arrow,
//                     size: 36,
//                   ),
//                   onPressed: _isPlaying ? _pause : _play,
//                 ),
//                 const SizedBox(width: 16),
//                 IconButton(
//                   icon: const Icon(Icons.forward_10, size: 28),
//                   onPressed: _forward,
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }