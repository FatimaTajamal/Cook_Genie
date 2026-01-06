import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_auth_service.dart';
import '../global/toast.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'user_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? pendingName; // used after signup
  const VerifyEmailScreen({super.key, this.pendingName});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final UserService _userService = UserService();

  Timer? _timer;

  // ✅ Only for button UI (manual check)
  bool _manualChecking = false;

  // ✅ For resend button UI
  bool _resending = false;

  // ✅ prevent overlapping auto checks
  bool _autoCheckInFlight = false;

  // Theme colors
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

  @override
  void initState() {
    super.initState();

    // Auto-check every 6 seconds (no UI loading)
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      _autoCheckVerified();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  Future<void> _resendEmail() async {
    setState(() => _resending = true);
    try {
      await _authService.sendVerificationEmail();
      showToast(message: "Verification email resent ✅");
    } catch (e) {
      debugPrint("Resend error: $e");
      showToast(message: "Failed to resend email. Try again.");
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// ✅ Auto check: NO setState toggles (no button flicker)
  Future<void> _autoCheckVerified() async {
    if (_autoCheckInFlight) return;
    _autoCheckInFlight = true;

    try {
      final verified = await _authService.reloadAndIsEmailVerified();
      if (verified) {
        await _onVerifiedNavigate();
      }
    } catch (e) {
      // silent on purpose
      debugPrint("Auto check verify error: $e");
    } finally {
      _autoCheckInFlight = false;
    }
  }

  /// ✅ Manual check: shows loading only when user taps button
  Future<void> _manualCheckVerified() async {
    if (_manualChecking) return;
    setState(() => _manualChecking = true);

    try {
      final verified = await _authService.reloadAndIsEmailVerified();
      if (verified) {
        await _onVerifiedNavigate();
      } else {
        showToast(message: "Not verified yet. Please check your email.");
      }
    } catch (e) {
      debugPrint("Manual check verify error: $e");
      showToast(message: "Could not check verification. Try again.");
    } finally {
      if (mounted) setState(() => _manualChecking = false);
    }
  }

  Future<void> _onVerifiedNavigate() async {
    // stop timer so it doesn't run after navigation
    _timer?.cancel();

    // Create Firestore profile ONLY AFTER verification (if provided)
    final name = widget.pendingName?.trim();
    if (name != null && name.isNotEmpty) {
      try {
        await _userService.saveUserPreferences(
          name: name,
          age: '',
          gender: '',
          dietaryPreferences: [],
          availableIngredients: [],
          allergies: [],
          profileImagePath: null,
        );
      } catch (e) {
        debugPrint("Firestore save after verify failed: $e");
      }
    }

    if (!mounted) return;
    showToast(message: "Email verified ✅ Welcome!");
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (_) => false,
    );
  }

  Future<void> _cancelAndDeleteAccount() async {
    try {
      await _authService.deleteCurrentUser();
      showToast(message: "Account removed. Please sign up again.");
    } catch (e) {
      debugPrint("Delete user error: $e");
      showToast(message: "Could not remove account. Try again.");
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "";

    return Scaffold(
      backgroundColor: _bgTop,
      body: Stack(
        children: [
          _bgGradient(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    "Verify your email",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "We sent a verification link to:",
                    style: TextStyle(color: Colors.white.withOpacity(0.65)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Steps",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "1) Open your email inbox\n"
                          "2) Click the verification link\n"
                          "3) Come back and tap “I verified”",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ✅ Manual check button: only loads when tapped
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _manualChecking ? null : _manualCheckVerified,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _manualChecking
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "I verified",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15.5,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _resending ? null : _resendEmail,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.18)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withOpacity(0.05),
                            ),
                            child: _resending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Resend email",
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _cancelAndDeleteAccount,
                          child: Text(
                            "Cancel & remove account",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}