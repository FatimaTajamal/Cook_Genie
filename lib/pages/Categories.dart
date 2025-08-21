import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'RecipeSearch.dart'; // contains RecipeService
import 'RecipeScreen.dart'; // screen that shows full recipe

class CategoryRecipeScreen extends StatefulWidget {
  final String category;

  const CategoryRecipeScreen({super.key, required this.category});

  @override
  _CategoryRecipeScreenState createState() => _CategoryRecipeScreenState();
}

class _CategoryRecipeScreenState extends State<CategoryRecipeScreen> {
  List<Map<String, dynamic>> categoryRecipes = [];
  List<Map<String, dynamic>> filteredRecipes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCategoryRecipes();
  }

  Future<void> fetchCategoryRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    String dietary = prefs.getString("dietPreference") ?? "";

    final List<String> suggestions =
        await RecipeService.getRecipeSuggestionsByCategoryAndPreference(
      category: widget.category,
  
    );

    if (suggestions.isNotEmpty) {
      final List<Map<String, dynamic>> recipes =
          await RecipeService.getMultipleRecipes(suggestions);

      setState(() {
        categoryRecipes = recipes;
        filteredRecipes = recipes;
        isLoading = false;
      });

      for (final recipe in recipes) {
        await RecipeService.saveRecipeAndPersist(recipe);
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void filterSearch(String query) {
    final results = categoryRecipes.where((recipe) {
      final title = recipe['name']?.toString().toLowerCase() ?? '';
      return title.contains(query.toLowerCase());
    }).toList();

    setState(() {
      filteredRecipes = results;
    });
  }

  void openRecipe(Map<String, dynamic> recipe) async {
    await RecipeService.saveRecipeAndPersist(recipe);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.category} Recipes"),
        backgroundColor: Colors.deepOrange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : categoryRecipes.isEmpty
              ? const Center(child: Text("No recipes found."))
              : Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = filteredRecipes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            elevation: 4,
                            child: ListTile(
                              title: Text(
                                recipe['name'] ?? 'No Title',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (recipe['ingredients'] as List?)
                                            ?.map((item) => item['name'] ?? '')
                                            .join(', ') ??
                                        '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => openRecipe(recipe),
                                      child: const Text("See More"),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeScreen(
                savedRecipes: categoryRecipes,
              ),
            ),
          );
        },
        child: AbsorbPointer(
          absorbing: true, // Prevents keyboard from opening
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search in ${widget.category}...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
