import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe; // Accept full recipe
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool isFavorite = false;

  String get recipeTitle => widget.recipe['name'];

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedRecipesJson = prefs.getStringList('saved_recipes') ?? [];

    setState(() {
      isFavorite = savedRecipesJson.any((r) {
        final decoded = jsonDecode(r);
        return decoded['name'] == recipeTitle;
      });
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedRecipesJson = prefs.getStringList('saved_recipes') ?? [];

    if (isFavorite) {
      savedRecipesJson.removeWhere((r) {
        final decoded = jsonDecode(r);
        return decoded['name'] == recipeTitle;
      });
    } else {
      savedRecipesJson.add(jsonEncode(widget.recipe));
    }

    await prefs.setStringList('saved_recipes', savedRecipesJson);

    setState(() {
      isFavorite = !isFavorite;
    });

    final snackBar = SnackBar(
      content: Text(
        isFavorite ? "Added to Favorites ❤️" : "Removed from Favorites 💔",
      ),
      duration: const Duration(seconds: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipeTitle),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Text(
              recipeTitle,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Text("Recipe Details"), // You can expand this to show full recipe
        ],
      ),
    );
  }
}
