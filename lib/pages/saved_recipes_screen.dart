import 'package:flutter/material.dart';
import 'firestore_saved_recipes_service.dart';
import 'RecipeScreen.dart';

class SavedRecipesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedRecipes; // kept for compatibility
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
          await _loadFromFirestore();
        });
  }

  Future<void> _remove(Map<String, dynamic> recipe) async {
    final name = (recipe['name'] ?? '').toString();

    setState(() {
      _savedRecipes.removeWhere((r) => (r['name'] ?? '').toString() == name);
    });

    try {
      await FirestoreSavedRecipesService.removeRecipe(recipe);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Removed from Saved'),
          backgroundColor: const Color(0xFF2A1246),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      await _loadFromFirestore();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing recipe: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0615),
      appBar: AppBar(
        backgroundColor: const Color(0xFF120A22),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Saved Recipes',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFromFirestore,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          _bgGradient(),
          _bgStars(),
          SafeArea(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (_savedRecipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7E3FF2).withOpacity(0.18),
                  const Color(0xFF2A1246).withOpacity(0.35),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB57BFF).withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bookmark_rounded, size: 64, color: Color(0xFFB57BFF)),
                const SizedBox(height: 14),
                Text(
                  'No saved recipes yet!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save recipes by tapping the heart icon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withOpacity(0.65),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      itemCount: _savedRecipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = _savedRecipes[index];
        final String title = r['name']?.toString() ?? 'Untitled';
        final String imageUrl = (r['image_url'] ?? '').toString();

        String subtitleText = '';
        if (r['ingredients'] is List) {
          final items = (r['ingredients'] as List)
              .map((i) => i is Map ? i['name'] : null)
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .take(3)
              .toList();
          if (items.isNotEmpty) {
            subtitleText = "${items.join(', ')}…";
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openRecipe(r),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.06),
                  const Color(0xFF7E3FF2).withOpacity(0.12),
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
                _thumb(imageUrl),
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
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitleText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitleText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _remove(r),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 66,
        height: 66,
        color: Colors.white.withOpacity(0.06),
        child: (url.isNotEmpty)
            ? Image.network(
                url,
                width: 66,
                height: 66,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_rounded, size: 34, color: Colors.white70),
              )
            : const Icon(Icons.restaurant_rounded, size: 34, color: Colors.white70),
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
        ],
      ),
    );
  }
}