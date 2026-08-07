import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/services/auth_service.dart';
import 'package:sketch2stitch/services/inventory_service.dart';
import '../../widgets/video_preview_player.dart';

class ProductColorVariant {
  String colorName;
  List<String> imagePaths;
  List<String> videoPaths;
  bool isAsset;
  double price;
  int stock;

  ProductColorVariant({
    required this.colorName,
    required this.imagePaths,
    required this.videoPaths,
    this.isAsset = false,
    this.price = 0,
    this.stock = 0,
  });
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = "";
  final Map<String, int> _selectedVariantIndexes = <String, int>{};
  
  final InventoryService _inventoryService = InventoryService();
  final AuthService _authService = AuthService();
  String? _retailerId;

  static const List<String> _commonMaterials = <String>[
    "Cotton", "Linen", "Silk", "Wool", "Cashmere", "Viscose",
    "Polyester", "Nylon", "Spandex (Lycra/Elastane)", "Khadi",
    "Muslin", "Jamdani",
  ];

  @override
  void initState() {
    super.initState();
    _retailerId = _authService.currentUser?.uid;
  }

  String _itemKey(Product item) => item.id;

  ColorOption? _selectedVariantFor(Product item) {
    if (item.colorOptions.isEmpty) return null;
    final index = _selectedVariantIndexes[_itemKey(item)] ?? 0;
    if (index < 0 || index >= item.colorOptions.length) {
      return item.colorOptions.first;
    }
    return item.colorOptions[index];
  }

  bool _hasLowStockColor(Product item) {
    return item.colorOptions.any((variant) => variant.stock < 5);
  }

