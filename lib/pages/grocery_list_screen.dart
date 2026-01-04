import 'package:flutter/material.dart';
import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        .orderBy('name');

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
      // ignore: avoid_print
      print("Grocery list listener error: $err");
    });
  }

  Future<void> addItem(String item) async {
    if (item.isEmpty || userId.isEmpty) return;
    final exists = groceryList.any(
      (e) => e['name'].toString().toLowerCase() == item.toLowerCase(),
    );
    if (exists) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('groceryList')
        .add({
      "name": item,
      "checked": false,
      "createdAt": FieldValue.serverTimestamp()
    });
  }

  Future<void> addItems(List<String> items) async {
    if (items.isEmpty || userId.isEmpty) return;

    final existingNames =
        groceryList.map((e) => e['name'].toString().toLowerCase()).toSet();

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

    final batch = _firestore.batch();
    final collectionRef =
        _firestore.collection('users').doc(userId).collection('groceryList');

    for (var item in newItems) {
      final docRef = collectionRef.doc();
      batch.set(docRef, {
        "name": item,
        "checked": false,
        "createdAt": FieldValue.serverTimestamp()
      });
    }

    await batch.commit();
  }

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
  GroceryListScreen({super.key});

  final GroceryController controller = Get.put(GroceryController());

  // Theme constants (match your Home/Ingredient/Saved screens)
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);

  @override
  Widget build(BuildContext context) {
    final input = TextEditingController();

    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: const Color(0xFF120A22),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Grocery List",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            tooltip: "Clear All",
            onPressed: () async {
              final confirm = await _confirmClearDialog(context);
              if (confirm == true) {
                await controller.clearAll();
                _snack(context, "Cleared grocery list");
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _bgGradient(),
          _bgStars(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 14),
                  _inputField(context, input),
                  const SizedBox(height: 14),
                  Text(
                    "Your items",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _list(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI PARTS ----------

  Widget _header() {
    return Stack(
      children: [
        Positioned(
          right: -8,
          top: -6,
          child: Icon(
            Icons.shopping_bag_rounded,
            color: Colors.white.withOpacity(0.06),
            size: 64,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What do you need today?",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Add items, tick them off, and swipe to delete.",
              style: GoogleFonts.poppins(
                fontSize: 12.8,
                height: 1.25,
                color: Colors.white.withOpacity(0.62),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inputField(BuildContext context, TextEditingController input) {
    Future<void> addNow() async {
      final text = input.text.trim();
      if (text.isEmpty) return;
      await controller.addItem(text);
      input.clear();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            color: _accent.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: input,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: _accent,
              decoration: InputDecoration(
                hintText: "Add grocery item (e.g., milk, eggs)",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => addNow(),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: addNow,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _accent,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          )
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    return Obx(() {
      if (controller.groceryList.isEmpty) {
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
                  const Icon(Icons.shopping_cart_outlined, size: 54, color: _accent),
                  const SizedBox(height: 10),
                  Text(
                    "Your grocery list is empty",
                    style: GoogleFonts.poppins(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Add items above and check them off as you shop.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.8,
                      height: 1.25,
                      color: Colors.white.withOpacity(0.62),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 2, bottom: 10),
        itemCount: controller.groceryList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = controller.groceryList[index];
          final bool checked = (item["checked"] == true);

          return Slidable(
            key: ValueKey(item["id"]),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => controller.removeItem(index),
                  backgroundColor: const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  borderRadius: BorderRadius.circular(18),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
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
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: Transform.scale(
                  scale: 1.05,
                  child: Checkbox(
                    value: checked,
                    activeColor: _accent,
                    checkColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onChanged: (_) => controller.toggleCheck(index),
                  ),
                ),
                title: Text(
                  (item["name"] ?? '').toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 14.8,
                    fontWeight: FontWeight.w700,
                    color: checked
                        ? Colors.white.withOpacity(0.55)
                        : Colors.white.withOpacity(0.92),
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  // ---------- DIALOG / SNACK ----------

  Future<bool?> _confirmClearDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF120A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "Clear Grocery List?",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          "This will remove all items from your list.",
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.75)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Clear",
              style: GoogleFonts.poppins(color: _accent, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF2A1246),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ---------- BACKGROUND ----------

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