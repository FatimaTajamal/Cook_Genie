// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// class ThemeProvider extends GetxController {
//   var isDarkMode = false.obs;

//   ThemeData get themeData => isDarkMode.value ? _darkTheme : _lightTheme;

//   static final _lightTheme = ThemeData(
//     primarySwatch: Colors.orange,
//     brightness: Brightness.light,
//     scaffoldBackgroundColor: Colors.white,
//     appBarTheme: const AppBarTheme(
//       backgroundColor: Colors.deepOrange,
//       foregroundColor: Colors.white,
//     ),
//     textTheme: const TextTheme(
//       bodyMedium: TextStyle(color: Colors.black87),
//       titleLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
//     ),
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//       ),
//     ),
//   );

//   static final _darkTheme = ThemeData(
//     primarySwatch: Colors.grey,
//     brightness: Brightness.dark,
//     scaffoldBackgroundColor: Colors.black,
//     appBarTheme: const AppBarTheme(
//       backgroundColor: Colors.grey,
//       foregroundColor: Colors.white,
//     ),
//     textTheme: const TextTheme(
//       bodyMedium: TextStyle(color: Colors.white70),
//       titleLarge: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
//     ),
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.blueGrey,
//         foregroundColor: Colors.white,
//       ),
//     ),
//   );

//   void toggleTheme(bool value) {
//     isDarkMode.value = value;
//     Get.changeTheme(themeData);
//   }
// }
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends GetxController {
  var isDarkMode = false.obs;

  ThemeData get themeData => isDarkMode.value ? _darkTheme : _lightTheme;

  static final _lightTheme = ThemeData(
    primarySwatch: Colors.orange,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.deepOrange,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.black87),
      titleLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    ),
    cardColor: Colors.white,
    shadowColor: Colors.grey.withOpacity(0.5),
  );

  static final _darkTheme = ThemeData(
    primarySwatch: Colors.grey,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.grey,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
    ),
    cardColor: Colors.grey[800],
    shadowColor: Colors.black.withOpacity(0.5),
  );

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
    Get.changeTheme(themeData);
  }

  void toggleTheme(bool value) async {
    isDarkMode.value = value;
    Get.changeTheme(themeData);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }
}
