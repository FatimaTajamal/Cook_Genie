// // HomeScreen.dart
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'RecipeScreen.dart';
// import 'Categories.dart';
// import 'saved_recipes_screen.dart';
// import 'voice_assistant_controller.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class HomeScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> savedRecipes;

//   const HomeScreen({super.key, required this.savedRecipes});

//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
//   final ScrollController _scrollController = ScrollController();
//   late final VoiceAssistantController voiceController;
//   String dailyHack = "Loading cooking hack...";
//   bool isLoadingHack = true;

//   final List<Map<String, dynamic>> categories = [
//     {
//       "title": "Breakfast",
//       "icon": Icons.free_breakfast,
//       "color": Color(0xFFFF9066)
//     },
//     {
//       "title": "Lunch", 
//       "icon": Icons.lunch_dining, 
//       "color": Color(0xFF66D9A8)
//     },
//     {
//       "title": "Dinner",
//       "icon": Icons.restaurant,
//       "color": Color(0xFF6B9EFF)
//     },
//     {
//       "title": "Brunch",
//       "icon": Icons.brunch_dining,
//       "color": Color(0xFFB68CFF)
//     },
//     {
//       "title": "Snacks",
//       "icon": Icons.fastfood,
//       "color": Color(0xFFFF8BA0)
//     },
//   ];

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     voiceController = Get.find<VoiceAssistantController>();
//     _fetchDailyHack();

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       if (!voiceController.hasWelcomed) {
//         voiceController.hasWelcomed = true;
//         await voiceController.speak(
//           "Welcome to Cook Genie. Say search to find a recipe or use the search bar manually.",
//         );
//       }
//       if (!voiceController.isListening) {
//         voiceController.startListeningOnHome(savedRecipes: widget.savedRecipes);
//       }
//     });
//   }

//   Future<void> _fetchDailyHack() async {
//   try {
//     final response = await http.get(
//       Uri.parse('https://database-six-kappa.vercel.app/cooking-hacks/daily'),
//     );

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);

//       setState(() {
//         dailyHack = data['data']['hack']; // ✅ FIXED
//         isLoadingHack = false;
//       });
//     } else {
//       throw Exception('Non-200 response');
//     }
//   } catch (e) {
//     setState(() {
//       dailyHack =
//           "Keep your herbs fresh longer by storing them like flowers in water!";
//       isLoadingHack = false;
//     });
//   }
// }


//   @override
//   void dispose() {
//     voiceController.onHomePageLeft();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       voiceController.restartListening(savedRecipes: widget.savedRecipes);
//     } else if (state == AppLifecycleState.paused) {
//       voiceController.stopListening();
//     }
//   }

//   void _navigateToSavedRecipes() {
//     voiceController.stopListening();
//     Get.to(() => SavedRecipesScreen(
//       savedRecipes: widget.savedRecipes,
//       onBack: () {
//         Get.back();
//         voiceController.startListeningOnHome(savedRecipes: widget.savedRecipes);
//       },
//     ));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
    
