import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeService {
  static const String geminiApiKey = "AIzaSyDh8gND41pOMzHXuSNOohL7s9PBecYinEE";
  static const String geminiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey";

  static const String pixabayApiKey = "51392156-8eaa4d6a677c8e44156c40208";
  static const String pixabayBaseUrl = "https://pixabay.com/api/";

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

  // 🌐 IMAGE FETCH from PIXABAY
  static Future<String> fetchImageUrl(String query) async {
    try {
      // Clean the query
      String simplifiedQuery = query.split(":").first.trim();
      simplifiedQuery = simplifiedQuery.replaceAll(RegExp(r'[&:(),]'), '');
      
      // Limit to 4 words
      List<String> words = simplifiedQuery.split(" ");
      if (words.length > 4) {
        simplifiedQuery = words.sublist(0, 4).join(" ");
      }

      // Add "food" to ensure relevance
      simplifiedQuery = "$simplifiedQuery food";

      // Build request URL with category filter
      final uri = Uri.parse(
        "$pixabayBaseUrl?key=$pixabayApiKey"
        "&q=${Uri.encodeQueryComponent(simplifiedQuery)}"
        "&image_type=photo"
        "&category=food"
        "&safesearch=true"
        "&pretty=true"
      );

      // Make the request
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hits = data["hits"] as List<dynamic>;

        if (hits.isNotEmpty) {
          // Return first image URL
          return hits[0]["webformatURL"] ?? "";
        } else {
          print("❌ No food-related image found for: $simplifiedQuery");
        }
      } else {
        print("❌ Pixabay API error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetching image from Pixabay: $e");
    }

    return ""; // return empty string if nothing found
  }

  // 🔎 RECIPE FETCH
  static Future<Map<String, dynamic>?> getRecipe(
    String query, {
    Function(String)? onError,
  }) async {
    // 🔥 Get dietary preferences from Firestore
    final List<String> preferences = await _getDietaryPreferences();
    final String preferenceKey = preferences.join(",").toLowerCase();
    final String cacheKey = "$query|$preferenceKey";

    if (_recipeCache.containsKey(cacheKey)) {
      print("✅ Using cached recipe for: $cacheKey");
      return _recipeCache[cacheKey];
    }

    String dietaryNote = preferences.isNotEmpty
        ? "Make sure the recipe is suitable for someone with these dietary preferences: ${preferences.join(', ')}."
        : "No specific dietary restrictions.";

    final Map<String, dynamic> requestData = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text":
                  "Give me a **standard and traditional** recipe for '$query' in JSON format **without any code block markers or markdown**. "
                  "$dietaryNote "
                  "Use this structure:\n"
                  "{\n"
                  "  \"name\": \"Recipe Name\",\n"
                  "  \"image_url\": \"Image URL\",\n"
                  "  \"ingredients\": [\n"
                  "    {\"name\": \"ingredient1\", \"quantity\": \"amount\"},\n"
                  "    {\"name\": \"ingredient2\", \"quantity\": \"amount\"}\n"
                  "  ],\n"
                  "  \"instructions\": [\n"
                  "    \"Step 1\",\n"
                  "    \"Step 2\"\n"
                  "  ]\n"
                  "} "
                  "Return valid JSON only."
            }
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(geminiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String content =
            jsonResponse["candidates"][0]["content"]["parts"][0]["text"];
        content =
            content.replaceAll("```json", "").replaceAll("```", "").trim();

        final decoded = jsonDecode(content);
        Map<String, dynamic>? recipe;

        if (decoded is List) {
          recipe = Map<String, dynamic>.from(decoded.first);
        } else if (decoded is Map<String, dynamic>) {
          recipe = Map<String, dynamic>.from(decoded);
        } else {
          print("❌ Unexpected recipe format.");
          return null;
        }

        recipe["name"] ??= query;
        recipe["ingredients"] ??= [];
        recipe["instructions"] ??= [];

        final imageUrl = await fetchImageUrl(query);
        print("✅ Recipe Image URL for '$query': $imageUrl");
        recipe["image_url"] = imageUrl;

        _recipeCache[cacheKey] = recipe;
        return recipe;
      } else {
        onError?.call(
          "Failed to fetch recipe. Status Code: ${response.statusCode}",
        );
        return null;
      }
    } catch (e) {
      onError?.call("Error parsing recipe JSON: $e");
      return null;
    }
  }

  // 🔎 FETCH RECIPES BY INGREDIENTS
  static Future<List<Map<String, dynamic>>> getRecipesByIngredients(
    List<String> ingredients, {
    Function(String)? onError,
  }) async {
    // 🔥 Get dietary preferences and allergies from Firestore
    final List<String> dietaryPrefs = await _getDietaryPreferences();
    final List<String> allergies = await _getAllergies();

    String dietaryPart = dietaryPrefs.isNotEmpty
        ? "suitable for ${dietaryPrefs.join(', ')} diet"
        : "";
    String allergyPart = allergies.isNotEmpty 
        ? "excluding ${allergies.join(', ')}" 
        : "";
    
    String query =
        "recipes using only ${ingredients.join(', ')} $dietaryPart $allergyPart";

    final Map<String, dynamic> requestData = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text":
                  "Suggest 5 traditional recipes using only these ingredients: ${ingredients.join(', ')} $dietaryPart $allergyPart. "
                  "Return a JSON array of recipes in this format without markdown or code block markers: "
                  "[{\"name\": \"Recipe Name\", \"image_url\": \"\", \"ingredients\": [{\"name\": \"ingredient\", \"quantity\": \"amount\"}], \"instructions\": [\"Step 1\", \"Step 2\"]}]",
            },
          ],
        },
      ],
    };

    try {
      final response = await http.post(
        Uri.parse(geminiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String content =
            jsonResponse["candidates"][0]["content"]["parts"][0]["text"];
        content =
            content.replaceAll("```json", "").replaceAll("```", "").trim();
        final decoded = jsonDecode(content);

        if (decoded is List) {
          List<Map<String, dynamic>> recipes =
              decoded.map((item) => Map<String, dynamic>.from(item)).toList();
          for (var recipe in recipes) {
            recipe["image_url"] = await fetchImageUrl(recipe["name"]);
            _recipeCache[recipe["name"]] = recipe;
          }
          return recipes;
        } else {
          onError?.call("Unexpected response format");
          return [];
        }
      } else {
        onError?.call(
          "Failed to fetch recipes. Status Code: ${response.statusCode}",
        );
        return [];
      }
    } catch (e) {
      onError?.call("Error fetching recipes: $e");
      return [];
    }
  }


  static Future<List<String>> getRecipeSuggestionsByCategoryAndPreference({
    required String category,
  }) async {
    // 🔥 Get dietary preferences from Firestore
    final List<String> preferences = await _getDietaryPreferences();

    final now = DateTime.now();
    String today = "${now.year}-${now.month}-${now.day}";
    String timeOfDay = now.hour < 12
        ? "morning"
        : (now.hour < 18 ? "afternoon" : "evening");
    int seed = now.millisecondsSinceEpoch % 1000;

    String dietaryPart = preferences.isNotEmpty
        ? "suitable for someone with the following dietary preferences: ${preferences.join(', ')}"
        : "without any specific dietary restrictions";

    final Map<String, dynamic> requestData = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text":
                  "Suggest 10 traditional and unique $category recipes $dietaryPart. "
                  "Make sure these are ideal for the $timeOfDay of $today. "
                  "Introduce variety using this number: $seed. "
                  "Return only a valid JSON array like [\"Recipe 1\", \"Recipe 2\"]"
            }
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(geminiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String content =
            jsonResponse["candidates"][0]["content"]["parts"][0]["text"];
        content =
            content.replaceAll("```json", "").replaceAll("```", "").trim();
        final decoded = jsonDecode(content);

        if (decoded is List) {
          return decoded.map<String>((item) => item.toString()).toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      print("❌ Error fetching suggestions: $e");
      return [];
    }
  }

  // 💡 RECIPE SUGGESTIONS (used for two-stage voice search)
  static Future<List<String>> getRecipeSuggestions(String query) async {
    // 🔥 Get dietary preferences from Firestore
    final List<String> preferences = await _getDietaryPreferences();
    
    final String dietaryPart = preferences.isNotEmpty
        ? "suitable for someone with the following dietary preferences: ${preferences.join(', ')}"
        : "";

    final Map<String, dynamic> requestData = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text":
                  "The user said '$query'. Suggest 4 specific, popular recipes that contain '$query' $dietaryPart. "
                  "For example, if the query is 'chicken', suggest 'Chicken Tikka Masala'. If the query is 'pasta', suggest 'Spaghetti Carbonara'. "
                  "Return ONLY a valid JSON array of the recipe names, like [\"Recipe 1\", \"Recipe 2\", \"Recipe 3\", \"Recipe 4\"]."
            }
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(geminiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String content =
            jsonResponse["candidates"][0]["content"]["parts"][0]["text"];
        
        // Clean up markdown and extra text
        content =
            content.replaceAll("```json", "").replaceAll("```", "").trim();
        
        final decoded = jsonDecode(content);

        if (decoded is List) {
          // Take the first 4 suggestions to keep the voice response brief
          return decoded
              .map<String>((item) => item.toString())
              .take(4)
              .toList();
        } else {
          // Fallback if Gemini doesn't return a list
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      print("❌ Error fetching suggestions: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMultipleRecipes(
    List<String> recipeNames,
  ) async {
    List<Map<String, dynamic>> recipes = [];

    for (String name in recipeNames) {
      final recipe = await getRecipe(name);
      if (recipe != null) {
        recipes.add(recipe);
      }
    }

    return recipes;
  }
}