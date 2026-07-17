import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: InventoryScreen(),
));

class ProductColorVariant {
  String colorName;
  String imagePath;
  bool isAsset;
  double price;
  int stock;

  ProductColorVariant({
    required this.colorName,
    required this.imagePath,
    this.isAsset = false,
    this.price = 0,
    this.stock = 0,
  });

  Map<String, dynamic> toMap() => {
        'colorName': colorName,
        'imagePath': imagePath,
        'isAsset': isAsset,
        'price': price,
        'stock': stock,
      };

  factory ProductColorVariant.fromMap(Map<String, dynamic> map) {
    return ProductColorVariant(
      colorName: map['colorName'] as String? ?? '',
      imagePath: map['imagePath'] as String? ?? '',
      isAsset: map['isAsset'] as bool? ?? false,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
    );
  }
}

class InventoryItem {
  String name;
  String category; // "Fabric" or "Element"
  String materialType; // Cotton, Silk etc.
  String sku;
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
    required this.description,
    required this.variants,
    this.canWash = true,
    this.canBleach = false,
    this.canDryClean = true,
    this.canTumbleDry = true,
    this.ironLevel = "Medium",
  });

  // Helpers
  String get mainImagePath => variants.isNotEmpty ? variants.first.imagePath : "";
  bool get mainIsAsset => variants.isNotEmpty ? variants.first.isAsset : false;
  List<String> get colorNames => variants.map((v) => v.colorName).toList();
  
  double get minPrice {
    if (variants.isEmpty) return 0;
    return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  }

  int get totalStock {
    if (variants.isEmpty) return 0;
    return variants.fold(0, (sum, v) => sum + v.stock);
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'materialType': materialType,
        'sku': sku,
        'description': description,
        'variants': variants.map((variant) => variant.toMap()).toList(),
        'canWash': canWash,
        'canBleach': canBleach,
        'canDryClean': canDryClean,
        'canTumbleDry': canTumbleDry,
        'ironLevel': ironLevel,
      };

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    final rawVariants = map['variants'];
    final variants = rawVariants is List
        ? rawVariants
            .whereType<Map>()
            .map((variant) => ProductColorVariant.fromMap(Map<String, dynamic>.from(variant)))
            .toList()
        : <ProductColorVariant>[];

    return InventoryItem(
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Element',
      materialType: map['materialType'] as String? ?? 'N/A',
      sku: map['sku'] as String? ?? '',
      description: map['description'] as String? ?? '',
      variants: variants,
      canWash: map['canWash'] as bool? ?? true,
      canBleach: map['canBleach'] as bool? ?? false,
      canDryClean: map['canDryClean'] as bool? ?? true,
      canTumbleDry: map['canTumbleDry'] as bool? ?? true,
      ironLevel: map['ironLevel'] as String? ?? 'Medium',
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = "";
  static const String _cacheKey = 'retailer_inventory_cache';
  int _gridAnimationSeed = 0;
  final Map<String, int> _selectedVariantIndexes = <String, int>{};

  final List<InventoryItem> items = <InventoryItem>[];

  List<InventoryItem> _seedItems() {
    return <InventoryItem>[
      InventoryItem(
        name: "Premium Egyptian Cotton",
        category: "Fabric",
        materialType: "Cotton",
        sku: "COT-001",
        description: "Soft, breathable Egyptian cotton perfect for shirts.",
        variants: [
          ProductColorVariant(colorName: "White", imagePath: 'assets/images/fab.jpg', isAsset: true, price: 650, stock: 45),
          ProductColorVariant(colorName: "Beige", imagePath: 'assets/images/fab2.jpg', isAsset: true, price: 680, stock: 30),
          ProductColorVariant(colorName: "Ivory", imagePath: 'assets/images/fab.jpg', isAsset: true, price: 720, stock: 6),
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
        description: "Luxurious silk blend with a natural sheen.",
        variants: [
          ProductColorVariant(colorName: "Gold", imagePath: 'assets/images/silk.jpg', isAsset: true, price: 1800, stock: 12),
          ProductColorVariant(colorName: "Pink", imagePath: 'assets/images/saree.jpg', isAsset: true, price: 1750, stock: 8),
          ProductColorVariant(colorName: "Emerald", imagePath: 'assets/images/gorgeous.jpg', isAsset: true, price: 1950, stock: 5),
        ],
        canWash: false,
        canBleach: false,
        canDryClean: true,
        canTumbleDry: false,
        ironLevel: "Low",
      ),
      InventoryItem(
        name: "Denim Work Shirt",
        category: "Element",
        materialType: "N/A",
        sku: "ACC-003",
        description: "Durable denim shirt with a modern fit.",
        variants: [
          ProductColorVariant(colorName: "Indigo", imagePath: 'assets/images/fab.jpg', isAsset: true, price: 920, stock: 28),
          ProductColorVariant(colorName: "Washed Blue", imagePath: 'assets/images/fabric_waves.jpg', isAsset: true, price: 980, stock: 7),
        ],
      ),
      InventoryItem(
        name: "Linen Summer Fabric",
        category: "Fabric",
        materialType: "Linen",
        sku: "LIN-004",
        description: "Lightweight linen fabric for summer wear.",
        variants: [
          ProductColorVariant(colorName: "Natural", imagePath: 'assets/images/fab2.jpg', isAsset: true, price: 1120, stock: 18),
          ProductColorVariant(colorName: "Sage", imagePath: 'assets/images/fabrics_rolled.jpg', isAsset: true, price: 1180, stock: 9),
        ],
        canWash: true,
        canBleach: false,
        canDryClean: true,
        canTumbleDry: false,
        ironLevel: "Medium",
      ),
      InventoryItem(
        name: "Printed Scarf",
        category: "Element",
        materialType: "N/A",
        sku: "SCF-005",
        description: "Light scarf with vibrant seasonal prints.",
        variants: [
          ProductColorVariant(colorName: "Multi", imagePath: 'assets/images/saree.jpg', isAsset: true, price: 380, stock: 64),
          ProductColorVariant(colorName: "Black", imagePath: 'assets/images/lace.jpg', isAsset: true, price: 420, stock: 4),
        ],
      ),
    ];
  }

  String _itemKey(InventoryItem item) {
    return item.sku.isNotEmpty ? item.sku : item.name;
  }

  ProductColorVariant? _selectedVariantFor(InventoryItem item) {
    if (item.variants.isEmpty) {
      return null;
    }

    final index = _selectedVariantIndexes[_itemKey(item)] ?? 0;
    if (index < 0 || index >= item.variants.length) {
      return item.variants.first;
    }

    return item.variants[index];
  }

  List<InventoryItem> get _filteredItems {
    final query = _searchQuery.toLowerCase();
    return items.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.sku.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  List<InventoryItem> _withHardcodedDemoValues(List<InventoryItem> loaded) {
    final seedItems = _seedItems();
    final seedsBySku = <String, InventoryItem>{
      for (final item in seedItems) item.sku: item,
    };

    final merged = loaded.isEmpty
        ? <InventoryItem>[...seedItems]
        : loaded.map((item) => seedsBySku[item.sku] ?? item).toList();
    final existingSkus = merged.map((item) => item.sku).toSet();

    for (final seed in seedItems) {
      if (!existingSkus.contains(seed.sku)) {
        merged.add(seed);
      }
    }

    return merged;
  }

  Future<void> _loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        items
          ..clear()
          ..addAll(_seedItems());
      });
      await _saveInventory();
      return;
    }

    final decoded = jsonDecode(raw);
    final loaded = decoded is List
        ? decoded
            .whereType<Map>()
            .map((entry) => InventoryItem.fromMap(Map<String, dynamic>.from(entry)))
            .toList()
        : _seedItems();
    final inventory = _withHardcodedDemoValues(loaded);

    if (!mounted) {
      return;
    }
    setState(() {
      items
        ..clear()
        ..addAll(inventory);
    });
    await _saveInventory();
  }

  Future<void> _saveInventory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
  }

  void _animateToNewestItem() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showProductPreview(InventoryItem item) async {
    if (item.variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This item has no color variants yet")),
      );
      return;
    }

    ProductColorVariant selectedVariant = _selectedVariantFor(item) ?? item.variants.first;

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
                    Text("Tk ${selectedVariant.price.toInt()}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
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
                        onTap: () {
                          setState(() {
                            _selectedVariantIndexes[_itemKey(item)] = index;
                          });
                          setP(() => selectedVariant = variant);
                        },
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
                    Text("Stock for ${selectedVariant.colorName}: ${selectedVariant.stock}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    _infoBadge(selectedVariant.stock < 10 ? "Low Stock" : "In Stock", selectedVariant.stock < 10 ? Colors.red.shade50 : Colors.green.shade50, selectedVariant.stock < 10 ? Colors.red : Colors.green),
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

  Widget _buildColorPicker(ProductColorVariant variant, StateSetter setM) {
    final List<Map<String, dynamic>> basicColors = [
      {'name': 'Red', 'color': Colors.red},
      {'name': 'Pink', 'color': Colors.pink},
      {'name': 'Purple', 'color': Colors.purple},
      {'name': 'Deep Purple', 'color': Colors.deepPurple},
      {'name': 'Indigo', 'color': Colors.indigo},
      {'name': 'Blue', 'color': Colors.blue},
      {'name': 'Light Blue', 'color': Colors.lightBlue},
      {'name': 'Cyan', 'color': Colors.cyan},
      {'name': 'Teal', 'color': Colors.teal},
      {'name': 'Green', 'color': Colors.green},
      {'name': 'Light Green', 'color': Colors.lightGreen},
      {'name': 'Lime', 'color': Colors.lime},
      {'name': 'Yellow', 'color': Colors.yellow},
      {'name': 'Amber', 'color': Colors.amber},
      {'name': 'Orange', 'color': Colors.orange},
      {'name': 'Deep Orange', 'color': Colors.deepOrange},
      {'name': 'Brown', 'color': Colors.brown},
      {'name': 'Grey', 'color': Colors.grey},
      {'name': 'Blue Grey', 'color': Colors.blueGrey},
      {'name': 'Black', 'color': Colors.black},
      {'name': 'White', 'color': Colors.white},
    ];

    return IconButton(
      icon: Icon(Icons.palette_outlined, color: Colors.green.shade800),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Select Color"),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: basicColors.length,
                itemBuilder: (context, index) {
                  final colorData = basicColors[index];
                  return GestureDetector(
                    onTap: () {
                      setM(() {
                        variant.colorName = colorData['name'];
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorData['color'],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> showItemForm({InventoryItem? item}) async {
    final name = TextEditingController(text: item?.name ?? "");
    final sku = TextEditingController(text: item?.sku ?? "");
    final desc = TextEditingController(text: item?.description ?? "");
    final matType = TextEditingController(text: item?.materialType ?? "");
    
    String category = item?.category ?? "Fabric";
    List<ProductColorVariant> workingVariants = item != null 
        ? List.from(item.variants) 
        : [ProductColorVariant(colorName: "", imagePath: "", isAsset: false, price: 0, stock: 0)];

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
                
                // 🏷 Category Toggle (Fabric vs Element) - Only shown for NEW items
                if (item == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeToggle("Fabric", category == "Fabric", () => setM(() => category = "Fabric")),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTypeToggle("Element", category == "Element", () => setM(() => category = "Element")),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                ],

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
                  bool isExistingVariant = item != null && idx < item.variants.length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      onChanged: (v) => variant.colorName = v,
                                      controller: TextEditingController(text: variant.colorName)..selection = TextSelection.fromPosition(TextPosition(offset: variant.colorName.length)),
                                      decoration: const InputDecoration(hintText: "Color Name (e.g. Red)", border: InputBorder.none),
                                    ),
                                  ),
                                  _buildColorPicker(variant, setM),
                                ],
                              ),
                            ),
                            if (workingVariants.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => setM(() => workingVariants.removeAt(idx)),
                              )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (v) => variant.price = double.tryParse(v) ?? 0,
                                controller: TextEditingController(text: variant.price > 0 ? variant.price.toString() : "")..selection = TextSelection.fromPosition(TextPosition(offset: (variant.price > 0 ? variant.price.toString() : "").length)),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: "Price (Tk)", prefixText: "Tk "),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: TextField(
                                enabled: !isExistingVariant, // Locked for existing variants
                                onChanged: (v) => variant.stock = int.tryParse(v) ?? 0,
                                controller: TextEditingController(text: variant.stock > 0 ? variant.stock.toString() : "")..selection = TextSelection.fromPosition(TextPosition(offset: (variant.stock > 0 ? variant.stock.toString() : "").length)),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Stock",
                                  helperText: isExistingVariant ? "Locked" : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                TextField(controller: name, decoration: const InputDecoration(labelText: "Product Name (e.g. Pure Silk Saree)")),
                const SizedBox(height: 10),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: "Description")),
                
                const SizedBox(height: 10),
                TextField(
                  controller: sku,
                  enabled: item == null,
                  decoration: InputDecoration(
                    labelText: "Product Code (SKU)",
                    helperText: item == null ? null : "SKU cannot be changed after creation",
                  ),
                ),

                if (category == "Fabric") ...[
                  const SizedBox(height: 10),
                  TextField(controller: matType, decoration: const InputDecoration(labelText: "Material Type (Cotton, Silk, etc.)")),
                ],

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
                    initialValue: ironLevel,
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
                    onPressed: () async {
                      if (workingVariants.any((v) => v.imagePath.isEmpty || v.colorName.isEmpty || v.price <= 0 || v.stock <= 0)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide color, image, price and stock for all variants")));
                        return;
                      }
                      final savedItem = InventoryItem(
                        name: name.text,
                        category: category,
                        materialType: category == "Fabric" ? matType.text : "N/A",
                        sku: sku.text,
                        description: desc.text,
                        variants: workingVariants,
                        canWash: canWash,
                        canBleach: canBleach,
                        canDryClean: canDryClean,
                        canTumbleDry: canTumbleDry,
                        ironLevel: ironLevel,
                      );
                      setState(() {
                        if (item == null) {
                          items.add(savedItem);
                        } else {
                          item.name = savedItem.name;
                          item.category = savedItem.category;
                          item.materialType = savedItem.materialType;
                          item.sku = savedItem.sku;
                          item.description = savedItem.description;
                          item.variants = savedItem.variants;
                          item.canWash = savedItem.canWash;
                          item.canBleach = savedItem.canBleach;
                          item.canDryClean = savedItem.canDryClean;
                          item.canTumbleDry = savedItem.canTumbleDry;
                          item.ironLevel = savedItem.ironLevel;
                        }
                        _gridAnimationSeed++;
                      });
                      await _saveInventory();
                      if (item == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _animateToNewestItem());
                      }
                      if (!mounted) {
                        return;
                      }
                      Navigator.of(context).pop();
                    },
                    child: Text(item == null ? "Add Item" : "Save Changes",
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
        Switch(value: value, activeThumbColor: Colors.green.shade700, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
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
          SizedBox(
            width: double.infinity,
            child: _summary(
              "Inventory",
              items.length.toString(),
              "total items",
              Colors.green.shade50,
            ),
          ),
          const SizedBox(height: 14),
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
            child: filteredItems.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty ? "No items in inventory yet" : "No products match your search",
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.6,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (c, i) {
                      return _buildAnimatedGridCard(filteredItems[i], i);
                    },
                  ),
          )
        ]),
      ),
    );
  }

  Widget _buildAnimatedGridCard(InventoryItem item, int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${item.sku}-$_gridAnimationSeed'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: Transform.scale(
              scale: 0.96 + (0.04 * value),
              child: child,
            ),
          ),
        );
      },
      child: _buildProductCard(item),
    );
  }

  Widget _buildProductCard(InventoryItem item) {
    final selectedVariant = _selectedVariantFor(item);
    final variantIndex = selectedVariant == null ? -1 : item.variants.indexOf(selectedVariant);

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
                  _buildVariantImage(selectedVariant),
                  Positioned(
                    top: 8, right: 8,
                    child: Row(
                      children: [
                        _actionBtn(Icons.edit, Colors.blue, () => showItemForm(item: item)),
                        const SizedBox(width: 5),
                        _actionBtn(Icons.delete, Colors.red, () async {
                          setState(() {
                            items.remove(item);
                            _gridAnimationSeed++;
                          });
                          await _saveInventory();
                        }),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        selectedVariant == null
                            ? "No stock"
                            : "${selectedVariant.colorName}: ${selectedVariant.stock}",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(5)),
                        child: Text(item.category == "Fabric" ? item.materialType : "Element", style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 5),
                      Expanded(child: Text(item.sku, style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 30,
                    child: item.variants.isEmpty
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("No colors", style: TextStyle(color: Colors.black45, fontSize: 10)),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.variants.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final variant = item.variants[index];
                              final isSelected = index == variantIndex;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedVariantIndexes[_itemKey(item)] = index;
                                  });
                                },
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 82),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.green.shade800 : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? Colors.green.shade800 : Colors.green.shade100,
                                    ),
                                  ),
                                  child: Text(
                                    variant.colorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.green.shade900,
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedVariant == null ? "Tk 0" : "Tk ${selectedVariant.price.toInt()}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Total: ${item.totalStock}",
                        style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
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

  Widget _buildVariantImage(ProductColorVariant? variant) {
    if (variant == null || variant.imagePath.isEmpty) {
      return Container(
        color: Colors.green.shade50,
        child: Icon(Icons.image_not_supported_outlined, color: Colors.green.shade200),
      );
    }

    return variant.isAsset
        ? Image.asset(variant.imagePath, fit: BoxFit.cover)
        : Image.file(File(variant.imagePath), fit: BoxFit.cover);
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

  Widget _summary(String t, String v, String subtitle, Color bg, {String? detail}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CountUpText(
            begin: 0,
            end: double.tryParse(v) ?? 0,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(t, style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black45, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ],
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