//     return Scaffold(
//       backgroundColor: isDark ? Color(0xFF121212) : Color(0xFFF8F9FA),
//       body: SafeArea(
//         child: CustomScrollView(
//           controller: _scrollController,
//           physics: const BouncingScrollPhysics(),
//           slivers: [
//             _buildHeader(isDark),
//             SliverPadding(
//               padding: const EdgeInsets.all(20.0),
//               sliver: SliverList(
//                 delegate: SliverChildListDelegate([
//                   _buildSearchBar(isDark),
//                   const SizedBox(height: 24),
//                   _buildDailyHackCard(isDark),
//                   const SizedBox(height: 28),
//                   _buildCategoriesHeader(isDark),
//                   const SizedBox(height: 16),
//                   _buildCategoryList(isDark),
//                   const SizedBox(height: 20),
//                 ]),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader(bool isDark) {
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "Cook Genie",
//                   style: TextStyle(
//                     fontSize: 32,
//                     fontWeight: FontWeight.w800,
//                     color: isDark ? Colors.white : Color(0xFF1A1A1A),
//                     letterSpacing: -0.5,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 Text(
//                   "Discover delicious recipes",
//                   style: TextStyle(
//                     fontSize: 15,
//                     color: isDark ? Colors.grey[400] : Colors.grey[600],
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//               ],
//             ),
//             Container(
//               decoration: BoxDecoration(
//                 color: isDark ? Color(0xFF1E1E1E) : Colors.white,
//                 shape: BoxShape.circle,
//                 boxShadow: [
//                   BoxShadow(
//                     color: isDark 
//                         ? Colors.black.withOpacity(0.3)
//                         : Colors.black.withOpacity(0.08),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: IconButton(
//                 icon: Icon(
//                   Icons.favorite,
//                   color: Color(0xFFFF9066),
//                   size: 26,
//                 ),
//                 onPressed: _navigateToSavedRecipes,
//                 tooltip: 'Saved Recipes',
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar(bool isDark) {
//     return GestureDetector(
//       onTap: () {
//         voiceController.stopListening();
//         Get.to(() => RecipeScreen(savedRecipes: widget.savedRecipes));
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         decoration: BoxDecoration(
//           color: isDark ? Color(0xFF1E1E1E) : Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: isDark 
//                   ? Colors.black.withOpacity(0.3)
//                   : Colors.black.withOpacity(0.06),
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Icon(
//               Icons.search_rounded,
//               color: isDark ? Colors.grey[500] : Colors.grey[400],
//               size: 24,
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Text(
//                 "Search recipes...",
//                 style: TextStyle(
//                   color: isDark ? Colors.grey[500] : Colors.grey[500],
//                   fontSize: 15,
//                   fontWeight: FontWeight.w400,
//                 ),
//               ),
//             ),
//             Icon(
//               Icons.mic_rounded,
//               color: Color(0xFFFF9066),
//               size: 22,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDailyHackCard(bool isDark) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFFFF9066), Color(0xFFFF6B9D)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Color(0xFFFF9066).withOpacity(0.3),
//             blurRadius: 20,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Icon(
//                   Icons.lightbulb_rounded,
//                   color: Colors.white,
//                   size: 24,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 "Daily Cooking Hack",
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.white,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 14),
//           isLoadingHack
//               ? Center(
//                   child: Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
//                   ),
//                 )
//               : Text(
//                   dailyHack,
//                   style: TextStyle(
//                     fontSize: 15,
//                     color: Colors.white.withOpacity(0.95),
//                     fontWeight: FontWeight.w400,
//                     height: 1.5,
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCategoriesHeader(bool isDark) {
//     return Text(
//       "Categories",
//       style: TextStyle(
//         fontSize: 22,
//         fontWeight: FontWeight.w700,
//         color: isDark ? Colors.white : Color(0xFF1A1A1A),
//       ),
//     );
//   }

//   Widget _buildCategoryList(bool isDark) {
//     return SizedBox(
//       height: 140,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         physics: const BouncingScrollPhysics(),
//         itemCount: categories.length,
//         itemBuilder: (context, index) {
//           return GestureDetector(
//             onTap: () {
//               voiceController.stopListening();
//               String category = categories[index]['title'];
//               Get.to(() => CategoryRecipeScreen(category: category));
//             },
//             child: Container(
//               width: 160,
//               margin: EdgeInsets.only(
//                 right: index < categories.length - 1 ? 16 : 0,
//               ),
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: categories[index]['color'],
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: categories[index]['color'].withOpacity(0.3),
//                     blurRadius: 12,
//                     offset: const Offset(0, 6),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Icon(
//                       categories[index]['icon'],
//                       size: 32,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     categories[index]['title'],
//                     style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// HomeScreen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'RecipeScreen.dart';
import 'Categories.dart';
import 'voice_assistant_controller.dart';
import 'saved_recipes_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes;

  const HomeScreen({super.key, required this.savedRecipes});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late final VoiceAssistantController voiceController;
  String dailyHack = "Loading cooking hack...";
  bool isLoadingHack = true;

  final List<Map<String, dynamic>> categories = [
    {"title": "Breakfast", "icon": Icons.free_breakfast_rounded},
    {"title": "Lunch", "icon": Icons.lunch_dining_rounded},
    {"title": "Dinner", "icon": Icons.restaurant_rounded},
    {"title": "Brunch", "icon": Icons.brunch_dining_rounded},
    {"title": "Snacks", "icon": Icons.fastfood_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    voiceController = Get.find<VoiceAssistantController>();
    _fetchDailyHack();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!voiceController.hasWelcomed) {
        voiceController.hasWelcomed = true;
        await voiceController.speak(
          "Welcome to Cook Genie. Say search to find a recipe or use the search bar manually.",
        );
      }

      if (!voiceController.isListening) {
        voiceController.startListeningOnHome(savedRecipes: widget.savedRecipes);
      }
    });
  }

 Future<void> _fetchDailyHack() async {
  try {
    final response = await http.get(
      Uri.parse('https://database-six-kappa.vercel.app/cooking-hacks/daily'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        dailyHack = data['data']['hack']; // ✅ FIXED
        isLoadingHack = false;
      });
    } else {
      throw Exception('Non-200 response');
    }
  } catch (e) {
    setState(() {
      dailyHack =
          "Keep your herbs fresh longer by storing them like flowers in water!";
      isLoadingHack = false;
    });
  }
}


  @override
  void dispose() {
    voiceController.onHomePageLeft();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      voiceController.restartListening(savedRecipes: widget.savedRecipes);
    } else if (state == AppLifecycleState.paused) {
      voiceController.stopListening();
    }
  }

  void _goToRecipesSearch() {
    voiceController.stopListening();
    Get.to(() => RecipeScreen(savedRecipes: widget.savedRecipes));
  }

  void _goToSavedRecipes() {
    voiceController.stopListening();

    Get.to(() => SavedRecipesScreen(
          savedRecipes: widget.savedRecipes,
          onBack: () => Get.back(),
        ));
  }

  void _goToCategory(String category) {
    voiceController.stopListening();
    Get.to(() => CategoryRecipeScreen(category: category));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0615),
      body: Stack(
        children: [
          _bgGradient(),
          _bgStars(),
          SafeArea(
            child: Scrollbar(
              controller: _scrollController,
              thickness: 6,
              radius: const Radius.circular(10),
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topBar(),
                      const SizedBox(height: 18),
                      _heroHeader(),
                      const SizedBox(height: 18),
                      _searchBar(),
                      const SizedBox(height: 18),
                      _dailyHackCard(),
                      const SizedBox(height: 22),
                      _sectionTitle("Explore Categories"),
                      const SizedBox(height: 12),
                      _categoryHorizontalList(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TOP BAR ----------

  Widget _topBar() {
    return Row(
      children: [
        const Expanded(
          child: Center(
            child: Text(
              "Cook Genie",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: _goToSavedRecipes,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFB57BFF),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- HERO ----------

  Widget _heroHeader() {
    return Stack(
      children: [
        Positioned(
          left: -6,
          top: 8,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(0.10),
            size: 48,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Hello, Chef",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB57BFF),
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "What magic shall we cook today?",
              style: TextStyle(
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFFCFC6DF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- SEARCH ----------

  Widget _searchBar() {
    return GestureDetector(
      onTap: _goToRecipesSearch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7E3FF2).withOpacity(0.22),
              const Color(0xFFB57BFF).withOpacity(0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB57BFF).withOpacity(0.20),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.70)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Search recipes, ingredients, or say it...",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                voiceController.restartListening(savedRecipes: widget.savedRecipes);
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Color(0xFFB57BFF),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- DAILY HACK ----------

  Widget _dailyHackCard() {
    final DateTime now = DateTime.now();
    final months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    final weekdays = [
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ];
    final dateText = "${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7E3FF2).withOpacity(0.22),
            const Color(0xFF2A1246).withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E3FF2).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Color(0xFFB57BFF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Daily Cooking Hack",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isLoadingHack
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB57BFF)),
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Text(
                  dailyHack,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    height: 1.35,
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: Text(
              "— $dateText —",
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- CATEGORIES (HORIZONTAL) ----------

  Widget _categoryHorizontalList() {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = categories[index];
          final title = item["title"] as String;
          final icon = item["icon"] as IconData;

          return GestureDetector(
            onTap: () => _goToCategory(title),
            child: Container(
              width: 170,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.06),
                    const Color(0xFF7E3FF2).withOpacity(0.14),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB57BFF).withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB57BFF).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Tap to explore",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Colors.white.withOpacity(0.92),
        letterSpacing: 0.2,
      ),
    );
  }

  // ---------- BACKGROUND ----------

  Widget _bgGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0B0615),
            Color(0xFF130A26),
            Color(0xFF1C0B33),
          ],
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
            left: 22,
            top: 110,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.06), size: 28),
          ),
          Positioned(
            right: 18,
            top: 160,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.05), size: 34),
          ),
          Positioned(
            right: 60,
            top: 380,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.05), size: 26),
          ),
          Positioned(
            left: 34,
            bottom: 210,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.04), size: 30),
          ),
        ],
      ),
    );
  }
}