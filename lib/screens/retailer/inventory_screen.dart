import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: InventoryScreen(),
));

class InventoryItem {
  String name;
  String category;
  String sku;
  double price;
  int stock;
  String careLevel;
  List<String> colors;
  String imagePath;

  InventoryItem({
    required this.name,
    required this.category,
    required this.sku,
    required this.price,
    required this.stock,
    required this.careLevel,
    required this.colors,
    required this.imagePath,
  });
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const productImages = [
    'assets/images/gorgette.jpg',
    'assets/images/gorgeous.jpg',
    'assets/images/fab.jpg',
    'assets/images/fab2.jpg',
    'assets/images/silk.jpg',
    'assets/images/lace.jpg',
    'assets/images/embroidery.jpg',
    'assets/images/textile.jpg',
  ];

  final items = <InventoryItem>[
    InventoryItem(
      name: "Georgette Fabric",
      category: "Fabric",
      sku: "TSH-001",
      price: 240,
      stock: 45,
      careLevel: "Medium Care",
      colors: ["White", "Pink"],
      imagePath: 'assets/images/gorgette.jpg',
    ),
    InventoryItem(
      name: "Silk Blend",
      category: "Fabric",
      sku: "SLK-002",
      price: 550,
      stock: 8,
      careLevel: "Delicate",
      colors: ["Gold"],
      imagePath: 'assets/images/silk.jpg',
    ),
  ];

  void showItemForm({InventoryItem? item}) {
    final name = TextEditingController(text: item?.name ?? "");
    final sku = TextEditingController(text: item?.sku ?? "");
    final price = TextEditingController(text: item?.price.toString() ?? "");
    final stock = TextEditingController(text: item?.stock.toString() ?? "");
    String category = item?.category ?? "Fabric";
    String care = item?.careLevel ?? "Low Care";
    String selectedImage = item?.imagePath ?? productImages.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (c, setM) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(item == null ? "Add Inventory Item" : "Edit Inventory Item",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                
                // 🖼 Image Selection Grid
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Select Product Image",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                ),
                const SizedBox(height: 15),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: productImages.length,
                  itemBuilder: (context, index) {
                    final img = productImages[index];
                    final isSelected = selectedImage == img;
                    return GestureDetector(
                      onTap: () => setM(() => selectedImage = img),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.green.shade700 : Colors.grey.shade200,
                            width: isSelected ? 3 : 1,
                          ),
                          image: DecorationImage(image: AssetImage(img), fit: BoxFit.cover),
                        ),
                        child: isSelected
                            ? const Center(child: Icon(Icons.check_circle, color: Colors.white))
                            : null,
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                TextField(controller: name, decoration: const InputDecoration(labelText: "Item Name")),
                Row(
                  children: [
                    Expanded(child: TextField(controller: sku, decoration: const InputDecoration(labelText: "SKU"))),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField(
                        value: category,
                        items: ["Fabric", "Design Element", "Accessory"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setM(() => category = v.toString()),
                        decoration: const InputDecoration(labelText: "Category"),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Price (₹)")),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                          controller: stock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Stock")),
                    ),
                  ],
                ),
                DropdownButtonFormField(
                  value: care,
                  items: ["Low Care", "Medium Care", "High Care", "Delicate", "Dry Clean Only"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setM(() => care = v.toString()),
                  decoration: const InputDecoration(labelText: "Care Level"),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      setState(() {
                        if (item == null) {
                          items.add(InventoryItem(
                            name: name.text,
                            category: category,
                            sku: sku.text,
                            price: double.tryParse(price.text) ?? 0,
                            stock: int.tryParse(stock.text) ?? 0,
                            careLevel: care,
                            colors: ["White"],
                            imagePath: selectedImage,
                          ));
                        } else {
                          item.name = name.text;
                          item.category = category;
                          item.sku = sku.text;
                          item.price = double.tryParse(price.text) ?? 0;
                          item.stock = int.tryParse(stock.text) ?? 0;
                          item.careLevel = care;
                          item.imagePath = selectedImage;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Text(item == null ? "Add Item" : "Update Item",
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("Inventory", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showItemForm(),
        backgroundColor: Colors.green.shade800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: _summary("Total Items", items.length.toString(), Colors.blue.shade50)),
            const SizedBox(width: 12),
            Expanded(
                child: _summary("Low Stock", items.where((e) => e.stock < 10).length.toString(),
                    Colors.orange.shade50)),
          ]),
          const SizedBox(height: 20),
          TextField(
              decoration: InputDecoration(
            hintText: "Search products...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          )),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
              ),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final item = items[i];
                return _buildProductCard(item);
              },
            ),
          )
        ]),
      ),
    );
  }

  Widget _buildProductCard(InventoryItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(item.imagePath, fit: BoxFit.cover),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      _actionBtn(Icons.edit, Colors.blue, () => showItemForm(item: item)),
                      const SizedBox(width: 5),
                      _actionBtn(Icons.delete, Colors.red, () {
                        setState(() => items.remove(item));
                      }),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Qty: ${item.stock}",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  item.category,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  "₹${item.price}",
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _summary(String t, String v, Color bg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(t, style: TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }
}
