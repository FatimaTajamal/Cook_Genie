import 'package:flutter/material.dart';
import 'firestore_saved_recipes_service.dart';
import 'RecipeScreen.dart';

class SavedRecipesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes; // Keep for backward compatibility
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
  List<Map<String, dynamic>> _savedRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final recipes = await FirestoreSavedRecipesService.loadAllRecipes();
      if (!mounted) return;
      
      setState(() {
        _savedRecipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading saved recipes: $e');
      if (!mounted) return;
      
      setState(() {
        _savedRecipes = [];
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading saved recipes: $e')),
      );
    }
  }

  void _openRecipe(Map<String, dynamic> recipe) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => RecipeScreen(
              savedRecipes: _savedRecipes,
              initialRecipe: recipe,
            ),
          ),
        )
        .then((_) async {
          // Refresh in case the user unsaved it from detail
          await _loadFromFirestore();
        });
  }

  Future<void> _remove(Map<String, dynamic> recipe) async {
    // Immediate UI update
    setState(() {
      final name = (recipe['name'] ?? '').toString();
      _savedRecipes.removeWhere((r) => (r['name'] ?? '').toString() == name);
    });

    // Remove from Firestore
    try {
      await FirestoreSavedRecipesService.removeRecipe(recipe);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from Saved')),
      );
    } catch (e) {
      print('❌ Error removing recipe: $e');
      
      // Reload to restore UI if delete failed
      await _loadFromFirestore();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing recipe: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_savedRecipes.isEmpty) {
      body = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No saved recipes yet!',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Save recipes by tapping the heart icon',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _savedRecipes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final r = _savedRecipes[index];
          return Card(
            elevation: 2,
            child: ListTile(
              onTap: () => _openRecipe(r),
              leading: r['image_url'] != null && r['image_url'].toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        r['image_url'],
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
                r['name']?.toString() ?? 'Untitled',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: (r['ingredients'] is List)
                  ? Text(
                      ((r['ingredients'] as List)
                              .map((i) => i['name'])
                              .whereType<String>()
                              .take(3)
                              .join(', ')) +
                          '…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _remove(r),
                tooltip: 'Remove',
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          if (_savedRecipes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFromFirestore,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: body,
    );
  }
}








// import 'package:flutter/material.dart';
// import '../services/saved_recipes_service.dart';
// import 'RecipeScreen.dart';

// class SavedRecipesScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> savedRecipes;
//   final VoidCallback onBack;

//   const SavedRecipesScreen({
//     super.key,
//     required this.savedRecipes,
//     required this.onBack,
//   });

//   @override
//   State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
// }

// class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
//   List<Map<String, dynamic>> _localSaved = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadFromStorage();
//   }

//   Future<void> _loadFromStorage() async {
//     final all = await SavedRecipesService.loadAll();
//     if (!mounted) return;
//     setState(() {
//       // Prefer storage; fall back to list passed in
//       _localSaved =
//           all.isNotEmpty
//               ? all
//               : List<Map<String, dynamic>>.from(widget.savedRecipes);
//     });
//   }

//   void _openRecipe(Map<String, dynamic> recipe) {
//     Navigator.of(context)
//         .push(
//           MaterialPageRoute(
//             builder:
//                 (_) => RecipeScreen(
//                   savedRecipes: widget.savedRecipes,
//                   initialRecipe: recipe,
//                   //showSearchBar: false, // HIDE SEARCH BAR for saved items
//                 ),
//           ),
//         )
//         .then((_) async {
//           // refresh in case the user unsaved it from detail
//           await _loadFromStorage();
//           if (mounted) setState(() {});
//         });
//   }

//   Future<void> _remove(Map<String, dynamic> recipe) async {
//     // Immediate UI update (no second tap)
//     setState(() {
//       final name = (recipe['name'] ?? '').toString();
//       _localSaved.removeWhere((r) => (r['name'] ?? '').toString() == name);
//       // keep legacy in-memory list in sync too
//       widget.savedRecipes.removeWhere(
//         (r) => (r['name'] ?? '').toString() == name,
//       );
//     });

//     // Persist change
//     await SavedRecipesService.remove(recipe);

//     // Optional: ensure storage/UI fully in sync
//     await _loadFromStorage();

//     if (!mounted) return;
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(const SnackBar(content: Text('Removed from Saved')));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final body =
//         _localSaved.isEmpty
//             ? const Center(child: Text('No saved recipes yet!'))
//             : ListView.separated(
//               padding: const EdgeInsets.all(12),
//               itemCount: _localSaved.length,
//               separatorBuilder: (_, __) => const SizedBox(height: 8),
//               itemBuilder: (context, index) {
//                 final r = _localSaved[index];
//                 return Card(
//                   child: ListTile(
//                     onTap: () => _openRecipe(r),
//                     title: Text(r['name']?.toString() ?? 'Untitled'),
//                     subtitle:
//                         (r['ingredients'] is List)
//                             ? Text(
//                               ((r['ingredients'] as List)
//                                       .map((i) => i['name'])
//                                       .whereType<String>()
//                                       .take(3)
//                                       .join(', ')) +
//                                   '…',
//                             )
//                             : null,
//                     trailing: IconButton(
//                       icon: const Icon(Icons.delete_outline),
//                       onPressed: () => _remove(r),
//                       tooltip: 'Remove',
//                     ),
//                   ),
//                 );
//               },
//             );

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Saved Recipes'),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: widget.onBack,
//         ),
//       ),
//       body: body,
//     );
//   }
// }