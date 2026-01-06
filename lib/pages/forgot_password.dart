import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../global/toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Cook Genie theme colors (match Login/Signup/Main)
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

  bool _isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF2A1246),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _bgGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgMid, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _bgStars() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 26,
            top: 120,
            child: Icon(Icons.auto_awesome,
                color: Colors.white.withOpacity(0.06), size: 28),
          ),
          Positioned(
            right: 18,
            top: 170,
            child: Icon(Icons.auto_awesome,
                color: Colors.white.withOpacity(0.05), size: 34),
          ),
          Positioned(
            right: 62,
            top: 420,
            child: Icon(Icons.auto_awesome,
                color: Colors.white.withOpacity(0.05), size: 26),
          ),
          Positioned(
            left: 18,
            bottom: 140,
            child: Icon(Icons.auto_awesome,
                color: Colors.white.withOpacity(0.04), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            _accent2.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.75)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _accent.withOpacity(0.85), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _primaryButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accent.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  fontSize: 15.5,
                ),
              ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      showToast(message: "Reset link sent ✅ Check your inbox (and Spam).");

      if (!mounted) return;
      Navigator.pop(context); // back to login
    } on FirebaseAuthException catch (e) {
      showToast(message: _getFriendlyErrorMessage(e));
    } catch (e) {
      debugPrint('Unexpected Error: $e');
      showToast(message: "An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      body: Stack(
        children: [
          _bgGradient(),
          _bgStars(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 34,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.arrow_back_rounded,
                                    color: Colors.white.withOpacity(0.9)),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Forgot password",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Enter your email and we’ll send you a reset link.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13.5,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 18),

                          _glassCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _inputDecoration(
                                      label: "Email",
                                      icon: Icons.email_rounded,
                                    ),
                                    validator: (value) {
                                      final v = value?.trim() ?? '';
                                      if (v.isEmpty) return 'Email is required';
                                      if (!_isEmailValid(v)) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _resetPassword(),
                                  ),
                                  const SizedBox(height: 14),
                                  _primaryButton(
                                    text: "Send reset link",
                                    onTap: _resetPassword,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Tip: If you don’t see the email, check Spam/Promotions.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.60),
                                      fontSize: 12.2,
                                      height: 1.25,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(),

                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "Back to Login",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              "CookGenie • Powered by AI Cooking Intelligence",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}