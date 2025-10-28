import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreSavedRecipesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  static CollectionReference get _savedRecipesCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(userId).collection('savedRecipes');
  }

  /// Save a recipe to Firestore
  static Future<void> saveRecipe(Map<String, dynamic> recipe) async {
    try {
      final recipeName = recipe['name']?.toString();
      if (recipeName == null || recipeName.isEmpty) {
        print('❌ Recipe name is required');
        return;
      }

      // Use recipe name as document ID (sanitized)
      final docId = _sanitizeDocId(recipeName);

      await _savedRecipesCollection.doc(docId).set({
        ...recipe,
        'savedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Recipe saved to Firestore: $recipeName');
    } catch (e) {
      print('❌ Error saving recipe to Firestore: $e');
      rethrow;
    }
  }

  /// Load all saved recipes from Firestore
  static Future<List<Map<String, dynamic>>> loadAllRecipes() async {
    try {
      final snapshot = await _savedRecipesCollection
          .orderBy('savedAt', descending: true)
          .get();

      final recipes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['firestoreId'] = doc.id; // Add document ID for reference
        return data;
      }).toList();

      print('✅ Loaded ${recipes.length} recipes from Firestore');
      return recipes;
    } catch (e) {
      print('❌ Error loading recipes from Firestore: $e');
      return [];
    }
  }

  /// Remove a recipe from Firestore
  static Future<void> removeRecipe(Map<String, dynamic> recipe) async {
    try {
      final recipeName = recipe['name']?.toString();
      if (recipeName == null || recipeName.isEmpty) {
        print('❌ Recipe name is required');
        return;
      }

      final docId = _sanitizeDocId(recipeName);
      await _savedRecipesCollection.doc(docId).delete();

      print('✅ Recipe removed from Firestore: $recipeName');
    } catch (e) {
      print('❌ Error removing recipe from Firestore: $e');
      rethrow;
    }
  }

  /// Check if a recipe is saved
  static Future<bool> isRecipeSaved(String recipeName) async {
    try {
      final docId = _sanitizeDocId(recipeName);
      final doc = await _savedRecipesCollection.doc(docId).get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking if recipe is saved: $e');
      return false;
    }
  }

  /// Get a single recipe by name
  static Future<Map<String, dynamic>?> getRecipe(String recipeName) async {
    try {
      final docId = _sanitizeDocId(recipeName);
      final doc = await _savedRecipesCollection.doc(docId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['firestoreId'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Error getting recipe from Firestore: $e');
      return null;
    }
  }

  /// Clear all saved recipes for current user
  static Future<void> clearAllRecipes() async {
    try {
      final snapshot = await _savedRecipesCollection.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ Cleared all saved recipes from Firestore');
    } catch (e) {
      print('❌ Error clearing recipes from Firestore: $e');
      rethrow;
    }
  }

  /// Sanitize recipe name to use as document ID
  static String _sanitizeDocId(String name) {
    // Remove special characters and limit length
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .substring(0, name.length > 100 ? 100 : name.length);
  }

  /// Real-time stream of saved recipes
  static Stream<List<Map<String, dynamic>>> streamSavedRecipes() {
    try {
      return _savedRecipesCollection
          .orderBy('savedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['firestoreId'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      print('❌ Error streaming recipes: $e');
      return Stream.value([]);
    }
  }
}