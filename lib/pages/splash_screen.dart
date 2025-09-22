import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    _initApp();
  }

  Future<void> _initApp() async {
    // Wait for animation
    await Future.delayed(const Duration(seconds: 3));

    // Request microphone permission
    var micStatus = await Permission.microphone.request();

    if (!mounted) return;

    if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
      Get.snackbar(
        "Permission Required",
        "Microphone access is needed for voice commands.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    // Now check login
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Get.offNamed('/main');
    } else {
      Get.offNamed('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset(
                'lib/images/genie.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ],
      ),
    );
  }
}






// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//  Future.delayed(const Duration(seconds: 3), () {
//       final user = FirebaseAuth.instance.currentUser;

//       if (!mounted) return;

//       if (user != null) {
//         // ✅ User is already logged in → go to main screen
//         Get.offNamed('/main');
//       } else {
//         // ❌ No user → go to login
//         Get.offNamed('/login');
//       }
//     });
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           // Full-screen background image
//           Image.asset('lib/images/genie.png', fit: BoxFit.cover),
//           // Optional: You can overlay a semi-transparent color or loading spinner
//           Center(child: CircularProgressIndicator(color: Colors.white)),
//         ],
//       ),
//     );
//   }
// }
