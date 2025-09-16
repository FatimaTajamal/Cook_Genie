import 'package:flutter/material.dart';
import '../services/saved_recipes_service.dart';
import 'RecipeScreen.dart';

class SavedRecipesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes;
  final VoidCallback onBack;

  const SavedRecipesScreen({
    super.key,
    required this.savedRecipes,
    required this.onBack,
  });

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  List<Map<String, dynamic>> _localSaved = [];

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final all = await SavedRecipesService.loadAll();
    if (!mounted) return;
    setState(() {
      // Prefer storage; fall back to list passed in
      _localSaved =
          all.isNotEmpty
              ? all
              : List<Map<String, dynamic>>.from(widget.savedRecipes);
    });
  }

  void _openRecipe(Map<String, dynamic> recipe) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (_) => RecipeScreen(
                  savedRecipes: widget.savedRecipes,
                  initialRecipe: recipe,
                  //showSearchBar: false, // HIDE SEARCH BAR for saved items
                ),
          ),
        )
        .then((_) async {
          // refresh in case the user unsaved it from detail
          await _loadFromStorage();
          if (mounted) setState(() {});
        });
  }

  Future<void> _remove(Map<String, dynamic> recipe) async {
    // Immediate UI update (no second tap)
    setState(() {
      final name = (recipe['name'] ?? '').toString();
      _localSaved.removeWhere((r) => (r['name'] ?? '').toString() == name);
      // keep legacy in-memory list in sync too
      widget.savedRecipes.removeWhere(
        (r) => (r['name'] ?? '').toString() == name,
      );
    });

    // Persist change
    await SavedRecipesService.remove(recipe);

    // Optional: ensure storage/UI fully in sync
    await _loadFromStorage();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Removed from Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final body =
        _localSaved.isEmpty
            ? const Center(child: Text('No saved recipes yet!'))
            : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _localSaved.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final r = _localSaved[index];
                return Card(
                  child: ListTile(
                    onTap: () => _openRecipe(r),
                    title: Text(r['name']?.toString() ?? 'Untitled'),
                    subtitle:
                        (r['ingredients'] is List)
                            ? Text(
                              ((r['ingredients'] as List)
                                      .map((i) => i['name'])
                                      .whereType<String>()
                                      .take(3)
                                      .join(', ')) +
                                  '…',
                            )
                            : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(r),
                      tooltip: 'Remove',
                    ),
                  ),
                );
              },
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: body,
    );
  }
}
