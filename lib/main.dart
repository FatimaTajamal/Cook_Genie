// main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pages/login_screen.dart';
import 'pages/main_screen.dart';
import 'pages/signup_screen.dart';
import 'pages/splash_screen.dart';
import 'pages/verify_email_screen.dart';
import 'theme/theme_provider.dart';
import 'pages/voice_assistant_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCnGXjPFe-3S_lxDV2Z_87ia5XGweJB1fM",
        authDomain: "cook-genie-2600f.firebaseapp.com",
        projectId: "cook-genie-2600f",
        storageBucket: "cook-genie-2600f.firebasestorage.app",
        messagingSenderId: "1033640517643",
        appId: "1:1033640517643:web:557c98417a801af771670e",
        measurementId: "G-FXB2T0PT3M",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Register controllers before UI builds
  Get.put(VoiceAssistantController());
  Get.put(ThemeProvider());

  runApp(const CookGenieApp());
}

class CookGenieApp extends StatelessWidget {
  const CookGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Cook Genie",
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,

      // ✅ Always start at AuthGate (it decides where to go)
      initialRoute: '/',

      getPages: [
        GetPage(name: '/', page: () => const AuthGate()),
        GetPage(name: '/splash', page: () => const SplashScreen()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/signup', page: () => const SignUpPage()),
        GetPage(name: '/verify', page: () => const VerifyEmailScreen()),
        GetPage(name: '/main', page: () => const MainScreen()),
      ],
    );
  }
}

/// ✅ Auth + Verification Gate
/// - Not logged in -> Login
/// - Logged in but email not verified -> VerifyEmailScreen
/// - Verified -> MainScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(); // keeps your existing splash visuals
        }

        final user = snapshot.data;

        // Not logged in
        if (user == null) {
          return const LoginScreen();
        }

        // Logged in - but might need a fresh reload to get latest verification state
        return FutureBuilder<void>(
          future: user.reload(),
          builder: (context, reloadSnap) {
            if (reloadSnap.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            final freshUser = FirebaseAuth.instance.currentUser;

            // Not verified
            if (freshUser != null && !freshUser.emailVerified) {
              return const VerifyEmailScreen();
            }

            // Verified
            return const MainScreen();
          },
        );
      },
    );
  }
}