// import 'package:flutter/material.dart';
// import 'RecipeSearch.dart'; // RecipeService (Gemini + caching)
// import 'RecipeScreen.dart'; // detail page

// class CategoryRecipeScreen extends StatefulWidget {
//   final String category;

//   const CategoryRecipeScreen({super.key, required this.category});

//   @override
//   _CategoryRecipeScreenState createState() => _CategoryRecipeScreenState();
// }

// class _CategoryRecipeScreenState extends State<CategoryRecipeScreen> {
  
//   List<Map<String, dynamic>> categoryRecipes = [];
// List<Map<String, dynamic>> filteredRecipes = [];

// bool isLoading = true;
// bool _loadingMore = false;

// int _currentPage = 1;
// bool _hasMore = true;

// String _searchQuery = '';
// static const int _pageSize = 3;


//   // --- THEME CONSTANTS (match your other screens) ---
//   static const Color _bgTop = Color(0xFF0B0615);
//   static const Color _bgMid = Color(0xFF130A26);
//   static const Color _bgBottom = Color(0xFF1C0B33);
//   static const Color _accent = Color(0xFFB57BFF);
//   static const Color _accent2 = Color(0xFF7E3FF2);

//   @override
//   void initState() {
//     super.initState();
//     fetchCategorySuggestionsAndFirstPage();
//   }

//  Future<void> fetchCategorySuggestionsAndFirstPage() async {
//   try {
//     final res = await RecipeService.getCategoryRecipesPaged(
//       category: widget.category,
//       page: 1,
//       limit: _pageSize,
//     );

//     if (!mounted) return;

//     setState(() {
//       categoryRecipes = res.recipes;
//       filteredRecipes = res.recipes;
//       _currentPage = res.currentPage;
//       _hasMore = res.hasMore;
//       isLoading = false;
//     });
//   } catch (e) {
//     debugPrint("❌ Error fetching category recipes: $e");
//     if (mounted) setState(() => isLoading = false);
//   }
// }



//   Future<void> _loadNextPage() async {
//   if (_loadingMore) return; // don't stop based on _hasMore

//   setState(() => _loadingMore = true);

//   try {
//     final res = await RecipeService.getCategoryRecipesPaged(
//       category: widget.category,
//       page: _currentPage + 1,
//       limit: _pageSize, // always request 3 recipes
//     );

//     if (!mounted) return;

//     setState(() {
//       categoryRecipes.addAll(res.recipes);
//       _applyFilter(_searchQuery); // keep search working
//       _currentPage++; // increment page regardless of count returned
//       _loadingMore = false;

//       // force _hasMore = true because API can always generate more
//       _hasMore = true;
//     });
//   } catch (e) {
//     debugPrint("❌ Load more error: $e");
//     if (mounted) setState(() => _loadingMore = false);
//   }
// }



//   void _applyFilter(String query) {
//     _searchQuery = query;
//     if (query.trim().isEmpty) {
//       filteredRecipes = List<Map<String, dynamic>>.from(categoryRecipes);
//     } else {
//       final lower = query.trim().toLowerCase();
//       filteredRecipes = categoryRecipes.where((recipe) {
//         final title = (recipe['name'] ?? '').toString().toLowerCase();
//         return title.contains(lower);
//       }).toList();
//     }
//   }

//   void filterSearch(String query) {
//     setState(() => _applyFilter(query));
//   }

