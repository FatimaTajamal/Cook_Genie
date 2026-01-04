// WeeklyMealPlanScreen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WeeklyMealPlanScreen extends StatefulWidget {
  const WeeklyMealPlanScreen({super.key});

  @override
  _WeeklyMealPlanScreenState createState() => _WeeklyMealPlanScreenState();
}

class _WeeklyMealPlanScreenState extends State<WeeklyMealPlanScreen> {
  String selectedDiet = 'None';
  String selectedGoal = 'Maintain Weight';
  double caloriesIntake = 2000;
  bool isGenerating = false;
  Map<String, List<Map<String, dynamic>>>? weeklyPlan;

  final List<String> diets = [
    'None',
    'Vegetarian',
    'Vegan',
    'Keto',
    'Paleo',
    'Low Carb',
    'Mediterranean',
  ];

  final List<String> goals = [
    'Lose Weight',
    'Maintain Weight',
    'Gain Muscle',
    'Stay Healthy',
  ];

  // Cook Genie theme constants
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _panel = Color(0xFF120A22);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

  Future<void> _generateMealPlan() async {
    setState(() => isGenerating = true);

    try {
      final response = await http.post(
        Uri.parse('https://database-six-kappa.vercel.app/generate-meal-plan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'diet': selectedDiet,
          'goal': selectedGoal,
          'calories': caloriesIntake,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weeklyPlan = _parseMealPlan(data);
          isGenerating = false;
        });
      } else {
        setState(() {
          weeklyPlan = _generateMockPlan();
          isGenerating = false;
        });
      }
    } catch (e) {
      setState(() {
        weeklyPlan = _generateMockPlan();
        isGenerating = false;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> _parseMealPlan(dynamic data) {
    // Parse your API response here
    return _generateMockPlan();
  }

  Map<String, List<Map<String, dynamic>>> _generateMockPlan() {
    return {
      'Monday': [
        {'meal': 'Breakfast', 'recipe': 'Oatmeal with Berries', 'calories': 350},
        {'meal': 'Lunch', 'recipe': 'Grilled Chicken Salad', 'calories': 450},
        {'meal': 'Dinner', 'recipe': 'Salmon with Vegetables', 'calories': 600},
      ],
      'Tuesday': [
        {'meal': 'Breakfast', 'recipe': 'Greek Yogurt Parfait', 'calories': 300},
        {'meal': 'Lunch', 'recipe': 'Turkey Wrap', 'calories': 400},
        {'meal': 'Dinner', 'recipe': 'Stir Fry with Brown Rice', 'calories': 550},
      ],
      'Wednesday': [
        {'meal': 'Breakfast', 'recipe': 'Scrambled Eggs & Toast', 'calories': 400},
        {'meal': 'Lunch', 'recipe': 'Quinoa Bowl', 'calories': 450},
        {'meal': 'Dinner', 'recipe': 'Baked Chicken Breast', 'calories': 500},
      ],
      'Thursday': [
        {'meal': 'Breakfast', 'recipe': 'Smoothie Bowl', 'calories': 350},
        {'meal': 'Lunch', 'recipe': 'Pasta Primavera', 'calories': 500},
        {'meal': 'Dinner', 'recipe': 'Grilled Fish Tacos', 'calories': 550},
      ],
      'Friday': [
        {'meal': 'Breakfast', 'recipe': 'Avocado Toast', 'calories': 380},
        {'meal': 'Lunch', 'recipe': 'Caesar Salad', 'calories': 420},
        {'meal': 'Dinner', 'recipe': 'Beef Stir Fry', 'calories': 600},
      ],
      'Saturday': [
        {'meal': 'Breakfast', 'recipe': 'Pancakes with Fruit', 'calories': 450},
        {'meal': 'Lunch', 'recipe': 'Veggie Burger', 'calories': 480},
        {'meal': 'Dinner', 'recipe': 'Roasted Chicken', 'calories': 650},
      ],
      'Sunday': [
        {'meal': 'Breakfast', 'recipe': 'French Toast', 'calories': 420},
        {'meal': 'Lunch', 'recipe': 'Buddha Bowl', 'calories': 500},
        {'meal': 'Dinner', 'recipe': 'Shrimp Pasta', 'calories': 580},
      ],
    };
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
            child: weeklyPlan == null ? _buildSetupView() : _buildPlanView(),
          ),
        ],
      ),
    );
  }

  // ---------------- SETUP VIEW ----------------

  Widget _buildSetupView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topHeader(),
          const SizedBox(height: 18),

          _sectionTitle("Diet Style"),
          const SizedBox(height: 12),
          _buildDietSelector(),

          const SizedBox(height: 22),
          _sectionTitle("Goal"),
          const SizedBox(height: 12),
          _buildGoalSelector(),

          const SizedBox(height: 22),
          _sectionTitle("Daily Calories"),
          const SizedBox(height: 12),
          _buildCalorieCard(),

          const SizedBox(height: 22),
          _buildGenerateButton(),
          const SizedBox(height: 10),

          if (weeklyPlan == null)
            Text(
              "Tip: Keep it simple. You can regenerate anytime.",
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12.5),
            ),
        ],
      ),
    );
  }

  Widget _topHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            _accent2.withOpacity(0.18),
            _panel.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Weekly Meal Plan",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Tell us your diet + goal. Cook Genie will build your week.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDietSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: diets.map((diet) {
        final isSelected = selectedDiet == diet;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => selectedDiet = diet),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        _accent.withOpacity(0.32),
                        _accent2.withOpacity(0.18),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.06),
                        _panel.withOpacity(0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border.all(
                color: isSelected ? _accent.withOpacity(0.60) : Colors.white.withOpacity(0.10),
              ),
            ),
            child: Text(
              diet,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.70),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoalSelector() {
    return Column(
      children: goals.map((goal) {
        final isSelected = selectedGoal == goal;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => selectedGoal = goal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        _accent2.withOpacity(0.22),
                        _accent.withOpacity(0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.06),
                        _panel.withOpacity(0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border.all(
                color: isSelected ? _accent.withOpacity(0.55) : Colors.white.withOpacity(0.10),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _accent.withOpacity(0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? _accent : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? _accent : Colors.white.withOpacity(0.35),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    goal,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalorieCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            _panel.withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                "Daily Target",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                "${caloriesIntake.toInt()} cal",
                style: const TextStyle(
                  color: _accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _accent,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: _accent,
              overlayColor: _accent.withOpacity(0.20),
              trackHeight: 4,
            ),
            child: Slider(
              value: caloriesIntake,
              min: 1200,
              max: 4000,
              divisions: 56,
              onChanged: (value) => setState(() => caloriesIntake = value),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("1200",
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
              Text("4000",
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isGenerating ? null : _generateMealPlan,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accent.withOpacity(0.30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: isGenerating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                "Generate Weekly Plan",
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }

  // ---------------- PLAN VIEW ----------------

  Widget _buildPlanView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => weeklyPlan = null),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your Weekly Plan",
                      style: TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "$selectedGoal • ${caloriesIntake.toInt()} cal/day",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.60),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accent.withOpacity(0.22),
                      _accent2.withOpacity(0.14),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Text(
                  selectedDiet,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            itemCount: weeklyPlan!.length,
            itemBuilder: (context, index) {
              final day = weeklyPlan!.keys.elementAt(index);
              final meals = weeklyPlan![day]!;
              return _buildDayCard(day, meals);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(String day, List<Map<String, dynamic>> meals) {
    final totalCalories = meals.fold<int>(0, (sum, m) {
      final c = (m['calories'] is int) ? m['calories'] as int : int.tryParse("${m['calories']}") ?? 0;
      return sum + c;
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            _panel.withOpacity(0.38),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Text(
                    "$totalCalories cal",
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.08)),
          ...meals.map(_buildMealRow).toList(),
        ],
      ),
    );
  }

  Widget _buildMealRow(Map<String, dynamic> meal) {
    final mealType = (meal['meal'] ?? '').toString();
    final recipeName = (meal['recipe'] ?? '').toString();
    final cal = (meal['calories'] is int) ? meal['calories'] as int : int.tryParse("${meal['calories']}") ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(_getMealIcon(mealType), size: 20, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mealType,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "$cal cal",
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMealIcon(String meal) {
    switch (meal) {
      case 'Breakfast':
        return Icons.free_breakfast_rounded;
      case 'Lunch':
        return Icons.lunch_dining_rounded;
      case 'Dinner':
        return Icons.restaurant_rounded;
      default:
        return Icons.fastfood_rounded;
    }
  }

  // ---------------- BACKGROUND ----------------

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
            left: 24,
            top: 90,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.05), size: 30),
          ),
          Positioned(
            right: 18,
            top: 150,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.04), size: 36),
          ),
          Positioned(
            right: 50,
            top: 360,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.04), size: 28),
          ),
        ],
      ),
    );
  }
}