import 'package:flutter/material.dart';
import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme_provider.dart';

class GroceryController extends GetxController {
  var groceryList = <Map<String, dynamic>>[].obs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _listenToGroceryList();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  String get userId => _auth.currentUser?.uid ?? "";

  void _listenToGroceryList() {
    if (userId.isEmpty) {
      groceryList.clear();
      return;
    }

    final ref = _firestore
        .collection('users')
        .doc(userId)
        .collection('groceryList')
        .orderBy('name'); // order optional

    _sub?.cancel();
    _sub = ref.snapshots().listen((snapshot) {
      groceryList.value = snapshot.docs
          .map((doc) => {
                "id": doc.id,
                "name": doc.data()['name'] ?? '',
                "checked": doc.data()['checked'] ?? false,
              })
          .toList();
    }, onError: (err) {
      // handle/ log errors if needed
      print("Grocery list listener error: $err");
    });
  }

  /// Add a single item (skips duplicates)
  Future<void> addItem(String item) async {
    if (item.isEmpty || userId.isEmpty) return;
    final exists = groceryList.any((e) => e['name'].toString().toLowerCase() == item.toLowerCase());
    if (exists) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('groceryList')
        .add({"name": item, "checked": false, "createdAt": FieldValue.serverTimestamp()});
  }

  /// ✅ Add multiple items (skips duplicates) — this method was missing previously
  Future<void> addItems(List<String> items) async {
    if (items.isEmpty || userId.isEmpty) return;

    // Normalize and filter unique new items (case-insensitive)
    final existingNames = groceryList.map((e) => e['name'].toString().toLowerCase()).toSet();
    final newItems = <String>[];
    for (var raw in items) {
      final item = raw.trim();
      if (item.isEmpty) continue;
      if (!existingNames.contains(item.toLowerCase())) {
        existingNames.add(item.toLowerCase());
        newItems.add(item);
      }
    }
    if (newItems.isEmpty) return;

    // Use batched writes for efficiency
    final batch = _firestore.batch();
    final collectionRef = _firestore.collection('users').doc(userId).collection('groceryList');

    for (var item in newItems) {
      final docRef = collectionRef.doc(); // new doc id
      batch.set(docRef, {"name": item, "checked": false, "createdAt": FieldValue.serverTimestamp()});
    }

    await batch.commit();
  }

  /// Toggle checked state for an item (uses doc id)
  Future<void> toggleCheck(int index) async {
    if (userId.isEmpty) return;
    if (index < 0 || index >= groceryList.length) return;

    final item = groceryList[index];
    final docId = item["id"];
    final currentChecked = item["checked"] ?? false;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('groceryList')
        .doc(docId)
        .update({"checked": !currentChecked});
  }

  /// Remove an item by index (uses doc id)
  Future<void> removeItem(int index) async {
    if (userId.isEmpty) return;
    if (index < 0 || index >= groceryList.length) return;

    final docId = groceryList[index]["id"];
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('groceryList')
        .doc(docId)
        .delete();
  }

  /// Clear all items for the user
  Future<void> clearAll() async {
    if (userId.isEmpty) return;

    final ref = _firestore.collection('users').doc(userId).collection('groceryList');
    final snapshot = await ref.get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

class GroceryListScreen extends StatelessWidget {
  final GroceryController controller = Get.put(GroceryController());
  GroceryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Get.find<ThemeProvider>();
    TextEditingController input = TextEditingController();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "My Grocery List",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ?? Colors.deepOrange,
        foregroundColor:
            Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "Clear All",
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(
                    "Clear Grocery List",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  content: Text(
                    "Are you sure you want to remove all items?",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        "Clear",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) await controller.clearAll();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField(context, input),
            const SizedBox(height: 20),
            Text(
              "Your Items",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            _buildGroceryList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(BuildContext context, TextEditingController input) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: input,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              decoration: InputDecoration(
                hintText: "Add grocery item...",
                hintStyle: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.5),
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (val) async {
                await controller.addItem(val.trim());
                input.clear();
              },
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle,
              color: Colors.deepOrange,
              size: 30,
            ),
            onPressed: () async {
              await controller.addItem(input.text.trim());
              input.clear();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryList(BuildContext context) {
    return Expanded(
      child: Obx(() {
        if (controller.groceryList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 60,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your grocery list is empty",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: controller.groceryList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = controller.groceryList[index];
            return Slidable(
              key: ValueKey(item["id"]),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => controller.removeItem(index),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                    label: 'Delete',
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Checkbox(
                    value: item["checked"],
                    activeColor: Colors.deepOrange,
                    checkColor: Colors.white,
                    onChanged: (_) => controller.toggleCheck(index),
                  ),
                  title: Text(
                    item["name"],
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      decoration:
                          item["checked"] ? TextDecoration.lineThrough : null,
                      color: item["checked"]
                          ? Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.6)
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