//   void openRecipe(Map<String, dynamic> recipe) {
//     if (!mounted) return;

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => RecipeScreen(
//           savedRecipes: categoryRecipes,
//           initialRecipe: recipe,
//         ),
//       ),
//     );
//   }

//   // ---------- THEMED UI ----------
//   void _showSnack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: const Color(0xFF2A1246),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//       ),
//     );
//   }

//   Widget _bgGradient() {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [_bgTop, _bgMid, _bgBottom],
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//         ),
//       ),
//     );
//   }

//   Widget _bgStars() {
//     return IgnorePointer(
//       child: Stack(
//         children: [
//           Positioned(
//             left: 22,
//             top: 110,
//             child: Icon(Icons.auto_awesome,
//                 color: Colors.white.withOpacity(0.06), size: 28),
//           ),
//           Positioned(
//             right: 18,
//             top: 160,
//             child: Icon(Icons.auto_awesome,
//                 color: Colors.white.withOpacity(0.05), size: 34),
//           ),
//           Positioned(
//             right: 60,
//             top: 380,
//             child: Icon(Icons.auto_awesome,
//                 color: Colors.white.withOpacity(0.05), size: 26),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _header() {
//     return Stack(
//       children: [
//         Positioned(
//           left: -4,
//           top: 6,
//           child: Icon(
//             Icons.auto_awesome,
//             color: Colors.white.withOpacity(0.08),
//             size: 44,
//           ),
//         ),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               "${widget.category} recipes",
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 20,
//                 fontWeight: FontWeight.w900,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               "Search inside what you've loaded, or keep loading more suggestions.",
//               style: TextStyle(
//                 color: Colors.white.withOpacity(0.65),
//                 fontSize: 13.5,
//                 height: 1.25,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildSearchBar() {
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(18),
//         gradient: LinearGradient(
//           colors: [
//             _accent2.withOpacity(0.20),
//             _accent.withOpacity(0.10),
//           ],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         border: Border.all(color: Colors.white.withOpacity(0.14)),
//         boxShadow: [
//           BoxShadow(
//             color: _accent.withOpacity(0.16),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: TextField(
//         onChanged: filterSearch,
//         style: const TextStyle(color: Colors.white),
//         cursorColor: _accent,
//         decoration: InputDecoration(
//           hintText: "Search in ${widget.category}...",
//           hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
//           prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
//           border: InputBorder.none,
//           contentPadding:
//               const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//         ),
//       ),
//     );
//   }

//   Widget _emptyState({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//   }) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 18),
//         child: Container(
//           padding: const EdgeInsets.all(18),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(22),
//             gradient: LinearGradient(
//               colors: [
//                 _accent2.withOpacity(0.16),
//                 const Color(0xFF2A1246).withOpacity(0.35),
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             border: Border.all(color: Colors.white.withOpacity(0.12)),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(icon, size: 54, color: _accent),
//               const SizedBox(height: 10),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w900,
//                   color: Colors.white.withOpacity(0.92),
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 subtitle,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.65),
//                   fontSize: 13,
//                   height: 1.25,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildList() {
//     return Expanded(
//       child: ListView.separated(
//         padding: const EdgeInsets.only(top: 4, bottom: 14),
//         itemCount: filteredRecipes.length,
//         separatorBuilder: (_, __) => const SizedBox(height: 10),
//         itemBuilder: (context, index) {
//           final recipe = filteredRecipes[index];
//           final title = recipe['name']?.toString() ?? 'No Title';

//           final ingredientsText = (recipe['ingredients'] is List)
//               ? ((recipe['ingredients'] as List)
//                       .map((i) => (i is Map ? i['name'] : null)?.toString() ?? '')
//                       .where((s) => s.trim().isNotEmpty)
//                       .take(6)
//                       .join(', '))
//               : '';

//           final imageUrl = (recipe['image_url'] ?? '').toString();

