// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'grocery_storage.dart';

// class GroceryController extends GetxController {
//   var groceryList = <Map<String, dynamic>>[].obs;

//   @override
//   void onInit() {
//     super.onInit();
//     loadFromStorage();
//   }

//   void addItem(String item) {
//     if (item.isNotEmpty && !groceryList.any((e) => e['name'] == item)) {
//       groceryList.add({"name": item, "checked": false});
//       GroceryStorage().addIngredients([item]);
//     }
//   }

//   void addItems(List<String> items) {
//     bool added = false;
//     for (var item in items) {
//       if (item.isNotEmpty && !groceryList.any((e) => e['name'] == item)) {
//         groceryList.add({"name": item, "checked": false});
//         added = true;
//       }
//     }
//     if (added) {
//       groceryList.refresh();
//       GroceryStorage().addIngredients(items);
//     }
//   }

//   void toggleCheck(int index) {
//     groceryList[index]["checked"] = !groceryList[index]["checked"];
//     groceryList.refresh();
//   }

//   void removeItem(int index) async {
//     final removed = groceryList.removeAt(index);
//     final existing = await GroceryStorage().getIngredients();
//     existing.remove(removed["name"]);
//     await GroceryStorage.overwriteIngredients(existing);
//   }

//   void clearAll() async {
//     groceryList.clear();
//     await GroceryStorage().clearIngredients();
//   }

//   void loadFromStorage() async {
//     final savedItems = await GroceryStorage().getIngredients();
//     for (var item in savedItems) {
//       if (!groceryList.any((e) => e["name"] == item)) {
//         groceryList.add({"name": item, "checked": false});
//       }
//     }
//   }
// }

// class GroceryListScreen extends StatelessWidget {
//   final GroceryController controller = Get.put(GroceryController());
//   GroceryListScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     TextEditingController input = TextEditingController();

//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         title: Text(
//           "My Grocery List",
//           style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
//         ),
//         centerTitle: true,
//         backgroundColor: Colors.deepOrange,
//         foregroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.delete_forever),
//             tooltip: "Clear All",
//             onPressed: () async {
//               final confirm = await showDialog<bool>(
//                 context: context,
//                 builder:
//                     (_) => AlertDialog(
//                       title: const Text("Clear Grocery List"),
//                       content: const Text(
//                         "Are you sure you want to remove all items?",
//                       ),
//                       actions: [
//                         TextButton(
//                           onPressed: () => Navigator.pop(context, false),
//                           child: const Text("Cancel"),
//                         ),
//                         TextButton(
//                           onPressed: () => Navigator.pop(context, true),
//                           child: const Text("Clear"),
//                         ),
//                       ],
//                     ),
//               );
//               if (confirm == true) controller.clearAll();
//             },
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildInputField(input),
//             const SizedBox(height: 20),
//             Text(
//               "Your Items",
//               style: GoogleFonts.poppins(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             const SizedBox(height: 12),
//             _buildGroceryList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildInputField(TextEditingController input) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: [
//           BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
//         ],
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: input,
//               style: GoogleFonts.poppins(fontSize: 16),
//               decoration: const InputDecoration(
//                 hintText: "Add grocery item...",
//                 border: InputBorder.none,
//               ),
//               onSubmitted: (val) {
//                 controller.addItem(val.trim());
//                 input.clear();
//               },
//             ),
//           ),
//           IconButton(
//             icon: const Icon(
//               Icons.add_circle,
//               color: Colors.deepOrange,
//               size: 30,
//             ),
//             onPressed: () {
//               controller.addItem(input.text.trim());
//               input.clear();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildGroceryList() {
//     return Expanded(
//       child: Obx(() {
//         if (controller.groceryList.isEmpty) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   Icons.shopping_cart_outlined,
//                   size: 60,
//                   color: Colors.grey.shade400,
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   "Your grocery list is empty",
//                   style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
//                 ),
//               ],
//             ),
//           );
//         }

