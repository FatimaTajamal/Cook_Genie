import 'package:flutter/material.dart';
import 'RecipeSearch.dart'; // RecipeService (Gemini + caching)
import 'RecipeScreen.dart'; // detail page
import 'firestore_saved_recipes_service.dart'; // Firestore service

class CategoryRecipeScreen extends StatefulWidget {
  final String category;

  const CategoryRecipeScreen({super.key, required this.category});

  @override
  _CategoryRecipeScreenState createState() => _CategoryRecipeScreenState();
}

class _CategoryRecipeScreenState extends State<CategoryRecipeScreen> {
  // Full list of names (from Gemini) – we page through this
  List<String> _allSuggestions = [];

  // Fetched recipe objects so far (paged)
  List<Map<String, dynamic>> categoryRecipes = [];
  List<Map<String, dynamic>> filteredRecipes = [];


  static const int _pageSize = 3;
  int _loadedCount = 0;
  bool isLoading = true; 
  bool _loadingMore = false; 
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchCategorySuggestionsAndFirstPage();
  }

  Future<void> fetchCategorySuggestionsAndFirstPage() async {
    try {
     
      final List<String> suggestions =
          await RecipeService.getRecipeSuggestionsByCategoryAndPreference(
            category: widget.category,
          );

      setState(() {
        _allSuggestions = suggestions;
      });

      // Load the first page (3) only
      await _loadNextPage(initial: true);
    } catch (e) {
      print('❌ Error fetching category suggestions: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNextPage({bool initial = false}) async {
    if (_loadingMore) return;
    if (_loadedCount >= _allSuggestions.length) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        if (initial) {
          isLoading = true; // show big loader on very first fetch
        } else {
          _loadingMore = true; // show small loader for "Load more"
        }
      });
    }

    final int nextEnd =
        (_loadedCount + _pageSize) > _allSuggestions.length
            ? _allSuggestions.length
            : _loadedCount + _pageSize;

    final List<String> slice = _allSuggestions.sublist(_loadedCount, nextEnd);

    try {
      // Fetch recipe objects for this slice
      final List<Map<String, dynamic>> nextRecipes =
          await RecipeService.getMultipleRecipes(slice);

      if (!mounted) return;

      // NO internal storage - just keep in memory for this session
      setState(() {
        categoryRecipes.addAll(nextRecipes);
        _applyFilter(_searchQuery); // refresh filtered view
        _loadedCount = nextEnd;
        isLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      print('❌ Error loading next page: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _loadingMore = false;
      });
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
    setState(() {
      _applyFilter(query);
    });
  }

  void openRecipe(Map<String, dynamic> recipe) async {
    // NO internal storage caching - only Firestore for saved recipes
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        onChanged: filterSearch,
        decoration: InputDecoration(
          hintText: "Search in ${widget.category}...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildList() {
    return Expanded(
      child: ListView.builder(
        itemCount: filteredRecipes.length,
        itemBuilder: (context, index) {
          final recipe = filteredRecipes[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 4,
            child: ListTile(
              onTap: () => openRecipe(recipe),
              leading: recipe['image_url'] != null && 
                      recipe['image_url'].toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        recipe['image_url'],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.restaurant,
                          size: 60,
                        ),
                      ),
                    )
                  : const Icon(Icons.restaurant, size: 60),
              title: Text(
                recipe['name']?.toString() ?? 'No Title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: (recipe['ingredients'] is List)
                  ? Text(
                      ((recipe['ingredients'] as List)
                              .map((i) => i['name'])
                              .whereType<String>()
                              .take(3)
                              .join(', ')) +
                          '…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadMore() {
    final bool hasMore = _loadedCount < _allSuggestions.length;
    // Hide "Load more" while searching
    final bool show = _searchQuery.trim().isEmpty && hasMore;

    if (!show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loadingMore ? null : () => _loadNextPage(),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
              : const Text("Load more"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = isLoading && categoryRecipes.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 8),
              if (filteredRecipes.isEmpty && categoryRecipes.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "No match found in loaded recipes.",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else if (filteredRecipes.isEmpty && categoryRecipes.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No recipes found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              if (filteredRecipes.isNotEmpty) _buildList(),
              _buildLoadMore(),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.category} Recipes"),
        backgroundColor: Colors.deepOrange,
      ),
      body: body,
    );
  }
}