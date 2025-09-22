import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pages/splash_screen.dart';
import 'pages/login_screen.dart';
import 'pages/signup_screen.dart';
import 'pages/main_screen.dart';
import 'theme/theme_provider.dart';

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
  runApp(const CookGenieApp()); // 🐛 Corrected: Moved this line outside the if/else block.
}

class CookGenieApp extends StatelessWidget {
  const CookGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Get.put(ThemeProvider());
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Cook Genie",
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const SplashScreen()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/signup', page: () => const SignUpPage()),
        GetPage(name: '/main', page: () => const MainScreen()),
      ],
    );
  }
}



// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'pages/splash_screen.dart';
// import 'pages/login_screen.dart';
// import 'pages/signup_screen.dart';
// import 'pages/main_screen.dart';
// import 'theme/theme_provider.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   if (kIsWeb) {
//     await Firebase.initializeApp(
//       options: const FirebaseOptions(
//         apiKey: "AIzaSyCnGXjPFe-3S_lxDV2Z_87ia5XGweJB1fM",
//         authDomain: "cook-genie-2600f.firebaseapp.com",
//         projectId: "cook-genie-2600f",
//         storageBucket: "cook-genie-2600f.firebasestorage.app",
//         messagingSenderId: "1033640517643",
//         appId: "1:1033640517643:web:557c98417a801af771670e",
//         measurementId: "G-FXB2T0PT3M",
//       ),
//     );
//     runApp(const CookGenieApp());
//   } else {
//     await Firebase.initializeApp();
//   }
// }

// class CookGenieApp extends StatelessWidget {
//   const CookGenieApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Get.put(ThemeProvider());
//     return GetMaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: "Cook Genie",
//       theme: ThemeData.light(),
//       darkTheme: ThemeData.dark(),
//       themeMode: ThemeMode.system,
//       initialRoute: '/', // ✅ SplashScreen first
//       getPages: [
//         GetPage(name: '/', page: () => const SplashScreen()),
//         GetPage(name: '/login', page: () => const LoginScreen()),
//         GetPage(name: '/signup', page: () => const SignUpPage()),
//         GetPage(name: '/main', page: () => const MainScreen()),
//       ],
//     );
//   }
// }
