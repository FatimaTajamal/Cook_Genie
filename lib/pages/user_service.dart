import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save user preferences to Firestore
  Future<void> saveUserPreferences({
    required String name,
    required String age,
    required String gender,
    required List<String> dietaryPreferences,
    required List<String> availableIngredients,
    required List<String> allergies,
    String? profileImagePath,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'age': age,
        'gender': gender,
        'dietaryPreferences': dietaryPreferences,
        'availableIngredients': availableIngredients,
        'allergies': allergies,
        'profileImagePath': profileImagePath,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true updates without overwriting other fields
    } catch (e) {
      print('Error saving preferences: $e');
      rethrow;
    }
  }

  // Load user preferences from Firestore
  Future<Map<String, dynamic>?> loadUserPreferences() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error loading preferences: $e');
      return null;
    }
  }

  // Save only dietary preferences (for quick updates)
  Future<void> saveDietaryPreferences(List<String> preferences) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'dietaryPreferences': preferences,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving dietary preferences: $e');
      rethrow;
    }
  }

  // Get only dietary preferences
  Future<List<String>> getDietaryPreferences() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['dietaryPreferences'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting dietary preferences: $e');
      return [];
    }
  }

  // Clear user data from Firestore
  Future<void> clearUserData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      print('Error clearing user data: $e');
      rethrow;
    }
  }

  // Get allergies
  Future<List<String>> getAllergies() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['allergies'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting allergies: $e');
      return [];
    }
  }

  // Get available ingredients
  Future<List<String>> getAvailableIngredients() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['availableIngredients'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting available ingredients: $e');
      return [];
    }
  }
}