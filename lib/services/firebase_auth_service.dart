import 'package:firebase_auth/firebase_auth.dart';
import '../../global/toast.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showToast(message: 'The email address is already in use.');
      } else {
        showToast(message: 'An error occurred: ${e.code}');
      }
    } catch (e) {
      print('Unexpected error occurred during sign up: $e');
      showToast(message: 'An unexpected error occurred.');
    }
    return null;
  }

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        showToast(message: 'Invalid email or password.');
      } else {
        showToast(message: 'An error occurred: ${e.code}');
      }
    } catch (e) {
      print('Unexpected error occurred during sign in: $e');
      showToast(message: 'An unexpected error occurred.');
    }
    return null;
  }

  Future<User?> signInAnonymously() async {
    try {
      UserCredential credential = await _auth.signInAnonymously();
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