//           return InkWell(
//             borderRadius: BorderRadius.circular(20),
//             onTap: () => openRecipe(recipe),
//             child: Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(20),
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.white.withOpacity(0.06),
//                     _accent2.withOpacity(0.12),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 border: Border.all(color: Colors.white.withOpacity(0.10)),
//                 boxShadow: [
//                   BoxShadow(
//                     color: _accent.withOpacity(0.10),
//                     blurRadius: 18,
//                     offset: const Offset(0, 10),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 54,
//                     height: 54,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(16),
//                       color: _accent.withOpacity(0.16),
//                       border: Border.all(color: Colors.white.withOpacity(0.10)),
//                     ),
//                     clipBehavior: Clip.antiAlias,
//                     child: imageUrl.isNotEmpty
//                         ? Image.network(
//                             imageUrl,
//                             fit: BoxFit.cover,
//                             errorBuilder: (_, __, ___) => const Icon(
//                               Icons.restaurant_rounded,
//                               color: Colors.white,
//                             ),
//                           )
//                         : const Icon(Icons.restaurant_rounded,
//                             color: Colors.white),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           title,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w900,
//                             fontSize: 15.5,
//                           ),
//                         ),
//                         const SizedBox(height: 6),
//                         if (ingredientsText.isNotEmpty)
//                           Text(
//                             ingredientsText,
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               color: Colors.white.withOpacity(0.65),
//                               fontSize: 12.5,
//                               height: 1.25,
//                             ),
//                           )
//                         else
//                           Text(
//                             "Tap to view recipe details",
//                             style: TextStyle(
//                               color: Colors.white.withOpacity(0.55),
//                               fontSize: 12.5,
//                               height: 1.25,
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Icon(Icons.chevron_right_rounded,
//                       color: Colors.white.withOpacity(0.75)),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//  Widget _buildLoadMore() {
//   // Only hide if searching; otherwise always show
//   if (_searchQuery.isNotEmpty) return const SizedBox.shrink();

//   return Padding(
//     padding: const EdgeInsets.only(top: 6),
//     child: SizedBox(
//       width: double.infinity,
//       height: 50,
//       child: ElevatedButton(
//         onPressed: _loadingMore ? null : _loadNextPage,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _accent,
//           foregroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           elevation: 0,
//         ),
//         child: _loadingMore
//             ? const SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   color: Colors.white,
//                 ),
//               )
//             : const Text(
//                 "Load more",
//                 style: TextStyle(
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: 0.2,
//                 ),
//               ),
//       ),
//     ),
//   );
// }



//   @override
//   Widget build(BuildContext context) {
//     final body = isLoading && categoryRecipes.isEmpty
//         ? const Center(
//             child: SizedBox(
//               width: 34,
//               height: 34,
//               child: CircularProgressIndicator(strokeWidth: 3),
//             ),
//           )
//         : Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _header(),
//               const SizedBox(height: 14),
//               _buildSearchBar(),
//               const SizedBox(height: 12),
//               if (filteredRecipes.isEmpty && categoryRecipes.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 10),
//                   child: _emptyState(
//                     icon: Icons.search_rounded,
//                     title: "No match found",
//                     subtitle: "Try a different keyword or load more recipes.",
//                   ),
//                 )
//               else if (filteredRecipes.isEmpty && categoryRecipes.isEmpty)
//                 Expanded(
//                   child: _emptyState(
//                     icon: Icons.restaurant_menu_rounded,
//                     title: "No recipes found",
//                     subtitle:
//                         "Try loading again, or check your connection and preferences.",
//                   ),
//                 )
//               else
//                 _buildList(),
//               const SizedBox(height: 10),
//               _buildLoadMore(),
//             ],
//           );

//     return Scaffold(
//       backgroundColor: _bgTop,
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF120A22),
//         elevation: 0,
//         centerTitle: true,
//         title: Text(
//           "${widget.category}",
//           style: const TextStyle(fontWeight: FontWeight.w900),
//         ),
//         foregroundColor: Colors.white,
//       ),
//       body: Stack(
//         children: [
//           _bgGradient(),
//           _bgStars(),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
//               child: body,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'RecipeSearch.dart'; // RecipeService (Gemini + caching)
import 'RecipeScreen.dart'; // detail page

class CategoryRecipeScreen extends StatefulWidget {
  final String category;

  const CategoryRecipeScreen({super.key, required this.category});

  @override
  _CategoryRecipeScreenState createState() => _CategoryRecipeScreenState();
}

class _CategoryRecipeScreenState extends State<CategoryRecipeScreen> {
  
  List<Map<String, dynamic>> categoryRecipes = [];
  List<Map<String, dynamic>> filteredRecipes = [];
  List<String> _shownRecipeIds = []; // ✅ Track shown recipe IDs

  bool isLoading = true;
  bool _loadingMore = false;

  int _currentPage = 1;
  bool _hasMore = true;

  String _searchQuery = '';
  static const int _pageSize = 3;

  // --- THEME CONSTANTS (match your other screens) ---
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

  @override
  void initState() {
    super.initState();
    fetchCategorySuggestionsAndFirstPage();
  }

