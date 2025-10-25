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