  String _lowStockTextFor(Product item) {
    final lowStockVariants = item.colorOptions
        .where((variant) => variant.stock < 5)
        .toList();

    return "Low stock: ${lowStockVariants.map((v) => "${v.stock} ${v.color}").join(", ")}";
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── UI MAPPING HELPERS ───────────────────────────────────────────────────

  List<MaterialBlend> _initialMaterialBlendsFor(Product? item) {
    if (item == null || item.materialType.isEmpty) {
      return [MaterialBlend(type: "", blend: 0)];
    }
    return item.materialType.map((m) => MaterialBlend(type: m.type, blend: m.blend)).toList();
  }

  List<ProductColorVariant> _initialVariantsFor(Product? item) {
    if (item == null || item.colorOptions.isEmpty) {
      return [ProductColorVariant(colorName: "", imagePaths: [], videoPaths: [], price: 0, stock: 0)];
    }
    return item.colorOptions.map((v) => ProductColorVariant(
      colorName: v.color,
      imagePaths: v.images,
      videoPaths: v.videos,
      isAsset: v.images.any((p) => p.startsWith('assets/')),
      price: v.price,
      stock: v.stock,
    )).toList();
  }

  // ─── FORM ────────────────────────────────────────────────────────────────

  Future<void> showItemForm({Product? item}) async {
    final name = TextEditingController(text: item?.productName ?? "");
    final sku = TextEditingController(text: item?.productCode ?? "");
    final desc = TextEditingController(text: item?.description ?? "");

    String category = item?.category ?? "Fabric";
    List<ProductColorVariant> workingVariants = _initialVariantsFor(item);
    List<MaterialBlend> workingBlends = _initialMaterialBlendsFor(item);

    bool canWash = item?.careSymbol.contains("Washable") ?? true;
    bool canBleach = item?.careSymbol.contains("Bleach Allowed") ?? false;
    bool canDryClean = item?.careSymbol.contains("Dry Clean Only") ?? true;
    bool canTumbleDry = item?.careSymbol.contains("Tumble Dry") ?? true;
    String ironLevel = item?.careSymbol.firstWhere((s) => s.startsWith("Iron:"), orElse: () => "Iron: Medium").replaceFirst("Iron: ", "") ?? "Medium";

    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (c, setM) {
          if (isSaving) {
            return Container(
              height: 300,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.92,
            minChildSize: 0.25,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                    Text(item == null ? "Add New Item" : "Edit Item", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 25),

                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: "Category",
                        prefixIcon: const Icon(Icons.category_outlined),
                        filled: true, fillColor: Colors.green.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                      items: ["Fabric", "Element"].map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (v) => setM(() => category = v!),
                    ),
                    const SizedBox(height: 25),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Color Variants", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                        TextButton.icon(
                          onPressed: () => setM(() => workingVariants.add(ProductColorVariant(colorName: "", imagePaths: [], videoPaths: []))),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Color"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...workingVariants.map((variant) {
                      int idx = workingVariants.indexOf(variant);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final List<XFile> medias = await _picker.pickMultipleMedia();
                                    if (medias.isNotEmpty) {
                                      setM(() {
                                        variant.isAsset = false;
                                        for (var file in medias) {
                                          final path = file.path.toLowerCase();
                                          if (path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi')) {
                                            variant.videoPaths.add(file.path);
                                          } else {
                                            variant.imagePaths.add(file.path);
                                          }
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade100)),
                                    child: const Icon(Icons.collections, size: 30, color: Colors.green),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ...variant.imagePaths.map((path) => _buildMediaThumbnail(path, true, variant.isAsset, () => setM(() => variant.imagePaths.remove(path)))),
                                        ...variant.videoPaths.map((path) => _buildMediaThumbnail(path, false, variant.isAsset, () => setM(() => variant.videoPaths.remove(path)))),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    onChanged: (v) => variant.colorName = v,
                                    controller: TextEditingController(text: variant.colorName)..selection = TextSelection.fromPosition(TextPosition(offset: variant.colorName.length)),
                                    decoration: const InputDecoration(hintText: "Color", border: InputBorder.none, isDense: true),
                                  ),
                                ),
                                if (workingVariants.length > 1)
                                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setM(() => workingVariants.removeAt(idx))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: TextField(
                                  onChanged: (v) => variant.price = double.tryParse(v) ?? 0,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: "Price (Tk)", prefixText: "Tk "),
                                  controller: TextEditingController(text: variant.price > 0 ? variant.price.toString() : "")..selection = TextSelection.fromPosition(TextPosition(offset: (variant.price > 0 ? variant.price.toString() : "").length)),
                                )),
                                const SizedBox(width: 15),
                                Expanded(child: TextField(
                                  onChanged: (v) => variant.stock = int.tryParse(v) ?? 0,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: "Stock"),
                                  controller: TextEditingController(text: variant.stock > 0 ? variant.stock.toString() : "")..selection = TextSelection.fromPosition(TextPosition(offset: (variant.stock > 0 ? variant.stock.toString() : "").length)),
                                )),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    TextField(controller: name, decoration: const InputDecoration(labelText: "Product Name")),
                    const SizedBox(height: 10),
                    TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: "Description")),
                    const SizedBox(height: 10),
                    TextField(controller: sku, decoration: const InputDecoration(labelText: "Product Code (SKU)")),

                    if (category == "Fabric") ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Material Composition", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                          TextButton.icon(
                            onPressed: () => setM(() => workingBlends.add(MaterialBlend(type: "", blend: 0))),
                            icon: const Icon(Icons.add, size: 18), label: const Text("Add Material"),
                          ),
                        ],
                      ),
                      ...workingBlends.asMap().entries.map((e) => _buildMaterialBlendRow(e.value, e.key, workingBlends, setM)),
                      const SizedBox(height: 25),
                      Text("Care Instructions", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                      _buildCareSwitch("Machine Washable", canWash, (v) => setM(() => canWash = v)),
                      _buildCareSwitch("Bleach Allowed", canBleach, (v) => setM(() => canBleach = v)),
                      _buildCareSwitch("Dry Clean Only", canDryClean, (v) => setM(() => canDryClean = v)),
                      _buildCareSwitch("Tumble Dry", canTumbleDry, (v) => setM(() => canTumbleDry = v)),
                      DropdownButtonFormField(
                        value: ironLevel,
                        items: ["None", "Low", "Medium", "High"].map((e) => DropdownMenuItem(value: e, child: Text("Iron Level: $e"))).toList(),
                        onChanged: (v) => setM(() => ironLevel = v.toString()),
                        decoration: const InputDecoration(labelText: "Ironing"),
                      ),
                    ],

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        onPressed: () async {
                          if (_retailerId == null) return;
                          setM(() => isSaving = true);
                          try {
                            List<ColorOption> finalColorOptions = [];
                            for (int i = 0; i < workingVariants.length; i++) {
                              final v = workingVariants[i];
                              final imageUrls = await _inventoryService.uploadMedia(v.imagePaths, folder: 'products/images');
                              final videoUrls = await _inventoryService.uploadMedia(v.videoPaths, folder: 'products/videos');
                              finalColorOptions.add(ColorOption(
                                optionId: i + 1,
                                color: v.colorName,
                                images: imageUrls,
                                videos: videoUrls,
                                price: v.price,
                                stock: v.stock,
                              ));
                            }

                            List<String> careSymbols = [];
                            if (canWash) careSymbols.add("Washable");
                            if (canBleach) careSymbols.add("Bleach Allowed");
                            if (canDryClean) careSymbols.add("Dry Clean Only");
                            if (canTumbleDry) careSymbols.add("Tumble Dry");
                            careSymbols.add("Iron: $ironLevel");

                            final product = Product(
                              id: item?.id ?? "",
                              retailerId: _retailerId!,
                              productName: name.text,
                              category: category,
                              productCode: sku.text,
                              materialType: category == "Fabric" ? workingBlends.where((b) => b.type.isNotEmpty).toList() : [],
                              colorOptions: finalColorOptions,
                              description: desc.text,
                              careSymbol: careSymbols,
                            );

                            if (item == null) {
                              await _inventoryService.createProduct(product.toJson());
                            } else {
                              await _inventoryService.updateProduct(item.id, product.toJson());
                            }
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            debugPrint("Error saving product: $e");
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                            setM(() => isSaving = false);
                          }
                        },
                        child: Text(item == null ? "Add Item" : "Save Changes", style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── WIDGETS ─────────────────────────────────────────────────────────────

  Widget _buildMediaThumbnail(String path, bool isImage, bool isAsset, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8), width: 50, height: 50,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: path.startsWith('http') 
              ? Image.network(path, fit: BoxFit.cover)
              : isImage 
                ? (isAsset ? Image.asset(path, fit: BoxFit.cover) : Image.file(File(path), fit: BoxFit.cover))
                : Container(color: Colors.black87, child: const Icon(Icons.videocam, color: Colors.white, size: 20)),
          ),
        ),
        Positioned(top: 0, right: 8, child: GestureDetector(onTap: onRemove, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 10, color: Colors.white)))),
      ],
    );
  }

  Widget _buildMaterialBlendRow(MaterialBlend blend, int index, List<MaterialBlend> blends, StateSetter setM) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(flex: 3, child: TextField(
            controller: TextEditingController(text: blend.type)..selection = TextSelection.fromPosition(TextPosition(offset: blend.type.length)),
            onChanged: (v) => setM(() => blends[index] = MaterialBlend(type: v, blend: blend.blend)),
            decoration: InputDecoration(
              labelText: "Material",
              suffixIcon: PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (v) => setM(() {
                  // Actually update the object in the list
                  blends[index] = MaterialBlend(type: v, blend: blend.blend);
                }),
                itemBuilder: (c) => _commonMaterials.map((m) => PopupMenuItem(value: m, child: Text(m))).toList(),
              ),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: TextField(
            keyboardType: TextInputType.number,
            onChanged: (v) => blends[index] = MaterialBlend(type: blend.type, blend: double.tryParse(v) ?? 0),
            decoration: const InputDecoration(labelText: "Blend %"),
          )),
          if (blends.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setM(() => blends.removeAt(index))),
        ],
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
    if (_retailerId == null) return const Scaffold(body: Center(child: Text("Please login to see inventory")));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(title: const Text("Retailer Inventory", style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showItemForm(), backgroundColor: Colors.green.shade800, icon: const Icon(Icons.add, color: Colors.white), label: const Text("Add Product", style: TextStyle(color: Colors.white))),
      body: StreamBuilder<List<Product>>(
        stream: _inventoryService.streamRetailerProducts(_retailerId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          final items = snapshot.data ?? [];
          final filteredItems = items.where((i) => i.productName.toLowerCase().contains(_searchQuery.toLowerCase()) || i.productCode.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _inventorySummary(items.length),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(hintText: "Search your products...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: filteredItems.isEmpty
                    ? const Center(child: Text("No products found"))
                    : GridView.builder(
                        controller: _scrollController,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.55, mainAxisSpacing: 15, crossAxisSpacing: 15),
                        itemCount: filteredItems.length,
                        itemBuilder: (c, i) => _buildProductCard(filteredItems[i]),
                      ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildProductCard(Product item) {
    final selectedVariant = _selectedVariantFor(item);
    final hasLowStock = _hasLowStockColor(item);

    return GestureDetector(
      onTap: () => _showProductPreview(item),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildVariantImage(selectedVariant),
                  Positioned(top: 8, right: 8, child: Row(children: [
                    _actionBtn(Icons.edit, Colors.blue, () => showItemForm(item: item)),
                    const SizedBox(width: 5),
                    _actionBtn(Icons.delete, Colors.red, () async {
                      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text("Delete Product?"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete"))]));
                      if (confirm == true) await _inventoryService.deleteProduct(item.id);
                    }),
                  ])),
                  Positioned(bottom: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)), child: Text("${selectedVariant?.color ?? 'N/A'}: ${selectedVariant?.stock ?? 0}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(5)), child: Text(item.category, style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 5),
                    Expanded(child: Text(item.productCode, style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.colorOptions.length,
                      separatorBuilder: (_, ___) => const SizedBox(width: 6),
                      itemBuilder: (c, idx) {
                        final v = item.colorOptions[idx];
                        final isSelected = selectedVariant == v;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedVariantIndexes[item.id] = idx),
                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: isSelected ? Colors.green.shade800 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(v.color, style: TextStyle(color: isSelected ? Colors.white : Colors.green.shade900, fontSize: 10, fontWeight: FontWeight.bold))),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasLowStock) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(7)), child: Text(_lowStockTextFor(item), style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  const SizedBox(height: 8),
                  Text("Tk ${selectedVariant?.price.toInt() ?? 0}", style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantImage(ColorOption? variant) {
    if (variant == null || variant.images.isEmpty) return Container(color: Colors.green.shade50, child: Icon(Icons.image_not_supported_outlined, color: Colors.green.shade200));
    final path = variant.images.first;
    if (path.startsWith('http')) return Image.network(path, fit: BoxFit.cover);
    if (path.startsWith('assets/')) return Image.asset(path, fit: BoxFit.cover);
    return Image.file(File(path), fit: BoxFit.cover);
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle), child: Icon(icon, size: 14, color: color)));
  }

  Widget _inventorySummary(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.inventory_2_outlined, size: 18, color: Colors.green.shade800),
        const SizedBox(width: 8),
        Text("$count", style: TextStyle(color: Colors.green.shade900, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        const Expanded(child: Text("products available in inventory", style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Future<void> _showProductPreview(Product item) async {
    ColorOption selectedVariant = _selectedVariantFor(item) ?? item.colorOptions.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (context, setP) {
        return DraggableScrollableSheet(
          expand: false, initialChildSize: 0.9,
          builder: (context, scroll) => Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              controller: scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                    ...selectedVariant.images.map((p) => Padding(padding: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _buildVariantImage(selectedVariant.copyWith(images: [p]))))),
                    ...selectedVariant.videos.map((p) => Padding(padding: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(20), child: VideoPreviewPlayer(videoPath: p, isAsset: p.startsWith('assets/'), height: 250, width: 200)))),
                  ])),
                  const SizedBox(height: 20),
                  Text(item.productName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Tk ${selectedVariant.price.toInt()}", style: TextStyle(fontSize: 20, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(item.description, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 20),
                  const Text("Colors", style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(spacing: 10, children: item.colorOptions.map((v) {
                    final isSel = v == selectedVariant;
                    return ChoiceChip(label: Text(v.color), selected: isSel, onSelected: (s) => setP(() => selectedVariant = v));
                  }).toList()),
                  const SizedBox(height: 20),
                  if (item.category == "Fabric") ...[
                    const Text("Composition", style: TextStyle(fontWeight: FontWeight.bold)),
                    ...item.materialType.map((m) => Text("${m.blend}% ${m.type}")),
                    const SizedBox(height: 20),
                    const Text("Care", style: TextStyle(fontWeight: FontWeight.bold)),
                    ...item.careSymbol.map((s) => Text("• $s")),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
