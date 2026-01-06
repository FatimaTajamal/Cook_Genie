import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'RecipeSearch.dart';
import 'RecipeScreen.dart';
import 'grocery_list_screen.dart';
import 'user_service.dart';

class IngredientSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes;

  const IngredientSearchScreen({Key? key, required this.savedRecipes}) : super(key: key);

  @override
  State<IngredientSearchScreen> createState() => _IngredientSearchScreenState();
}

class _IngredientSearchScreenState extends State<IngredientSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final UserService _userService = UserService();

  List<Map<String, dynamic>> _recipes = [];
  List<String> _ingredients = [];
  bool _isLoading = false;
  bool _isListening = false;

  // Theme constants
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

  @override
  void initState() {
    super.initState();
    _loadSavedIngredients();
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _loadSavedIngredients() async {
    try {
      final ingredients = await _userService.getAvailableIngredients();
      if (!mounted) return;
      setState(() {
        _ingredients = ingredients;
        _controller.text = _ingredients.join(', ');
      });
    } catch (e) {
      debugPrint('❌ Error loading ingredients: $e');
    }
  }

  Future<void> _saveIngredients() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'availableIngredients': _ingredients,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error saving ingredients: $e');
    }
  }

  void _addIngredient(String input) {
  if (input.isEmpty) return;

  final newIngredients = input
      .split(',')
      .map((e) => e.trim().toLowerCase()) // ✅ Normalize to lowercase
      .where((e) => e.isNotEmpty)
      .toList();

  if (!mounted) return;
  setState(() {
    // ✅ Use Set to avoid duplicates and normalize all ingredients
    _ingredients = <String>{
      ..._ingredients.map((e) => e.toLowerCase()),
      ...newIngredients
    }.toList();
    _controller.text = _ingredients.join(', ');
  });

  _saveIngredients();
}

// ✅ Add a method to update ingredients from text field without duplicating
void _syncIngredientsFromTextField() {
  final text = _controller.text.trim();
  if (text.isEmpty) return;

  final parsed = text
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  if (!mounted) return;
  setState(() {
    _ingredients = parsed;
  });
}

