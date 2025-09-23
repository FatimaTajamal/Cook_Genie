// HomeScreen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'RecipeScreen.dart';
import 'Categories.dart';
import 'voice_assistant_controller.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes;

  const HomeScreen({super.key, required this.savedRecipes});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late final VoiceAssistantController voiceController; // Use late final

  final List<Map<String, dynamic>> categories = [
    {"title": "Breakfast", "icon": Icons.free_breakfast, "color": Colors.orange},
    {"title": "Lunch", "icon": Icons.lunch_dining, "color": Color(0xFF87EB8A)},
    {"title": "Dinner", "icon": Icons.restaurant, "color": Color(0xFF81BDEE)},
    {"title": "Brunch", "icon": Icons.brunch_dining, "color": Color(0xFFCF86DC)},
    {"title": "Snacks", "icon": Icons.fastfood, "color": Color(0xFFE2AAA6)},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    voiceController = Get.find<VoiceAssistantController>(); // Get the controller instance

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!voiceController.hasWelcomed) {
        voiceController.hasWelcomed = true;
        await voiceController.speak(
          "Welcome to Cook Genie. Say search to find a recipe or use the search bar manually.",
        );
      }
      // Start listening when HomeScreen is first built
      if (!voiceController.isListening) {
        voiceController.startListeningOnHome(savedRecipes: widget.savedRecipes);
      }
    });
  }

  @override
  void dispose() {
   voiceController.onHomePageLeft();
    super.dispose();
  }

  /// Called when app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resume mic when HomeScreen comes back to the foreground
      voiceController.restartListening(savedRecipes: widget.savedRecipes);
    } else if (state == AppLifecycleState.paused) {
      // Stop mic when leaving the app
      voiceController.stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cook Genie"),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Scrollbar(
        controller: _scrollController,
        thickness: 6,
        radius: const Radius.circular(10),
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 20),
                const Text(
                  "Recipe Categories",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                _buildCategoryGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        voiceController.stopListening();
        Get.to(() => RecipeScreen(savedRecipes: widget.savedRecipes));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor,
              blurRadius: 5,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 10),
            Text(
              "Search for recipes...",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            voiceController.stopListening();
            String category = categories[index]['title'];
            Get.to(() => CategoryRecipeScreen(category: category));
          },
          child: Container(
            decoration: BoxDecoration(
              color: categories[index]['color'],
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor,
                  blurRadius: 5,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  categories[index]['icon'],
                  size: 50,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  categories[index]['title'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}







// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'RecipeScreen.dart';
// import 'Categories.dart';
// import 'voice_assistant_controller.dart';

// class HomeScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> savedRecipes;

//   const HomeScreen({super.key, required this.savedRecipes});

//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
//   final ScrollController _scrollController = ScrollController();
//   final VoiceAssistantController voiceController =
//       Get.put(VoiceAssistantController());

//   final List<Map<String, dynamic>> categories = [
//     {"title": "Breakfast", "icon": Icons.free_breakfast, "color": Colors.orange},
//     {"title": "Lunch", "icon": Icons.lunch_dining, "color": Color(0xFF87EB8A)},
//     {"title": "Dinner", "icon": Icons.restaurant, "color": Color(0xFF81BDEE)},
//     {"title": "Brunch", "icon": Icons.brunch_dining, "color": Color(0xFFCF86DC)},
//     {"title": "Snacks", "icon": Icons.fastfood, "color": Color(0xFFE2AAA6)},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       if (!voiceController.hasWelcomed) {
//         voiceController.hasWelcomed = true;
//         await voiceController.speak(
//           "Welcome to Cook Genie. Say search to find a recipe or use the search bar manually.",
//         );
//       }

//       // Start listening when HomeScreen is visible
//       voiceController.startListeningOnHome(savedRecipes: widget.savedRecipes);
//     });
//   }

//   @override
//   void dispose() {
//     voiceController.stopListening();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   /// Called when app lifecycle state changes
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       // Resume mic when HomeScreen comes back
//       voiceController.startListeningOnHome(savedRecipes: widget.savedRecipes);
//     } else if (state == AppLifecycleState.paused) {
//       // Stop mic when leaving screen
//       voiceController.stopListening();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Cook Genie"),
//         centerTitle: true,
//         backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
//         foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
//       ),
//       body: Scrollbar(
//         controller: _scrollController,
//         thickness: 6,
//         radius: const Radius.circular(10),
//         thumbVisibility: true,
//         child: SingleChildScrollView(
//           controller: _scrollController,
//           physics: const AlwaysScrollableScrollPhysics(),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildSearchBar(),
//                 const SizedBox(height: 20),
//                 const Text(
//                   "Recipe Categories",
//                   style: TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 _buildCategoryGrid(),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return GestureDetector(
//       onTap: () {
//         voiceController.stopListening();
//         Get.to(() => RecipeScreen(savedRecipes: widget.savedRecipes));
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
//         decoration: BoxDecoration(
//           color: Theme.of(context).cardColor,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Theme.of(context).shadowColor,
//               blurRadius: 5,
//               spreadRadius: 2,
//               offset: const Offset(0, 3),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             const Icon(Icons.search, color: Colors.grey),
//             const SizedBox(width: 10),
//             Text(
//               "Search for recipes...",
//               style: TextStyle(
//                 color: Theme.of(context).textTheme.bodyMedium?.color,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCategoryGrid() {
//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       padding: const EdgeInsets.only(top: 10),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         childAspectRatio: 1,
//         crossAxisSpacing: 10,
//         mainAxisSpacing: 10,
//       ),
//       itemCount: categories.length,
//       itemBuilder: (context, index) {
//         return GestureDetector(
//           onTap: () {
//             voiceController.stopListening();
//             String category = categories[index]['title'];
//             Get.to(() => CategoryRecipeScreen(category: category));
//           },
//           child: Container(
//             decoration: BoxDecoration(
//               color: categories[index]['color'],
//               borderRadius: BorderRadius.circular(15),
//               boxShadow: [
//                 BoxShadow(
//                   color: Theme.of(context).shadowColor,
//                   blurRadius: 5,
//                   spreadRadius: 2,
//                   offset: const Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   categories[index]['icon'],
//                   size: 50,
//                   color: Colors.white,
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   categories[index]['title'],
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }