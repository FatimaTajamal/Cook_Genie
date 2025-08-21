import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'saved_recipes_screen.dart';
import 'grocery_list_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'IngredientSearchScreen.dart'; 

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Map<String, dynamic>> savedRecipes = [];
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _buildScreens();
  }

  void _buildScreens() {
    _screens = [
      HomeScreen(savedRecipes: savedRecipes),
      SavedRecipesScreen(
        savedRecipes: savedRecipes,
        onBack: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      GroceryListScreen(),
      IngredientSearchScreen(savedRecipes: savedRecipes), // ⬅ new screen
      ProfileScreen(),
      SettingsScreen(),
    ];
  }

  void _updateScreens() {
    setState(() {
      _buildScreens();
      if (savedRecipes.isEmpty && _currentIndex == 1) {
        _currentIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Grocery'),
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: 'Ingredients'), // ⬅ new
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).unselectedWidgetColor,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        type: BottomNavigationBarType.fixed, // ⬅ important for 6+ items
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'home_screen.dart';
// import 'saved_recipes_screen.dart';
// import 'grocery_list_screen.dart';
// import 'profile_screen.dart';
// import 'settings_screen.dart';

// class MainScreen extends StatefulWidget {
//   const MainScreen({super.key});

//   @override
//   State<MainScreen> createState() => _MainScreenState();
// }

// class _MainScreenState extends State<MainScreen> {
//   int _currentIndex = 0;
//   final List<Map<String, dynamic>> savedRecipes = [];
//   late List<Widget> _screens;

//   @override
//   void initState() {
//     super.initState();
//     _buildScreens();
//   }

//   void _buildScreens() {
//     _screens = [
//       HomeScreen(savedRecipes: savedRecipes),
//       SavedRecipesScreen(
//         savedRecipes: savedRecipes,
//         onBack: () {
//           setState(() {
//             _currentIndex = 0;
//           });
//         },
//       ),
//       GroceryListScreen(),
//       ProfileScreen(),
//       SettingsScreen(),
//     ];
//   }

//   void _updateScreens() {
//     setState(() {
//       _buildScreens();
//       if (savedRecipes.isEmpty && _currentIndex == 1) {
//         _currentIndex = 0;
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _screens[_currentIndex],
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         onTap: (index) {
//           setState(() {
//             _currentIndex = index;
//           });
//         },
//         items: const [
//           BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
//           BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.shopping_cart),
//             label: 'Grocery',
//           ),
//           BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.settings),
//             label: 'Settings',
//           ),
//         ],
//         selectedItemColor: Theme.of(context).primaryColor,
//         unselectedItemColor: Theme.of(context).unselectedWidgetColor,
//         backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
//       ),
//     );
//   }
// }
