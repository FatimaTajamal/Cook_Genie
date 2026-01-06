import 'package:firebase_auth/firebase_auth.dart';
import '../../global/toast.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showToast(message: 'The email address is already in use.');
      } else if (e.code == 'invalid-email') {
        showToast(message: 'Please enter a valid email address.');
      } else if (e.code == 'weak-password') {
        showToast(message: 'Password is too weak (min 6 characters).');
      } else {
        showToast(message: 'An error occurred: ${e.code}');
      }
    } catch (e) {
      print('Unexpected error occurred during sign up: $e');
      showToast(message: 'An unexpected error occurred.');
    }
    return null;
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        showToast(message: 'Invalid email or password.');
      } else if (e.code == 'invalid-email') {
        showToast(message: 'Please enter a valid email address.');
      } else if (e.code == 'too-many-requests') {
        showToast(message: 'Too many attempts. Please try again later.');
      } else {
        showToast(message: 'An error occurred: ${e.code}');
      }
    } catch (e) {
      print('Unexpected error occurred during sign in: $e');
      showToast(message: 'An unexpected error occurred.');
    }
    return null;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sends verification email to the currently logged-in user
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No logged-in user.");
    if (user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Reloads the current user and returns whether email is verified
  Future<bool> reloadAndIsEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = _auth.currentUser;
    return fresh?.emailVerified ?? false;
  }

  /// Deletes the currently logged-in Firebase Auth user
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
  }

  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print('Error signing in anonymously: $e');
      showToast(message: 'Error signing in anonymously: ${e.code}');
    } catch (e) {
      print('Unexpected error occurred during anonymous sign in: $e');
      showToast(message: 'An unexpected error occurred.');
    }
    return null;
  }
}