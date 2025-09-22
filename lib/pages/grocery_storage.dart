import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GroceryStorage {
  static const String _key = 'grocery_items';

  Future<List<String>> getIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> addIngredients(List<String> newItems) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? [];
    final updated = {...current, ...newItems}.toList(); // remove duplicates
    await prefs.setStringList(_key, updated);
  }

  Future<void> clearIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> overwriteIngredients(List<String> encodedItems) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, encodedItems);
  }

  static Future<List<Map<String, dynamic>>> loadIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final storedItems = prefs.getStringList(_key) ?? [];
    return storedItems
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();
  }
}
