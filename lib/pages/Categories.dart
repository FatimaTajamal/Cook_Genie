import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'RecipeSearch.dart'; // RecipeService (Gemini + caching)
import 'RecipeScreen.dart'; // detail page

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

  // Paging state
  static const int _pageSize = 3;
  int _loadedCount = 0;
  bool isLoading = true; // first load
  bool _loadingMore = false; // subsequent loads
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchCategorySuggestionsAndFirstPage();
  }

  Future<void> fetchCategorySuggestionsAndFirstPage() async {
    try {
      // Get the list of suggested recipe names for this category (+diet prefs)
      final List<String> suggestions =
          await RecipeService.getRecipeSuggestionsByCategoryAndPreference(
            category: widget.category,
          );

      setState(() {
        _allSuggestions = suggestions;
      });

      // Load the first page (3) only
      await _loadNextPage(initial: true);
    } catch (_) {
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

      // Optionally persist to your cache (as your original code did)
      for (final r in nextRecipes) {
        await RecipeService.saveRecipeAndPersist(r);
      }

      setState(() {
        categoryRecipes.addAll(nextRecipes);
        _applyFilter(_searchQuery); // refresh filtered view
        _loadedCount = nextEnd;
        isLoading = false;
        _loadingMore = false;
      });
    } catch (_) {
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
      filteredRecipes =
          categoryRecipes.where((recipe) {
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
    // keep your caching behavior
    await RecipeService.saveRecipeAndPersist(recipe);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => RecipeScreen(
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
              title: Text(
                recipe['name']?.toString() ?? 'No Title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle:
                  (recipe['ingredients'] is List)
                      ? Text(
                        ((recipe['ingredients'] as List)
                                .map((i) => i['name'])
                                .whereType<String>()
                                .take(3)
                                .join(', ')) +
                            '…',
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
          child:
              _loadingMore
                  ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : const Text("Load more"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body =
        isLoading && categoryRecipes.isEmpty
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
                  ),
                _buildList(),
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
