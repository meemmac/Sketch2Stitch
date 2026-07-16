import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: InventoryScreen(),
));

class ProductColorVariant {
  String colorName;
  String imagePath;
  bool isAsset;

  ProductColorVariant({
    required this.colorName,
    required this.imagePath,
    this.isAsset = false,
  });
}

class InventoryItem {
  String name;
  String category; // "Fabric" or "Accessory"
  String materialType; // Cotton, Silk etc.
  String sku;
  double price;
  int stock;
  String description;
  List<ProductColorVariant> variants;

  // Detailed Care Options
  bool canWash;
  bool canBleach;
  bool canDryClean;
  bool canTumbleDry;
  String ironLevel; // Low, Medium, High

  InventoryItem({
    required this.name,
    required this.category,
    required this.materialType,
    required this.sku,
    required this.price,
    required this.stock,
    required this.description,
    required this.variants,
    this.canWash = true,
    this.canBleach = false,
    this.canDryClean = true,
    this.canTumbleDry = true,
    this.ironLevel = "Medium",
  });

  // Helper to get first image
  String get mainImagePath => variants.isNotEmpty ? variants.first.imagePath : "";
  bool get mainIsAsset => variants.isNotEmpty ? variants.first.isAsset : false;
  List<String> get colorNames => variants.map((v) => v.colorName).toList();
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  final List<InventoryItem> items = <InventoryItem>[
    InventoryItem(
      name: "Premium Egyptian Cotton",
      category: "Fabric",
      materialType: "Cotton",
      sku: "COT-001",
      price: 650,
      stock: 45,
      description: "Soft, breathable Egyptian cotton perfect for shirts.",
      variants: [
        ProductColorVariant(colorName: "White", imagePath: 'assets/images/fab.jpg', isAsset: true),
        ProductColorVariant(colorName: "Beige", imagePath: 'assets/images/fab2.jpg', isAsset: true),
      ],
      canWash: true,
      canBleach: false,
      canDryClean: true,
      canTumbleDry: true,
      ironLevel: "High",
    ),
    InventoryItem(
      name: "Golden Silk Blend",
      category: "Fabric",
      materialType: "Silk",
      sku: "SLK-002",
      price: 1800,
      stock: 12,
      description: "Luxurious silk blend with a natural sheen.",
      variants: [
        ProductColorVariant(colorName: "Gold", imagePath: 'assets/images/silk.jpg', isAsset: true),
        ProductColorVariant(colorName: "Pink", imagePath: 'assets/images/saree.jpg', isAsset: true),
      ],
      canWash: false,
      canBleach: false,
      canDryClean: true,
      canTumbleDry: false,
      ironLevel: "Low",
    ),
  ];

