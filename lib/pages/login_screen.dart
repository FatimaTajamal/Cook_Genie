import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_screen.dart';
import 'signup_screen.dart';
import '../services/firebase_auth_service.dart';
import '../widgets/form_container_widget.dart';
import '../global/toast.dart';
import 'forgot_password.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuthService _auth = FirebaseAuthService();
  final _googleSignIn = GoogleSignIn(scopes: ['email']);
  bool _isLoading = false;
  bool _keepLoggedIn = false;

  // Handle Email/Password Sign-In
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      User? user = await _auth.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (_keepLoggedIn) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } else {
        await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
      }
      if (!mounted || user == null) {
        showToast(message: "Login failed. Please try again.");
        return;
      }
      showToast(message: "Login successful!");
      Get.off(() => const MainScreen());
    } catch (e) {
      print('Sign-In Error: $e');
      // Error handling is already in FirebaseAuthService
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Handle Google Sign-In
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In cancelled by user');
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      print(
        'Google Auth: accessToken=${googleAuth.accessToken}, idToken=${googleAuth.idToken}',
      );
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      if (_keepLoggedIn) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
      if (!mounted || userCredential.user == null) {
        showToast(message: "Google Sign-In failed. Please try again.");
        return;
      }
      showToast(message: "Google Sign-In successful!");
      Get.off(() => const MainScreen());
    } on FirebaseAuthException catch (e) {
      print('Google Sign-In Error: ${e.code} - ${e.message}');
      showToast(message: _getFriendlyErrorMessage(e));
    } catch (e) {
      print('Unexpected Error: $e');
      showToast(message: "An unexpected error occurred. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Handle Password Reset
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      showToast(
        message: "Password reset email sent to ${_emailController.text.trim()}",
      );
    } on FirebaseAuthException catch (e) {
      print('Password Reset Error: ${e.code} - ${e.message}');
      showToast(message: _getFriendlyErrorMessage(e));
    } catch (e) {
      print('Unexpected Error: $e');
      showToast(message: "An unexpected error occurred. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Convert Firebase errors to user-friendly messages
  String _getFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check and try again.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF8C42).withOpacity(0.8),
                const Color(0xFF4CAF50).withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Cook Genie",
                    style: GoogleFonts.lobster(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 50,
                    ),
                  ),
                  const SizedBox(height: 40),
                  FormContainerWidget(
                    controller: _emailController,
                    hintText: "Email",
                    isPasswordField: false,
                    inputType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  FormContainerWidget(
                    controller: _passwordController,
                    hintText: "Password",
                    isPasswordField: true,
                    inputType: TextInputType.visiblePassword,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                      onFieldSubmitted: (_) => _signIn(),
                  ),
                  CheckboxListTile(
                    value: _keepLoggedIn,
                    onChanged: (value) {
                      setState(() => _keepLoggedIn = value ?? false);
                    },
                    title: const Text(
                      'Keep me logged in',
                      style: TextStyle(color: Colors.white),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                     onPressed: _isLoading
      ? null
      : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ForgotPasswordScreen(),
            ),
          );
        },
        child: const Text(
          'Forgot Password?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            ),
            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : GestureDetector(
                        onTap: _signIn,
                        child: Container(
                          width: double.infinity,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              "Log in",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(
                      Icons.g_mobiledata,
                      color: Colors.blue,
                      size: 28,
                    ),
                    label: const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () {
                          Get.to(() => const SignUpPage());
                        },
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