  Future<void> fetchCategorySuggestionsAndFirstPage() async {
    try {
      final res = await RecipeService.getCategoryRecipesPaged(
        category: widget.category,
        page: 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      // ✅ Extract and track recipe IDs
      final newIds = res.recipes
          .map((r) => r['_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      debugPrint("✅ Initial load: ${res.recipes.length} recipes");
      debugPrint("✅ Initial IDs: $newIds");

      setState(() {
        categoryRecipes = res.recipes;
        filteredRecipes = res.recipes;
        _shownRecipeIds = newIds; // ✅ Initialize tracking
        _currentPage = res.currentPage;
        _hasMore = res.hasMore;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching category recipes: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore) return;

    setState(() => _loadingMore = true);

    try {
      final res = await RecipeService.getCategoryRecipesPaged(
        category: widget.category,
        page: _currentPage + 1,
        limit: _pageSize,
        excludeIds: _shownRecipeIds, // ✅ Pass already shown IDs
      );

      if (!mounted) return;

      // ✅ Extract new recipe IDs
      final newIds = res.recipes
          .map((r) => r['_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      debugPrint("✅ Loaded ${res.recipes.length} new recipes");
      debugPrint("✅ New IDs: $newIds");
      debugPrint("✅ Total shown IDs: ${_shownRecipeIds.length + newIds.length}");

      setState(() {
        categoryRecipes.addAll(res.recipes);
        _shownRecipeIds.addAll(newIds); // ✅ Track new IDs
        _applyFilter(_searchQuery); // keep search working
        _currentPage++;
        _loadingMore = false;
        _hasMore = true; // force true because API can always generate more
      });
      
      debugPrint("✅ Total recipes now: ${categoryRecipes.length}");
    } catch (e) {
      debugPrint("❌ Load more error: $e");
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      filteredRecipes = List<Map<String, dynamic>>.from(categoryRecipes);
    } else {
      final lower = query.trim().toLowerCase();
      filteredRecipes = categoryRecipes.where((recipe) {
        final title = (recipe['name'] ?? '').toString().toLowerCase();
        return title.contains(lower);
      }).toList();
    }
  }

  void filterSearch(String query) {
    setState(() => _applyFilter(query));
  }

  void openRecipe(Map<String, dynamic> recipe) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeScreen(
          savedRecipes: categoryRecipes,
          initialRecipe: recipe,
        ),
      ),
    );
  }

  // ---------- THEMED UI ----------
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF2A1246),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
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

  Widget _bgStars() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 22,
            top: 110,
            child: Icon(Icons.auto_awesome,
                color: Colors.white.withOpacity(0.06), size: 28),
          ),
          Positioned(
            right: 18,
            top: 160,
            child: Icon(Icons.auto_awesome,
                color: Colors.white.withOpacity(0.05), size: 34),
          ),
          Positioned(
            right: 60,
            top: 380,
            child: Icon(Icons.auto_awesome,
                color: Colors.white.withOpacity(0.05), size: 26),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Stack(
      children: [
        Positioned(
          left: -4,
          top: 6,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(0.08),
            size: 44,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.category} recipes",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Search inside what you've loaded, or keep loading more suggestions.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            _accent2.withOpacity(0.20),
            _accent.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        onChanged: filterSearch,
        style: const TextStyle(color: Colors.white),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: "Search in ${widget.category}...",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                _accent2.withOpacity(0.16),
                const Color(0xFF2A1246).withOpacity(0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: _accent),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.92),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 14),
        itemCount: filteredRecipes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final recipe = filteredRecipes[index];
          final title = recipe['name']?.toString() ?? 'No Title';

          final ingredientsText = (recipe['ingredients'] is List)
              ? ((recipe['ingredients'] as List)
                      .map((i) => (i is Map ? i['name'] : null)?.toString() ?? '')
                      .where((s) => s.trim().isNotEmpty)
                      .take(6)
                      .join(', '))
              : '';

          final imageUrl = (recipe['image_url'] ?? '').toString();

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => openRecipe(recipe),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.06),
                    _accent2.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _accent.withOpacity(0.16),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant_rounded,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.restaurant_rounded,
                            color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (ingredientsText.isNotEmpty)
                          Text(
                            ingredientsText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          )
                        else
                          Text(
                            "Tap to view recipe details",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withOpacity(0.75)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadMore() {
    // Only hide if searching; otherwise always show
    if (_searchQuery.isNotEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _loadingMore ? null : _loadNextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _loadingMore
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  "Load more",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = isLoading && categoryRecipes.isEmpty
        ? const Center(
            child: SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 14),
              _buildSearchBar(),
              const SizedBox(height: 12),
              if (filteredRecipes.isEmpty && categoryRecipes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _emptyState(
                    icon: Icons.search_rounded,
                    title: "No match found",
                    subtitle: "Try a different keyword or load more recipes.",
                  ),
                )
              else if (filteredRecipes.isEmpty && categoryRecipes.isEmpty)
                Expanded(
                  child: _emptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: "No recipes found",
                    subtitle:
                        "Try loading again, or check your connection and preferences.",
                  ),
                )
              else
                _buildList(),
              const SizedBox(height: 10),
              _buildLoadMore(),
            ],
          );

    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: const Color(0xFF120A22),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "${widget.category}",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _bgGradient(),
          _bgStars(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}