Future<void> _searchRecipes() async {
  // ✅ Sync ingredients from text field before searching
  _syncIngredientsFromTextField();

  if (_ingredients.isEmpty) {
    _showSnack('Please enter at least one ingredient');
    return;
  }

  debugPrint('🔍 Searching with ingredients: $_ingredients'); // ✅ Debug log

  if (!mounted) return;
  setState(() {
    _isLoading = true;
    _recipes = [];
  });

  try {
    final recipes = await RecipeService.getRecipesByIngredients(
      _ingredients,
      onError: (error) {
        if (mounted) _showSnack(error);
      },
    );

    debugPrint('✅ Received ${recipes.length} recipes');
    if (recipes.isNotEmpty) {
      debugPrint('📋 First recipe: ${recipes[0]['name']}');
    }
    
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });
  } catch (e) {
    debugPrint('❌ Error in _searchRecipes: $e');
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }
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
        _showSnack('Microphone permission denied');
        return;
      }
    }

    _startListening();
  }

  void _startListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available) return;

    if (!mounted) return;
    setState(() => _isListening = true);

    _speech.listen(
      onResult: (val) async {
        if (!mounted) return;

        if (val.finalResult) {
          if (!mounted) return;
          setState(() {
            _controller.text = val.recognizedWords;
            _isListening = false;
          });
          _addIngredient(val.recognizedWords);
          await _searchRecipes();
        } else {
          if (!mounted) return;
          setState(() {
            _controller.text = val.recognizedWords;
          });
        }
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _openRecipe(Map<String, dynamic> recipe) {
    Get.to(() => RecipeScreen(
          savedRecipes: widget.savedRecipes,
          initialRecipe: recipe,
        ));
  }

  void _addMissingIngredientsToGroceryList(Map<String, dynamic> recipe) {
    try {
      final groceryController = Get.find<GroceryController>();

      final recipeIngredients = (recipe['ingredients'] as List?)
              ?.map((i) {
                final name = (i is Map ? i['name'] : null)?.toString() ?? '';
                final qty = (i is Map ? i['quantity'] : null)?.toString() ?? '';
                return {
                  'name': name,
                  'quantity': qty,
                  'category': _inferCategory(name),
                  'isPurchased': false,
                };
              })
              .where((m) => (m['name'] as String).trim().isNotEmpty)
              .toList() ??
          [];

      final userHave = _ingredients.map((e) => e.toLowerCase().trim()).toSet();

      final missing = recipeIngredients.where((ing) {
        final name = (ing['name'] as String).toLowerCase().trim();
        return name.isNotEmpty && !userHave.contains(name);
      }).toList();

      if (missing.isEmpty) {
        _showSnack('No missing ingredients to add');
        return;
      }

      final List<String> names =
          missing.map((i) => (i['name'] ?? '').toString()).toList();

      groceryController.addItems(names);
      _showSnack('Added ${names.join(', ')} to grocery list');
    } catch (e) {
      _showSnack('Error adding to grocery list');
      debugPrint('❌ Error: $e');
    }
  }

  String _inferCategory(String ingredient) {
    final lower = ingredient.toLowerCase();
    if (['apple', 'banana', 'tomato'].contains(lower)) return 'Produce';
    if (['milk', 'cheese', 'yogurt'].contains(lower)) return 'Dairy';
    if (['chicken', 'beef'].contains(lower)) return 'Meat';
    if (['rice', 'wheat'].contains(lower)) return 'Grains';
    return 'Uncategorized';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: const Color(0xFF120A22),
        elevation: 0,
        title: const Text(
          'Search by Ingredients',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _bgGradient(),
          _bgStars(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 14),
                      _inputRow(),
                      const SizedBox(height: 10),
                      _chipsWrapScrollable(),
                      const SizedBox(height: 12),
                      _searchButton(),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildResultsSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return Center(child: _emptyState());
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        final name = (recipe['name'] ?? 'No Title').toString();
        final ingredientsText = (recipe['ingredients'] as List?)
                ?.map((i) => (i is Map ? i['name'] : i).toString())
                .where((s) => s.trim().isNotEmpty)
                .take(8)
                .join(', ') ??
            '';
        return _recipeCard(recipe, name, ingredientsText);
      },
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              _accent2.withOpacity(0.16),
              const Color(0xFF2A1246).withOpacity(0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 54, color: _accent),
            const SizedBox(height: 10),
            Text(
              'No recipes found.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adding more ingredients or simplify your list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Stack(
      children: [
        Positioned(
          left: -4,
          top: 6,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(0.08),
            size: 44,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Find recipes fast",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Type ingredients or use the mic. We'll match recipes you can cook.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inputRow() {
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
                  color: _accent.withOpacity(0.18),
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
                hintText: "chicken, rice, tomato...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onSubmitted: (value) {
                _addIngredient(value);
                _searchRecipes();
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: _isListening ? 66 : 58,
          height: _isListening ? 66 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isListening ? Colors.redAccent : _accent,
            boxShadow: _isListening
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
            onTap: _listen,
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipsWrapScrollable() {
    if (_ingredients.isEmpty) {
      return Text(
        "Your ingredients will appear here as chips.",
        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12.5),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 120),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ingredients.map((ingredient) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    _accent2.withOpacity(0.14),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ingredient,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _ingredients.remove(ingredient);
                          _controller.text = _ingredients.join(', ');
                        });
                        _saveIngredients();
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.70),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

 Widget _searchButton() {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: _isLoading ? null : () {
        // ✅ First, parse and add any new ingredients from text field
        _addIngredient(_controller.text);
        // ✅ Then search
        _searchRecipes();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _accent.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: const Text(
        'Search Recipes',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.2),
      ),
    ),
  );
}
  Widget _recipeCard(Map<String, dynamic> recipe, String name, String ingredientsText) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openRecipe(recipe),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              _accent2.withOpacity(0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: const Icon(Icons.restaurant_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ingredientsText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_shopping_cart_rounded),
              color: Colors.white.withOpacity(0.85),
              onPressed: () => _addMissingIngredientsToGroceryList(recipe),
              tooltip: 'Add missing to grocery',
            ),
          ],
        ),
      ),
    );
  }

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