  Future<void> _showProductPreview(InventoryItem item) async {
    ProductColorVariant selectedVariant = item.variants.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (context, setP) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: selectedVariant.isAsset
                      ? Image.asset(selectedVariant.imagePath, height: 250, width: double.infinity, fit: BoxFit.cover)
                      : Image.file(File(selectedVariant.imagePath), height: 250, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    Text("Tk ${item.price.toInt()}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _infoBadge(item.category, Colors.blue.shade50, Colors.blue.shade800),
                    const SizedBox(width: 8),
                    if (item.category == "Fabric")
                      _infoBadge(item.materialType, Colors.green.shade50, Colors.green.shade800),
                    const SizedBox(width: 8),
                    _infoBadge("SKU: ${item.sku}", Colors.grey.shade100, Colors.grey.shade800),
                  ],
                ),
                const SizedBox(height: 20),

                // 🎨 Color Selection (Interactive)
                const Text("Select Color", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.variants.length,
                    itemBuilder: (context, index) {
                      final variant = item.variants[index];
                      final isSelected = selectedVariant == variant;
                      return GestureDetector(
                        onTap: () => setP(() => selectedVariant = variant),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green.shade800 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? Colors.green.shade800 : Colors.transparent),
                          ),
                          child: Center(
                            child: Text(
                              variant.colorName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),
                const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(item.description, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Current Stock: ${item.stock}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    _infoBadge(item.stock < 10 ? "Low Stock" : "In Stock", item.stock < 10 ? Colors.red.shade50 : Colors.green.shade50, item.stock < 10 ? Colors.red : Colors.green),
                  ],
                ),
                if (item.category == "Fabric") ...[
                  const SizedBox(height: 25),
                  const Text("Care Instructions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _careInfoRow(Icons.wash, "Machine Washable", item.canWash),
                  _careInfoRow(Icons.biotech, "Bleach Allowed", item.canBleach),
                  _careInfoRow(Icons.dry_cleaning, "Dry Clean Only", item.canDryClean),
                  _careInfoRow(Icons.settings_input_component, "Tumble Dry", item.canTumbleDry),
                  _careInfoRow(Icons.iron, "Iron Level", true, trailing: item.ironLevel),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _infoBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _careInfoRow(IconData icon, String label, bool isOk, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isOk ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isOk ? Colors.black87 : Colors.grey)),
          const Spacer(),
          Text(trailing ?? (isOk ? "Yes" : "No"), style: TextStyle(fontWeight: FontWeight.bold, color: isOk ? Colors.green.shade800 : Colors.grey)),
        ],
      ),
    );
  }

  Future<void> showItemForm({InventoryItem? item}) async {
    final name = TextEditingController(text: item?.name ?? "");
    final sku = TextEditingController(text: item?.sku ?? "");
    final price = TextEditingController(text: item?.price.toString() ?? "");
    final stock = TextEditingController(text: item?.stock.toString() ?? "");
    final desc = TextEditingController(text: item?.description ?? "");
    final matType = TextEditingController(text: item?.materialType ?? "");
    
    String category = item?.category ?? "Fabric";
    List<ProductColorVariant> workingVariants = item != null 
        ? List.from(item.variants) 
        : [ProductColorVariant(colorName: "Standard", imagePath: "", isAsset: false)];

    // Care states
    bool canWash = item?.canWash ?? true;
    bool canBleach = item?.canBleach ?? false;
    bool canDryClean = item?.canDryClean ?? true;
    bool canTumbleDry = item?.canTumbleDry ?? true;
    String ironLevel = item?.ironLevel ?? "Medium";

    await showModalBottomSheet(
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
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Text(item == null ? "Add New Item" : "Edit Item",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                
                // 🏷 Category Toggle (Fabric vs Accessory)
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeToggle("Fabric", category == "Fabric", () => setM(() => category = "Fabric")),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTypeToggle("Accessory", category == "Accessory", () => setM(() => category = "Accessory")),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // 🌈 Multi-Color Variants Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Color Variants", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                      TextButton.icon(
                        onPressed: () => setM(() => workingVariants.add(ProductColorVariant(colorName: "", imagePath: ""))),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add Color"),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                
                // Variants List
                ...workingVariants.map((variant) {
                  int idx = workingVariants.indexOf(variant);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              setM(() {
                                variant.imagePath = image.path;
                                variant.isAsset = false;
                              });
                            }
                          },
                          child: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: variant.imagePath.isEmpty
                                ? const Icon(Icons.add_a_photo, size: 20, color: Colors.green)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: variant.isAsset 
                                        ? Image.asset(variant.imagePath, fit: BoxFit.cover)
                                        : Image.file(File(variant.imagePath), fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => variant.colorName = v,
                            controller: TextEditingController(text: variant.colorName)..selection = TextSelection.fromPosition(TextPosition(offset: variant.colorName.length)),
                            decoration: const InputDecoration(hintText: "Color Name (e.g. Red)", border: InputBorder.none),
                          ),
                        ),
                        if (workingVariants.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => setM(() => workingVariants.removeAt(idx)),
                          )
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                TextField(controller: name, decoration: const InputDecoration(labelText: "Product Name (e.g. Pure Silk Saree)")),
                const SizedBox(height: 10),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: "Description")),
                
                const SizedBox(height: 10),
                TextField(controller: sku, decoration: const InputDecoration(labelText: "Product Code (SKU)")),

                if (category == "Fabric") ...[
                  const SizedBox(height: 10),
                  TextField(controller: matType, decoration: const InputDecoration(labelText: "Material Type (Cotton, Silk, etc.)")),
                ],

                Row(
                  children: [
                    Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price (Tk)"))),
                    const SizedBox(width: 15),
                    Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock Quantity"))),
                  ],
                ),

                if (category == "Fabric") ...[
                  const SizedBox(height: 25),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Care Instructions", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                  ),
                  const SizedBox(height: 10),
                  _buildCareSwitch("Machine Washable", canWash, (v) => setM(() => canWash = v)),
                  _buildCareSwitch("Bleach Allowed", canBleach, (v) => setM(() => canBleach = v)),
                  _buildCareSwitch("Dry Clean Only", canDryClean, (v) => setM(() => canDryClean = v)),
                  _buildCareSwitch("Tumble Dry", canTumbleDry, (v) => setM(() => canTumbleDry = v)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    value: ironLevel,
                    items: ["None", "Low", "Medium", "High"]
                        .map((e) => DropdownMenuItem(value: e, child: Text("Iron Level: $e")))
                        .toList(),
                    onChanged: (v) => setM(() => ironLevel = v.toString()),
                    decoration: const InputDecoration(labelText: "Ironing"),
                  ),
                ],

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      if (workingVariants.any((v) => v.imagePath.isEmpty || v.colorName.isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide color and image for all variants")));
                        return;
                      }
                      setState(() {
                        if (item == null) {
                          items.add(InventoryItem(
                            name: name.text,
                            category: category,
                            materialType: category == "Fabric" ? matType.text : "N/A",
                            sku: sku.text,
                            price: double.tryParse(price.text) ?? 0,
                            stock: int.tryParse(stock.text) ?? 0,
                            description: desc.text,
                            variants: workingVariants,
                            canWash: canWash,
                            canBleach: canBleach,
                            canDryClean: canDryClean,
                            canTumbleDry: canTumbleDry,
                            ironLevel: ironLevel,
                          ));
                        } else {
                          item.name = name.text;
                          item.category = category;
                          item.materialType = category == "Fabric" ? matType.text : "N/A";
                          item.sku = sku.text;
                          item.price = double.tryParse(price.text) ?? 0;
                          item.stock = int.tryParse(stock.text) ?? 0;
                          item.description = desc.text;
                          item.variants = workingVariants;
                          item.canWash = canWash;
                          item.canBleach = canBleach;
                          item.canDryClean = canDryClean;
                          item.canTumbleDry = canTumbleDry;
                          item.ironLevel = ironLevel;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Text(item == null ? "Publish Item" : "Save Changes",
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

  Widget _buildTypeToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.green.shade800 : Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCareSwitch(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Switch(value: value, activeColor: Colors.green.shade700, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("Retailer Inventory", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showItemForm(),
        backgroundColor: Colors.green.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Product", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: _summary("Inventory", items.length.toString(), Colors.green.shade50)),
            const SizedBox(width: 12),
            Expanded(child: _summary("Low Stock", items.where((e) => e.stock < 10).length.toString(), Colors.red.shade50)),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: "Search your products...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.6,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
              ),
              itemCount: items.where((item) =>
                item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.sku.toLowerCase().contains(_searchQuery.toLowerCase())
              ).length,
              itemBuilder: (c, i) {
                final filteredItems = items.where((item) =>
                  item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  item.sku.toLowerCase().contains(_searchQuery.toLowerCase())
                ).toList();
                return _buildProductCard(filteredItems[i]);
              },
            ),
          )
        ]),
      ),
    );
  }

  Widget _buildProductCard(InventoryItem item) {
    return GestureDetector(
      onTap: () => _showProductPreview(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.mainIsAsset
                      ? Image.asset(item.mainImagePath, fit: BoxFit.cover)
                      : Image.file(File(item.mainImagePath), fit: BoxFit.cover),
                  Positioned(
                    top: 8, right: 8,
                    child: Row(
                      children: [
                        _actionBtn(Icons.edit, Colors.blue, () => showItemForm(item: item)),
                        const SizedBox(width: 5),
                        _actionBtn(Icons.delete, Colors.red, () => setState(() => items.remove(item))),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                      child: Text("Stock: ${item.stock}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(5)),
                        child: Text(item.category == "Fabric" ? item.materialType : "Accessory", style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 5),
                      Expanded(child: Text(item.sku, style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                  const SizedBox(height: 5),
                  Text("Colors: ${item.colorNames.join(", ")}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 10)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Tk ${item.price.toInt()}", style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w900, fontSize: 15)),
                      if (item.category == "Fabric")
                        GestureDetector(
                          onTap: () => _showProductPreview(item),
                          child: Icon(Icons.info_outline, size: 16, color: Colors.green.shade300),
                        ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _summary(String t, String v, Color bg) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CountUpText(
            begin: 0,
            end: double.tryParse(v) ?? 0,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(t, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}

class CountUpText extends StatefulWidget {
  final double begin;
  final double end;
  final Duration duration;
  final TextStyle style;

  const CountUpText({
    super.key,
    required this.begin,
    required this.end,
    this.duration = const Duration(seconds: 1),
    required this.style,
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: widget.begin, end: widget.end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.end != widget.end) {
      _animation = Tween<double>(begin: oldWidget.end, end: widget.end).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.toInt().toString(),
          style: widget.style,
        );
      },
    );
  }
}