//         return ListView.separated(
//           itemCount: controller.groceryList.length,
//           separatorBuilder: (_, __) => const SizedBox(height: 8),
//           itemBuilder: (context, index) {
//             final item = controller.groceryList[index];
//             return Slidable(
//               key: ValueKey(item["name"]),
//               endActionPane: ActionPane(
//                 motion: const DrawerMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => controller.removeItem(index),
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black12,
//                       blurRadius: 4,
//                       offset: Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: ListTile(
//                   leading: Checkbox(
//                     value: item["checked"],
//                     activeColor: Colors.deepOrange,
//                     onChanged: (_) => controller.toggleCheck(index),
//                   ),
//                   title: Text(
//                     item["name"],
//                     style: GoogleFonts.poppins(
//                       fontSize: 17,
//                       decoration:
//                           item["checked"] ? TextDecoration.lineThrough : null,
//                       color: item["checked"] ? Colors.grey : Colors.black87,
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       }),
//     );
//   }
// }

// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'dart:convert';
// // import 'grocery_storage.dart';

// // class GroceryController extends GetxController {
// //   var groceryItems =
// //       <Map<String, dynamic>>[]
// //           .obs; // {name: String, quantity: String, category: String, isPurchased: bool}

// //   void addItems(List<Map<String, dynamic>> items) {
// //     final newItems =
// //         items
// //             .where(
// //               (item) => !groceryItems.any((i) => i['name'] == item['name']),
// //             )
// //             .toList();
// //     groceryItems.addAll(newItems);
// //     GroceryStorage.overwriteIngredients(
// //       groceryItems
// //           .map(
// //             (i) => jsonEncode({
// //               'name': i['name'],
// //               'quantity': i['quantity'],
// //               'category': i['category'],
// //               'isPurchased': i['isPurchased'],
// //             }),
// //           )
// //           .toList(),
// //     );
// //     _savePurchasedState();
// //   }

// //   void togglePurchased(String itemName, bool value) {
// //     final index = groceryItems.indexWhere((item) => item['name'] == itemName);
// //     if (index != -1) {
// //       groceryItems[index]['isPurchased'] = value;
// //       _savePurchasedState();
// //     }
// //   }

// //   void removeItem(String itemName) {
// //     groceryItems.removeWhere((item) => item['name'] == itemName);
// //     GroceryStorage.overwriteIngredients(
// //       groceryItems
// //           .map(
// //             (i) => jsonEncode({
// //               'name': i['name'],
// //               'quantity': i['quantity'],
// //               'category': i['category'],
// //               'isPurchased': i['isPurchased'],
// //             }),
// //           )
// //           .toList(),
// //     );
// //     _savePurchasedState();
// //   }

// //   void sortItems(String criteria) {
// //     if (criteria == 'name') {
// //       groceryItems.sort((a, b) => a['name'].compareTo(b['name']));
// //     } else if (criteria == 'purchased') {
// //       groceryItems.sort((a, b) => a['isPurchased'] ? 1 : -1);
// //     }
// //     groceryItems.refresh();
// //   }

// //   Future<void> _savePurchasedState() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final purchasedStates =
// //         groceryItems
// //             .map(
// //               (item) => jsonEncode({
// //                 'name': item['name'],
// //                 'quantity': item['quantity'],
// //                 'category': item['category'],
// //                 'isPurchased': item['isPurchased'],
// //               }),
// //             )
// //             .toList();
// //     await prefs.setStringList('groceryPurchasedStates', purchasedStates);
// //   }

// //   Future<void> loadPurchasedState() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final storedStates = prefs.getStringList('groceryPurchasedStates');
// //     if (storedStates != null) {
// //       groceryItems.value =
// //           storedStates.map((state) {
// //             final decoded = jsonDecode(state) as Map<String, dynamic>;
// //             return {
// //               'name': decoded['name'] as String,
// //               'quantity': decoded['quantity'] as String? ?? '',
// //               'category': decoded['category'] as String? ?? 'Uncategorized',
// //               'isPurchased': decoded['isPurchased'] as bool? ?? false,
// //             };
// //           }).toList();
// //     }
// //   }
// // }

// // class GroceryListScreen extends StatefulWidget {
// //   const GroceryListScreen({super.key});

// //   @override
// //   _GroceryListScreenState createState() => _GroceryListScreenState();
// // }

// // class _GroceryListScreenState extends State<GroceryListScreen> {
// //   final GroceryController _groceryController = Get.put(GroceryController());
// //   String _sortCriteria = 'name';

