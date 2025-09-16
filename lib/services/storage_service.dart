import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keySavedRecipes = 'saved_recipes';
  static const String _fileName = 'saved_recipes.json';

  /// Save recipes to local storage or SharedPreferences (for Web)
  static Future<void> saveRecipes(List<Map<String, dynamic>> recipes) async {
    final recipesJson = json.encode(recipes);

    if (kIsWeb) {
      // Use SharedPreferences on Web
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySavedRecipes, recipesJson);
    } else {
      // Save to file on mobile/desktop
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsString(recipesJson);
    }
  }

  /// Load recipes from local storage or SharedPreferences (for Web)
  static Future<List<Map<String, dynamic>>> loadSavedRecipes() async {
    try {
      String? recipesJson;

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        recipesJson = prefs.getString(_keySavedRecipes);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_fileName');
        if (await file.exists()) {
          recipesJson = await file.readAsString();
        }
      }

      if (recipesJson != null) {
        final List<dynamic> recipesList = json.decode(recipesJson);
        return recipesList.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('Error loading recipes: $e');
    }

    return [];
  }

  /// Clear saved recipes
  static Future<void> clearSavedRecipes() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySavedRecipes);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}



// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';

// class StorageService {
//   static const String _keySavedRecipes = 'saved_recipes';

//   // Save recipes to SharedPreferences
//   static Future<void> saveRecipes(List<Map<String, dynamic>> recipes) async {
//     final prefs = await SharedPreferences.getInstance();
//     final recipesJson = json.encode(recipes);
//     await prefs.setString(_keySavedRecipes, recipesJson);
//   }

//   // Load recipes from SharedPreferences
//   static Future<List<Map<String, dynamic>>> loadSavedRecipes() async {
//     final prefs = await SharedPreferences.getInstance();
//     final recipesJson = prefs.getString(_keySavedRecipes);
//     if (recipesJson != null) {
//       final List<dynamic> recipesList = json.decode(recipesJson);
//       return recipesList.map((e) => Map<String, dynamic>.from(e)).toList();
//     }
//     return [];
//   }

//   // Clear saved recipes (optional)
//   static Future<void> clearSavedRecipes() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_keySavedRecipes);
//   }
// }
