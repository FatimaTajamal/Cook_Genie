import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeService {
  // 🔥 REPLACE WITH YOUR VERCEL URL
  static const String backendUrl = "https://database-six-kappa.vercel.app";

  final FlutterTts flutterTts = FlutterTts();
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  static final Map<String, Map<String, dynamic>> _recipeCache = {};

  // 🔥 FIRESTORE HELPER: Get Dietary Preferences
  static Future<List<String>> _getDietaryPreferences() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['dietaryPreferences'] ?? []);
      }
    } catch (e) {
      print('Error fetching dietary preferences from Firestore: $e');
    }
    return [];
  }

  // 🔥 FIRESTORE HELPER: Get Allergies
  static Future<List<String>> _getAllergies() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['allergies'] ?? []);
      }
    } catch (e) {
      print('Error fetching allergies from Firestore: $e');
    }
    return [];
  }

  // 🔥 FIRESTORE HELPER: Get Available Ingredients
  static Future<List<String>> _getAvailableIngredients() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['availableIngredients'] ?? []);
      }
    } catch (e) {
      print('Error fetching ingredients from Firestore: $e');
    }
    return [];
  }

  // 🎤 VOICE SEARCH
  Future<void> listenAndSearch(
    Function(String) onQueryRecognized,
    Function(bool) onListeningStateChanged,
  ) async {
    onQueryRecognized("");

    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(Duration(milliseconds: 200));
    }

    bool available = await _speech.initialize();
    if (available) {
      _isListening = true;
      onListeningStateChanged(true);

      _speech.listen(
        onResult: (result) async {
          if (result.finalResult) {
            String spokenText = result.recognizedWords.trim();
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

  // 🔎 RECIPE FETCH (calls your backend)
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
      
      print("🔹 Backend Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final recipe = jsonDecode(response.body);
        _recipeCache[cacheKey] = recipe;
        return recipe;
      } else {
        onError?.call("Failed to fetch recipe. Status Code: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      onError?.call("Error fetching recipe: $e");
      return null;
    }
  }

  // 🔎 FETCH RECIPES BY INGREDIENTS
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
        List<Map<String, dynamic>> recipes = 
            data.map((item) => Map<String, dynamic>.from(item)).toList();
        
        for (var recipe in recipes) {
          _recipeCache[recipe["name"]] = recipe;
        }
        
        return recipes;
      } else {
        onError?.call("Failed to fetch recipes. Status Code: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      onError?.call("Error fetching recipes: $e");
      return [];
    }
  }

 // 📋 GET FULL RECIPES BY CATEGORY
// 📋 GET FULL RECIPES BY CATEGORY
static Future<List<Map<String, dynamic>>> getCategoryRecipes({
  required String category,
  int page = 1,
  int limit = 10,
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
    print("📋 Category body: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // ✅ FIXED: Extract recipes from the nested structure
      final List<dynamic> recipes = decoded['recipes'] ?? [];
      
      // Optional: Handle pagination info if needed
      final pagination = decoded['pagination'];
      if (pagination != null) {
        print("📄 Pagination: Page ${pagination['currentPage']}, Total: ${pagination['totalCount']}, HasMore: ${pagination['hasMore']}");
      }

      // Convert to List<Map<String, dynamic>>
      return recipes
          .map<Map<String, dynamic>>(
              (r) => Map<String, dynamic>.from(r))
          .toList();
    } else {
      print("❌ Failed to fetch category recipes. Status: ${response.statusCode}");
      print("❌ Response: ${response.body}");
    }
  } catch (e) {
    print("❌ Category fetch error: $e");
  }

  return [];
}


  // 💡 RECIPE SUGGESTIONS (for voice search)
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

  // 🔄 GET MULTIPLE RECIPES
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