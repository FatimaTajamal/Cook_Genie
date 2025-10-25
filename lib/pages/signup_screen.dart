import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import 'user_service.dart'; // Add this import
import '../widgets/form_container_widget.dart';
import '../global/toast.dart';
import '../pages/login_screen.dart';
import '../pages/main_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final UserService _userService = UserService(); // Add this

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSigningUp = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(20),
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
                  const Color(0xFFFF8C42).withOpacity(0.8), // Warm Orange
                  const Color(0xFF4CAF50).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    "Create your Account",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'BriemHand',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FormContainerWidget(
                    controller: _firstNameController,
                    hintText: "First Name",
                    isPasswordField: false,
                  ),
                  const SizedBox(height: 10),
                  FormContainerWidget(
                    controller: _lastNameController,
                    hintText: "Last Name",
                    isPasswordField: false,
                  ),
                  const SizedBox(height: 10),
                  FormContainerWidget(
                    controller: _emailController,
                    hintText: "Email",
                    isPasswordField: false,
                  ),
                  const SizedBox(height: 10),
                  FormContainerWidget(
                    controller: _passwordController,
                    hintText: "Password",
                    isPasswordField: true,
                  ),
                  const SizedBox(height: 10),
                  FormContainerWidget(
                    controller: _confirmPasswordController,
                    hintText: "Confirm Password",
                    isPasswordField: true,
                    onFieldSubmitted: (_) => _signUp(),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _signUp,
                    child: Container(
                      width: double.infinity,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child:
                            _isSigningUp
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account?",
                        style: TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Log in",
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

  /// **Handles User Signup**
  void _signUp() async {
    setState(() {
      _isSigningUp = true;
    });

    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showToast(message: "All fields are required");
      setState(() {
        _isSigningUp = false;
      });
      return;
    }

    if (password != confirmPassword) {
      showToast(message: "Passwords do not match");
      setState(() {
        _isSigningUp = false;
      });
      return;
    }

    try {
      User? user = await _auth.signUpWithEmailAndPassword(email, password);

      // Always get the current signed-in user
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // 🔥 Create initial Firestore document for the new user
        try {
          await _userService.saveUserPreferences(
            name: '$firstName $lastName', // Combine first and last name
            age: '',
            gender: '',
            dietaryPreferences: [],
            availableIngredients: [],
            allergies: [],
            profileImagePath: null,
          );
          print("✅ User profile created in Firestore for: ${currentUser.email}");
        } catch (e) {
          print("❌ Error creating Firestore profile: $e");
          // Don't fail signup if Firestore fails, just log it
        }

        // Send verification email
        await currentUser.sendEmailVerification();
        print("📧 Verification email sent to: ${currentUser.email}");

        showToast(
          message:
              "Account created! Please check your email to verify your account.",
        );

        // Go to LoginScreen (don't auto-login until verified)
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        showToast(message: "Signup failed. Try again.");
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Signup failed.";
      
      switch (e.code) {
        case 'weak-password':
          errorMessage = "Password is too weak. Use at least 6 characters.";
          break;
        case 'email-already-in-use':
          errorMessage = "An account already exists with this email.";
          break;
        case 'invalid-email':
          errorMessage = "Invalid email address.";
          break;
        default:
          errorMessage = e.message ?? "Signup failed.";
      }
      
      showToast(message: errorMessage);
    } catch (e) {
      print("❌ Unexpected error during signup: $e");
      showToast(message: "An unexpected error occurred. Please try again.");
    } finally {
      setState(() {
        _isSigningUp = false;
      });
    }
  }
}