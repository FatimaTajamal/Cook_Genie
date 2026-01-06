import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'home_screen.dart';
import 'grocery_list_screen.dart';
import 'profile_settings_screen.dart';
import 'IngredientSearchScreen.dart';
import 'WeeklyMealPlanScreen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> savedRecipes = [];
  late List<Widget> _screens;

  // Cook Genie theme colors
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _navBg = Color(0xFF120A22);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

  @override
  void initState() {
    super.initState();
    _buildScreens();
    _loadSavedRecipes();

    // ✅ Guard AFTER first frame to avoid context errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guardEmailVerified();
    });
  }

  Future<void> _guardEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }

    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser;

    if (fresh != null && !fresh.emailVerified) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _loadSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString('saved_recipes');
    if (recipesJson != null) {
      setState(() {
        savedRecipes = List<Map<String, dynamic>>.from(json.decode(recipesJson));
        _buildScreens();
      });
    }
  }

  void _buildScreens() {
    _screens = [
      HomeScreen(savedRecipes: savedRecipes),
      IngredientSearchScreen(savedRecipes: savedRecipes),
      const WeeklyMealPlanScreen(),
      GroceryListScreen(),
      ProfileSettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _CookGenieBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _CookGenieBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CookGenieBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const Color _navBg = Color(0xFF120A22);
  static const Color _accent = Color(0xFFB57BFF);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: _navBg,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 30,
              offset: const Offset(0, -12),
            ),
            BoxShadow(
              color: _accent.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
              label: "Home",
              icon: Icons.home_rounded,
              index: 0,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              label: "Ingredients",
              icon: Icons.kitchen_rounded,
              index: 1,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              label: "Meal Plan",
              icon: Icons.calendar_month_rounded,
              index: 2,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              label: "Grocery",
              icon: Icons.shopping_cart_rounded,
              index: 3,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              label: "Profile",
              icon: Icons.person_rounded,
              index: 4,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color _accent = Color(0xFFB57BFF);

  @override
  Widget build(BuildContext context) {
    final bool selected = index == currentIndex;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      _accent.withOpacity(0.26),
                      Colors.white.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: selected
                ? Border.all(color: Colors.white.withOpacity(0.12))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _accent.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? _accent : Colors.white.withOpacity(0.60),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? _accent : Colors.white.withOpacity(0.60),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}