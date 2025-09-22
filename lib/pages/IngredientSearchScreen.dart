import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'RecipeSearch.dart';
import 'RecipeScreen.dart';
import 'grocery_list_screen.dart';

class IngredientSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes;

  const IngredientSearchScreen({super.key, required this.savedRecipes});

  @override
  _IngredientSearchScreenState createState() => _IngredientSearchScreenState();
}

class _IngredientSearchScreenState extends State<IngredientSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  List<Map<String, dynamic>> _recipes = [];
  List<String> _ingredients = [];
  bool _isLoading = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIngredients();
  }

  Future<void> _loadSavedIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ingredients = prefs.getStringList('availableIngredients') ?? [];
      _controller.text = _ingredients.join(', ');
    });
  }

  Future<void> _saveIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('availableIngredients', _ingredients);
  }

  void _addIngredient(String input) {
    if (input.isNotEmpty) {
      final newIngredients = input.split(',').map((e) => e.trim()).toList();
      setState(() {
        _ingredients = _ingredients = <String>{..._ingredients, ...newIngredients}.toList();
        _controller.text = _ingredients.join(', ');
      });
      _saveIngredients();
    }
  }

  Future<void> _searchRecipes() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter at least one ingredient',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _recipes = [];
    });

    final recipes = await RecipeService.getRecipesByIngredients(
      _ingredients,
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        );
      },
    );

    setState(() {
      _recipes = recipes;
      _isLoading = false;
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
          SnackBar(
            content: Text(
              'Microphone permission denied',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
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

    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) async {
          if (val.finalResult) {
            setState(() {
              _controller.text = val.recognizedWords;
              _isListening = false;
            });
            _addIngredient(val.recognizedWords);
            await _searchRecipes();
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

  void _openRecipe(Map<String, dynamic> recipe) {
    Get.to(
      () => RecipeScreen(
        savedRecipes: widget.savedRecipes,
        initialRecipe: recipe,
      ),
    );
  }

  void _addMissingIngredientsToGroceryList(Map<String, dynamic> recipe) {
    final groceryController = Get.find<GroceryController>();
    final recipeIngredients =
        (recipe['ingredients'] as List?)
            ?.map(
              (i) => {
                'name': i['name'] as String,
                'quantity': i['quantity'] as String? ?? '',
                'category': _inferCategory(i['name'] as String),
                'isPurchased': false,
              },
            )
            .toList() ??
        [];
    final missingIngredients =
        recipeIngredients.where((ingredient) {
          final name = ingredient['name'] as String?;
          return name != null && !_ingredients.contains(name.toLowerCase());
        }).toList();

    if (missingIngredients.isNotEmpty) {
      groceryController.addItems(missingIngredients.cast<String>());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${missingIngredients.map((i) => i['name']).join(', ')} to grocery list',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No missing ingredients to add')),
      );
    }
  }

  String _inferCategory(String ingredient) {
    final lowerCaseIngredient = ingredient.toLowerCase();
    if (['apple', 'banana', 'tomato'].contains(lowerCaseIngredient)) {
      return 'Produce';
    }
    if (['milk', 'cheese', 'yogurt'].contains(lowerCaseIngredient)) {
      return 'Dairy';
    }
    if (['chicken', 'beef'].contains(lowerCaseIngredient)) return 'Meat';
    if (['rice', 'wheat'].contains(lowerCaseIngredient)) return 'Grains';
    return 'Uncategorized';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search by Ingredients'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText:
                          "Enter ingredients (e.g., chicken, rice, tomato)",
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    onSubmitted: (value) {
                      _addIngredient(value);
                      _searchRecipes();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: _isListening ? 70 : 60,
                  height: _isListening ? 70 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _isListening
                            ? Colors.redAccent
                            : Theme.of(context).primaryColor,
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children:
                  _ingredients
                      .map(
                        (ingredient) => Chip(
                          label: Text(
                            ingredient,
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          onDeleted: () {
                            setState(() {
                              _ingredients.remove(ingredient);
                              _controller.text = _ingredients.join(', ');
                            });
                            _saveIngredients();
                          },
                          backgroundColor:
                              Theme.of(context).chipTheme.backgroundColor,
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _searchRecipes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
                foregroundColor: Theme.of(
                  context,
                ).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
              ),
              child: const Text('Search Recipes'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _recipes.isEmpty
                      ? const Center(child: Text('No recipes found.'))
                      : ListView.builder(
                        itemCount: _recipes.length,
                        itemBuilder: (context, index) {
                          final recipe = _recipes[index];
                          return Card(
                            color: Theme.of(context).cardColor,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: ListTile(
                              title: Text(
                                recipe['name'] ?? 'No Title',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              subtitle: Text(
                                (recipe['ingredients'] as List?)
                                        ?.map((i) => i['name'])
                                        .join(', ') ??
                                    '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              onTap: () => _openRecipe(recipe),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_shopping_cart),
                                color: Theme.of(context).iconTheme.color,
                                onPressed:
                                    () => _addMissingIngredientsToGroceryList(
                                      recipe,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