// //   @override
// //   void initState() {
// //     super.initState();
// //     _groceryController.loadPurchasedState();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Text(
// //           'Grocery List',
// //           style: Theme.of(context).textTheme.titleLarge,
// //         ),
// //         backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
// //         foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
// //         actions: [
// //           PopupMenuButton<String>(
// //             onSelected: (value) {
// //               setState(() {
// //                 _sortCriteria = value;
// //                 _groceryController.sortItems(value);
// //               });
// //             },
// //             itemBuilder:
// //                 (context) => [
// //                   const PopupMenuItem(
// //                     value: 'name',
// //                     child: Text('Sort by Name'),
// //                   ),
// //                   const PopupMenuItem(
// //                     value: 'purchased',
// //                     child: Text('Sort by Purchased'),
// //                   ),
// //                 ],
// //           ),
// //         ],
// //       ),
// //       body: Padding(
// //         padding: const EdgeInsets.all(16.0),
// //         child: Obx(() {
// //           if (_groceryController.groceryItems.isEmpty) {
// //             return Center(
// //               child: Text(
// //                 'No items in your grocery list.',
// //                 style: Theme.of(context).textTheme.bodyMedium,
// //               ),
// //             );
// //           }
// //           return ListView.builder(
// //             itemCount: _groceryController.groceryItems.length,
// //             itemBuilder: (context, index) {
// //               final item = _groceryController.groceryItems[index];
// //               return Card(
// //                 color: Theme.of(context).cardColor,
// //                 elevation: Theme.of(context).cardTheme.elevation!,
// //                 shape: Theme.of(context).cardTheme.shape,
// //                 margin: const EdgeInsets.symmetric(vertical: 8.0),
// //                 child: ListTile(
// //                   leading: Checkbox(
// //                     value: item['isPurchased'],
// //                     onChanged: (value) {
// //                       _groceryController.togglePurchased(
// //                         item['name'],
// //                         value ?? false,
// //                       );
// //                     },
// //                     activeColor: Colors.green,
// //                     checkColor: Colors.white,
// //                   ),
// //                   title: RichText(
// //                     text: TextSpan(
// //                       children: [
// //                         TextSpan(
// //                           text: item['name'],
// //                           style: TextStyle(
// //                             fontFamily: 'Roboto',
// //                             color:
// //                                 Theme.of(context).textTheme.bodyMedium?.color,
// //                             decoration:
// //                                 item['isPurchased']
// //                                     ? TextDecoration.lineThrough
// //                                     : TextDecoration.none,
// //                             decorationColor:
// //                                 Theme.of(context).textTheme.bodyMedium?.color,
// //                           ),
// //                         ),
// //                         if (item['quantity'].isNotEmpty)
// //                           TextSpan(
// //                             text: ' (${item['quantity']})',
// //                             style: TextStyle(
// //                               fontFamily: 'Roboto',
// //                               color: Theme.of(
// //                                 context,
// //                               ).textTheme.bodyMedium?.color?.withOpacity(0.7),
// //                               decoration:
// //                                   item['isPurchased']
// //                                       ? TextDecoration.lineThrough
// //                                       : TextDecoration.none,
// //                             ),
// //                           ),
// //                       ],
// //                     ),
// //                   ),
// //                   subtitle: Text(
// //                     item['category'],
// //                     style: TextStyle(
// //                       fontFamily: 'Roboto',
// //                       color: Theme.of(
// //                         context,
// //                       ).textTheme.bodyMedium?.color?.withOpacity(0.6),
// //                     ),
// //                   ),
// //                   trailing: IconButton(
// //                     icon: Icon(
// //                       Icons.delete,
// //                       color: Theme.of(context).iconTheme.color,
// //                     ),
// //                     onPressed:
// //                         () => _groceryController.removeItem(item['name']),
// //                   ),
// //                 ),
// //               );
// //             },
// //           );
// //         }),
// //       ),
// //       floatingActionButton: FloatingActionButton(
// //         onPressed: () {
// //           _showAddItemDialog(context);
// //         },
// //         backgroundColor: Theme.of(
// //           context,
// //         ).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
// //         foregroundColor: Theme.of(
// //           context,
// //         ).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
// //         child: const Icon(Icons.add),
// //       ),
// //     );
// //   }

// //   void _showAddItemDialog(BuildContext context) {
// //     final TextEditingController _nameController = TextEditingController();
// //     final TextEditingController _quantityController = TextEditingController();
// //     String _selectedCategory = 'Uncategorized';
// //     final List<String> categories = [
// //       'Uncategorized',
// //       'Produce',
// //       'Dairy',
// //       'Meat',
// //       'Grains',
// //       'Snacks',
// //     ];

