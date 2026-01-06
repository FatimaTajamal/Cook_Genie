import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../global/toast.dart';
import 'verify_email_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final FirebaseAuthService _auth = FirebaseAuthService();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSigningUp = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  // --- THEME CONSTANTS (match Login / Ingredient screen) ---
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // ---------- BACKGROUND ----------
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

  // ---------- UI ----------
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    _accent2.withOpacity(0.9),
                    _accent.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CookGenie",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  "Create your account",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          "Let’s get you started",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Save recipes, track ingredients, and build your grocery list in one place.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 13.5,
            height: 1.25,
          ),
        ),
      ],
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
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.75)),
      suffixIcon: suffix,
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
        onPressed: _isSigningUp ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accent.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSigningUp
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

  // ---------- SIGNUP LOGIC ----------
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSigningUp = true);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      showToast(message: "Passwords do not match");
      setState(() => _isSigningUp = false);
      return;
    }

    try {
      final user = await _auth.signUpWithEmailAndPassword(email, password);

      if (user == null) {
        setState(() => _isSigningUp = false);
        return;
      }

      // Send verification email
      await _auth.sendVerificationEmail();

      showToast(message: "Verification email sent. Please verify to continue.");

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            pendingName: "$firstName $lastName",
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint("❌ Signup error: $e");
      showToast(message: "Signup failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isSigningUp = false);
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
                          _header(),
                          const SizedBox(height: 18),
                          _glassCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _firstNameController,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: _inputDecoration(
                                            label: "First name",
                                            icon: Icons.person_rounded,
                                          ),
                                          validator: (value) {
                                            final v = value?.trim() ?? '';
                                            if (v.isEmpty) {
                                              return 'First name is required';
                                            }
                                            if (v.length > 50) {
                                              return 'Too long';
                                            }
                                            return null;
                                          },
                                          textInputAction: TextInputAction.next,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _lastNameController,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: _inputDecoration(
                                            label: "Last name",
                                            icon: Icons.person_outline_rounded,
                                          ),
                                          validator: (value) {
                                            final v = value?.trim() ?? '';
                                            if (v.isEmpty) {
                                              return 'Last name is required';
                                            }
                                            if (v.length > 50) {
                                              return 'Too long';
                                            }
                                            return null;
                                          },
                                          textInputAction: TextInputAction.next,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
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
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    style: const TextStyle(color: Colors.white),
                                    obscureText: _obscure1,
                                    decoration: _inputDecoration(
                                      label: "Password",
                                      icon: Icons.lock_rounded,
                                      suffix: IconButton(
                                        onPressed: () => setState(
                                            () => _obscure1 = !_obscure1),
                                        icon: Icon(
                                          _obscure1
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: Colors.white.withOpacity(0.70),
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      final v = value?.trim() ?? '';
                                      if (v.isEmpty) {
                                        return 'Password is required';
                                      }
                                      if (v.length < 6) {
                                        return 'Min 6 characters';
                                      }
                                      return null;
                                    },
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    style: const TextStyle(color: Colors.white),
                                    obscureText: _obscure2,
                                    decoration: _inputDecoration(
                                      label: "Confirm password",
                                      icon: Icons.lock_outline_rounded,
                                      suffix: IconButton(
                                        onPressed: () => setState(
                                            () => _obscure2 = !_obscure2),
                                        icon: Icon(
                                          _obscure2
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: Colors.white.withOpacity(0.70),
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      final v = value?.trim() ?? '';
                                      if (v.isEmpty) {
                                        return 'Confirm your password';
                                      }
                                      if (v != _passwordController.text.trim()) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) => _signUp(),
                                  ),
                                  const SizedBox(height: 14),
                                  _primaryButton(
                                    text: "Create account",
                                    onTap: _signUp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              "After signup, verify email to access the app.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.55),
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
}