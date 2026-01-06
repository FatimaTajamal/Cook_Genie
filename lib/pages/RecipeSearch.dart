import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ PAGINATED CATEGORY RESPONSE (used for Load More)
class CategoryRecipesResponse {
  final List<Map<String, dynamic>> recipes;
  final bool hasMore;
  final int currentPage;
  final int totalCount;

  CategoryRecipesResponse({
    required this.recipes,
    required this.hasMore,
    required this.currentPage,
    required this.totalCount,
  });
}

class RecipeService {
  // 🔥 REPLACE WITH YOUR VERCEL URL
  static const String backendUrl = "https://database-six-kappa.vercel.app";

  final FlutterTts flutterTts = FlutterTts();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  static final Map<String, Map<String, dynamic>> _recipeCache = {};

  // -------------------- FIRESTORE HELPERS --------------------

  static Future<List<String>> _getDietaryPreferences() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['dietaryPreferences'] ?? []);
      }
    } catch (e) {
      print('Error fetching dietary preferences from Firestore: $e');
    }
    return [];
  }

  static Future<List<String>> _getAllergies() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['allergies'] ?? []);
      }
    } catch (e) {
      print('Error fetching allergies from Firestore: $e');
    }
    return [];
  }

  static Future<List<String>> _getAvailableIngredients() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['availableIngredients'] ?? []);
      }
    } catch (e) {
      print('Error fetching ingredients from Firestore: $e');
    }
    return [];
  }

  // -------------------- VOICE SEARCH --------------------

  Future<void> listenAndSearch(
    Function(String) onQueryRecognized,
    Function(bool) onListeningStateChanged,
  ) async {
    onQueryRecognized("");

    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    bool available = await _speech.initialize();
    if (available) {
      _isListening = true;
      onListeningStateChanged(true);

      _speech.listen(
        onResult: (result) async {
          if (result.finalResult) {
            final spokenText = result.recognizedWords.trim();
            if (spokenText.isNotEmpty) {
              _isListening = false;
              await _speech.stop();
              onListeningStateChanged(false);
              onQueryRecognized(spokenText);
            }
          }
        },
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        partialResults: false,
      );
    }
  }

  Future<void> speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  // -------------------- RECIPE FETCH --------------------

  static Future<Map<String, dynamic>?> getRecipe(
    String query, {
    Function(String)? onError,
  }) async {
    final List<String> preferences = await _getDietaryPreferences();
    final List<String> allergies = await _getAllergies();

    final String preferenceKey = preferences.join(",").toLowerCase();
    final String cacheKey = "$query|$preferenceKey";

    if (_recipeCache.containsKey(cacheKey)) {
      print("✅ Using cached recipe for: $cacheKey");
      return _recipeCache[cacheKey];
    }

    final Map<String, dynamic> requestData = {
      "query": query,
      "dietaryPreferences": preferences,
      "allergies": allergies,
    };

    try {
      final response = await http.post(
        Uri.parse("$backendUrl/generate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final recipe = jsonDecode(response.body);
        _recipeCache[cacheKey] = Map<String, dynamic>.from(recipe);
        return _recipeCache[cacheKey];
      } else {
        onError?.call(
            "Failed to fetch recipe. Status Code: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      onError?.call("Error fetching recipe: $e");
      return null;
    }
  }

  // -------------------- BY INGREDIENTS --------------------

  static Future<List<Map<String, dynamic>>> getRecipesByIngredients(
    List<String> ingredients, {
    Function(String)? onError,
  }) async {
    final List<String> dietaryPrefs = await _getDietaryPreferences();
    final List<String> allergies = await _getAllergies();

    final Map<String, dynamic> requestData = {
      "ingredients": ingredients,
      "dietaryPreferences": dietaryPrefs,
      "allergies": allergies,
    };

    try {
      final response = await http.post(
        Uri.parse("$backendUrl/by-ingredients"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final recipes = data
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        for (final recipe in recipes) {
          final name = (recipe["name"] ?? "").toString();
          if (name.isNotEmpty) _recipeCache[name] = recipe;
        }

        return recipes;
      } else {
        onError?.call(
            "Failed to fetch recipes. Status Code: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      onError?.call("Error fetching recipes: $e");
      return [];
    }
  }

  // -------------------- CATEGORY (PAGINATED for Load More) --------------------
  // ✅ This is the function your CategoryRecipeScreen should call.
  // ✅ Default limit = 3 (so it loads only 3 initially).
  static Future<CategoryRecipesResponse> getCategoryRecipesPaged({
    required String category,
    int page = 1,
    int limit = 3,
  }) async {
    final List<String> preferences = await _getDietaryPreferences();
    final List<String> allergies = await _getAllergies();

    final Map<String, dynamic> requestData = {
      "category": category,
      "dietaryPreferences": preferences,
      "allergies": allergies,
      "page": page,
      "limit": limit,
    };

    try {
      final response = await http.post(
        Uri.parse("$backendUrl/suggestions-by-category"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      print("📋 Category status: ${response.statusCode}");
      // print("📋 Category body: ${response.body}"); // uncomment if debugging

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // ✅ Your backend returns: { recipes: [...], pagination: {...} }
        final List<dynamic> recipesRaw = decoded['recipes'] ?? [];
        final Map<String, dynamic> pagination =
            Map<String, dynamic>.from(decoded['pagination'] ?? {});

        final recipes = recipesRaw
            .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
            .toList();

        final bool hasMore = (pagination['hasMore'] ?? false) == true;
        final int currentPage = (pagination['currentPage'] ?? page) as int;
        final int totalCount = (pagination['totalCount'] ?? 0) as int;

        // Optional caching by name
        for (final recipe in recipes) {
          final name = (recipe["name"] ?? "").toString();
          if (name.isNotEmpty) _recipeCache[name] = recipe;
        }

        return CategoryRecipesResponse(
          recipes: recipes,
          hasMore: hasMore,
          currentPage: currentPage,
          totalCount: totalCount,
        );
      } else {
        print(
            "❌ Failed to fetch category recipes. Status: ${response.statusCode}");
        print("❌ Response: ${response.body}");
      }
    } catch (e) {
      print("❌ Category fetch error: $e");
    }

    return CategoryRecipesResponse(
      recipes: [],
      hasMore: false,
      currentPage: page,
      totalCount: 0,
    );
  }

  /// ✅ Backward-compatible method (so your old UI code keeps working)
  /// Loads recipes by category with pagination.
  /// Default limit = 3 so you get 3 initially.
  static Future<List<Map<String, dynamic>>> getCategoryRecipes({
    required String category,
    int page = 1,
    int limit = 3,
  }) async {
    final res = await getCategoryRecipesPaged(
      category: category,
      page: page,
      limit: limit,
    );
    return res.recipes;
  }

  // -------------------- SUGGESTIONS (VOICE) --------------------

  static Future<List<String>> getRecipeSuggestions(String query) async {
    final List<String> preferences = await _getDietaryPreferences();

    final Map<String, dynamic> requestData = {
      "query": query,
      "dietaryPreferences": preferences,
    };

    try {
      final response = await http.post(
        Uri.parse("$backendUrl/suggestions"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map<String>((item) => item.toString()).take(4).toList();
      } else {
        return [];
      }
    } catch (e) {
      print("❌ Error fetching suggestions: $e");
      return [];
    }
  }

  // -------------------- MULTIPLE RECIPES --------------------

  static Future<List<Map<String, dynamic>>> getMultipleRecipes(
    List<String> recipeNames,
  ) async {
    final Map<String, dynamic> requestData = {
      "recipeNames": recipeNames,
    };

    try {
      final response = await http.post(
        Uri.parse("$backendUrl/multiple"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print("❌ Error fetching multiple recipes: $e");
      return [];
    }
  }
}