// //     showDialog(
// //       context: context,
// //       builder:
// //           (context) => AlertDialog(
// //             title: Text(
// //               'Add Item',
// //               style: Theme.of(context).textTheme.titleLarge,
// //             ),
// //             content: Column(
// //               mainAxisSize: MainAxisSize.min,
// //               children: [
// //                 TextField(
// //                   controller: _nameController,
// //                   decoration: InputDecoration(
// //                     labelText: 'Item Name',
// //                     border: OutlineInputBorder(
// //                       borderRadius: BorderRadius.circular(15),
// //                     ),
// //                     labelStyle: Theme.of(context).textTheme.bodyMedium,
// //                   ),
// //                 ),
// //                 TextField(
// //                   controller: _quantityController,
// //                   decoration: InputDecoration(
// //                     labelText: 'Quantity (e.g., 2kg)',
// //                     border: OutlineInputBorder(
// //                       borderRadius: BorderRadius.circular(15),
// //                     ),
// //                     labelStyle: Theme.of(context).textTheme.bodyMedium,
// //                   ),
// //                 ),
// //                 DropdownButton<String>(
// //                   value: _selectedCategory,
// //                   items:
// //                       categories.map((String value) {
// //                         return DropdownMenuItem<String>(
// //                           value: value,
// //                           child: Text(
// //                             value,
// //                             style: Theme.of(context).textTheme.bodyMedium,
// //                           ),
// //                         );
// //                       }).toList(),
// //                   onChanged: (value) {
// //                     setState(() {
// //                       _selectedCategory = value!;
// //                     });
// //                   },
// //                   dropdownColor: Theme.of(context).cardColor,
// //                 ),
// //               ],
// //             ),
// //             actions: [
// //               TextButton(
// //                 onPressed: () => Navigator.pop(context),
// //                 child: Text(
// //                   'Cancel',
// //                   style: TextStyle(
// //                     color: Theme.of(context).textTheme.bodyMedium?.color,
// //                   ),
// //                 ),
// //               ),
// //               TextButton(
// //                 onPressed: () {
// //                   if (_nameController.text.isNotEmpty) {
// //                     _groceryController.addItems([
// //                       {
// //                         'name': _nameController.text.trim(),
// //                         'quantity': _quantityController.text.trim(),
// //                         'category': _selectedCategory,
// //                         'isPurchased': false,
// //                       },
// //                     ]);
// //                     Navigator.pop(context);
// //                   }
// //                 },
// //                 child: Text(
// //                   'Add',
// //                   style: TextStyle(
// //                     color: Theme.of(context).textTheme.bodyMedium?.color,
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //     );
// //   }
// // }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme_provider.dart';
import 'grocery_storage.dart';

class GroceryController extends GetxController {
  var groceryList = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadFromStorage();
  }

  void addItem(String item) {
    if (item.isNotEmpty && !groceryList.any((e) => e['name'] == item)) {
      groceryList.add({"name": item, "checked": false});
      GroceryStorage().addIngredients([item]);
    }
  }

  void addItems(List<String> items) {
    bool added = false;
    for (var item in items) {
      if (item.isNotEmpty && !groceryList.any((e) => e['name'] == item)) {
        groceryList.add({"name": item, "checked": false});
        added = true;
      }
    }
    if (added) {
      groceryList.refresh();
      GroceryStorage().addIngredients(items);
    }
  }

  void toggleCheck(int index) {
    groceryList[index]["checked"] = !groceryList[index]["checked"];
    groceryList.refresh();
  }

  void removeItem(int index) async {
    final removed = groceryList.removeAt(index);
    final existing = await GroceryStorage().getIngredients();
    existing.remove(removed["name"]);
    await GroceryStorage.overwriteIngredients(existing);
  }

  void clearAll() async {
    groceryList.clear();
    await GroceryStorage().clearIngredients();
  }

  void loadFromStorage() async {
    final savedItems = await GroceryStorage().getIngredients();
    for (var item in savedItems) {
      if (!groceryList.any((e) => e['name'] == item)) {
        groceryList.add({"name": item, "checked": false});
      }
    }
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
                builder:
                    (_) => AlertDialog(
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
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            "Clear",
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
              );
              if (confirm == true) controller.clearAll();
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
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (val) {
                controller.addItem(val.trim());
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
            onPressed: () {
              controller.addItem(input.text.trim());
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
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.6),
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
              key: ValueKey(item["name"]),
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
                      color:
                          item["checked"]
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
