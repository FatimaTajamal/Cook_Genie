import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedRecipesService {
  static const String _prefsKey = 'saved_recipes_v1';

  static Future<List<Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? <String>[];
    return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> _saveAll(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = items.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_prefsKey, encoded);
  }

  static String _id(Map<String, dynamic> recipe) {
    final n = recipe['name'];
    if (n is String && n.isNotEmpty) return n;
    return jsonEncode(recipe);
  }

  static Future<bool> isSaved(Map<String, dynamic> recipe) async {
    final all = await loadAll();
    final id = _id(recipe);
    return all.any((r) => _id(r) == id);
  }

  static Future<void> add(Map<String, dynamic> recipe) async {
    final all = await loadAll();
    final id = _id(recipe);
    if (!all.any((r) => _id(r) == id)) {
      all.add(recipe);
      await _saveAll(all);
    }
  }

  static Future<void> remove(Map<String, dynamic> recipe) async {
    final all = await loadAll();
    final id = _id(recipe);
    all.removeWhere((r) => _id(r) == id);
    await _saveAll(all);
  }

  static Future<bool> toggle(Map<String, dynamic> recipe) async {
    final saved = await isSaved(recipe);
    if (saved) {
      await remove(recipe);
      return false;
    } else {
      await add(recipe);
      return true;
    }
  }
}