import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/services/inventory_service.dart';
import 'package:sketch2stitch/services/user_session.dart';
import '../../widgets/video_preview_player.dart';
import '../../widgets/top_feedback_banner.dart';

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

  Map<String, dynamic> toMap() => {
    'colorName': colorName,
    'imagePaths': imagePaths,
    'videoPaths': videoPaths,
    'isAsset': isAsset,
    'price': price,
    'stock': stock,
  };

  factory ProductColorVariant.fromMap(Map<String, dynamic> map) {
    List<String> images = [];
    if (map['imagePaths'] is List) {
      images = List<String>.from(map['imagePaths'] as List);
    } else if (map['imagePath'] is String && (map['imagePath'] as String).isNotEmpty) {
      images = [map['imagePath'] as String];
    }

    List<String> videos = [];
    if (map['videoPaths'] is List) {
      videos = List<String>.from(map['videoPaths'] as List);
    } else if (map['videoPath'] is String && (map['videoPath'] as String).isNotEmpty) {
      videos = [map['videoPath'] as String];
    }

    return ProductColorVariant(
      colorName: map['colorName'] as String? ?? '',
      imagePaths: images,
      videoPaths: videos,
      isAsset: map['isAsset'] as bool? ?? false,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
    );
  }
}

class FabricMaterialBlend {
  String material;
  String blend;

  FabricMaterialBlend({required this.material, this.blend = ""});

  String get displayText {
    final cleanBlend = blend.trim();
    final cleanMaterial = material.trim();
    if (cleanBlend.isEmpty) {
      return cleanMaterial;
    }

    return "$cleanBlend $cleanMaterial";
  }

  Map<String, dynamic> toMap() => {'material': material, 'blend': blend};

  factory FabricMaterialBlend.fromMap(Map<String, dynamic> map) {
    return FabricMaterialBlend(
      material: map['material'] as String? ?? '',
      blend: map['blend'] as String? ?? '',
    );
  }
}

class InventoryItem {
  String id;
  String name;
  String category; // "Fabric" or "Element"
  String materialType; // Cotton, Silk etc.
  String sku;
  String description;
  List<ProductColorVariant> variants;
  List<FabricMaterialBlend> materialBlends;

  // Detailed Care Options
  bool canWash;
  bool canBleach;
  bool canDryClean;
  bool canTumbleDry;
  String ironLevel; // Low, Medium, High

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.materialType,
    required this.sku,
    required this.description,
    required this.variants,
    List<FabricMaterialBlend>? materialBlends,
    this.canWash = true,
    this.canBleach = false,
    this.canDryClean = true,
    this.canTumbleDry = true,
    this.ironLevel = "Medium",
  }) : materialBlends = materialBlends ?? <FabricMaterialBlend>[];

  // Helpers
  String get mainImagePath =>
      variants.isNotEmpty && variants.first.imagePaths.isNotEmpty
          ? variants.first.imagePaths.first
          : "";
  bool get mainIsAsset => variants.isNotEmpty ? variants.first.isAsset : false;
  List<String> get colorNames => variants.map((v) => v.colorName).toList();

  String get materialDisplay {
    final cleanBlends = materialBlends
        .where((blend) => blend.material.trim().isNotEmpty)
        .map((blend) => blend.displayText)
        .where((text) => text.trim().isNotEmpty)
        .toList();

    if (cleanBlends.isNotEmpty) {
      return cleanBlends.join(", ");
    }

    return materialType.trim().isNotEmpty ? materialType : "N/A";
  }

  double get minPrice {
    if (variants.isEmpty) return 0;
    return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  }

  int get totalStock {
    if (variants.isEmpty) return 0;
    return variants.fold(0, (sum, v) => sum + v.stock);
  }

  Map<String, dynamic> toMap() => {
  'id': id,
  'name': name,
  'category': category,
  'materialType': materialType,
  'sku': sku,
  'description': description,
  'variants': variants.map((v) => v.toMap()).toList(),
  'materialBlends': materialBlends.map((b) => b.toMap()).toList(),
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
              .map(
                (variant) => ProductColorVariant.fromMap(
                  Map<String, dynamic>.from(variant),
                ),
              )
              .toList()
        : <ProductColorVariant>[];
    final rawMaterialBlends = map['materialBlends'];
    final materialBlends = rawMaterialBlends is List
        ? rawMaterialBlends
              .whereType<Map>()
              .map(
                (blend) => FabricMaterialBlend.fromMap(
                  Map<String, dynamic>.from(blend),
                ),
              )
              .toList()
        : <FabricMaterialBlend>[];

    return InventoryItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Element',
      materialType: map['materialType'] as String? ?? 'N/A',
      sku: map['sku'] as String? ?? '',
      description: map['description'] as String? ?? '',
      variants: variants,
      materialBlends: materialBlends,
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

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = "";
  int _gridAnimationSeed = 0;
  final Map<String, int> _selectedVariantIndexes = <String, int>{};
  
  // Feedback state
  String? _feedbackMessage;
  bool _isFeedbackError = false;
  Timer? _feedbackTimer;
  
  final InventoryService _inventoryService = InventoryService();
  String? _retailerId;
  StreamSubscription<List<Product>>? _inventorySubscription;

  static const List<String> _commonMaterials = <String>[
    "Cotton",
    "Linen",
    "Silk",
    "Wool",
    "Cashmere",
    "Viscose",
    "Polyester",
    "Nylon",
    "Spandex (Lycra/Elastane)",
    "Khadi",
    "Muslin",
    "Jamdani",
  ];

  final List<InventoryItem> items = <InventoryItem>[];


  String _itemKey(InventoryItem item) {
    return item.id;
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

  String _lowStockTextFor(InventoryItem item) {
    final lowStockVariants = item.variants
        .where((variant) => variant.stock < 5)
        .toList();

    final colorStocks = lowStockVariants
        .map((variant) => "${variant.stock} ${variant.colorName}")
        .join(", ");
    return "Low stock: $colorStocks";
  }

  bool _hasLowStockColor(InventoryItem item) {
    return item.variants.any((variant) => variant.stock < 5);
  }


  List<FabricMaterialBlend> _initialMaterialBlendsFor(InventoryItem? item) {
    if (item == null) {
      return <FabricMaterialBlend>[FabricMaterialBlend(material: "")];
    }

    if (item.materialBlends.isNotEmpty) {
      return item.materialBlends
          .map(
            (blend) => FabricMaterialBlend(
              material: blend.material,
              blend: blend.blend,
            ),
          )
          .toList();
    }

    if (item.materialType.trim().isNotEmpty && item.materialType != "N/A") {
      return <FabricMaterialBlend>[
        FabricMaterialBlend(material: item.materialType),
      ];
    }

    return <FabricMaterialBlend>[FabricMaterialBlend(material: "")];
  }

  String _materialLabelFor(InventoryItem item) {
    final material = item.materialDisplay.trim();
    if (material.isNotEmpty && material != "N/A") {
      return material;
    }

    return item.category == "Fabric" ? "Fabric" : "Element";
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
    _retailerId = UserSession.instance.uid;
    _loadInventory();
  }

  // In inventory_screen.dart, find the _mapProductToItem method and update:

InventoryItem _mapProductToItem(Product p) {
  return InventoryItem(
    id: p.id,
    name: p.productName,
    category: p.category,
    materialType: p.materialType.isNotEmpty ? p.materialType.first.type : 'N/A',
    sku: p.productCode ?? '',  // ← Fix: add null fallback
    description: p.description,
    variants: p.colorOptions.map((v) {
      final images = v.image.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      final videos = v.video.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      
      final isAsset = [...images, ...videos].any((path) => path.startsWith('assets/'));
      
      return ProductColorVariant(
        colorName: v.color,
        imagePaths: images,
        videoPaths: videos,
        isAsset: isAsset,
        price: v.price,
        stock: v.stock,
      );
    }).toList(),
    materialBlends: p.materialType.map((m) => FabricMaterialBlend(
      material: m.type,
      blend: "${m.blend.toInt()}%",
    )).toList(),
    canWash: p.careSymbol.contains('Washable'),
    canBleach: p.careSymbol.contains('Bleach Allowed'),
    canDryClean: p.careSymbol.contains('Dry Clean Only'),
    canTumbleDry: p.careSymbol.contains('Tumble Dry'),
    ironLevel: p.careSymbol.firstWhere(
      (s) => s.startsWith('Iron: '), 
      orElse: () => 'Iron: Medium'
    ).replaceFirst('Iron: ', ''),
  );
}
  Future<void> _loadInventory() async {
    if (_retailerId == null) return;

    _inventorySubscription?.cancel();
    _inventorySubscription =
        _inventoryService.streamRetailerProducts(_retailerId!).listen((products) {
      if (!mounted) return;
      setState(() {
        items.clear();
        items.addAll(products.map((p) => _mapProductToItem(p)));
        _gridAnimationSeed++;
      });
    });
  }



  void _showFeedback(String message, {bool isError = false}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _isFeedbackError = isError;
    });

    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _inventorySubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showProductPreview(InventoryItem item) async {
    if (item.variants.isEmpty) {
      AppFeedback.show(context, "This item has no color variants yet",
          isError: true);
      return;
    }

    ProductColorVariant selectedVariant =
        _selectedVariantFor(item) ?? item.variants.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setP) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: item.category == "Fabric" ? 0.92 : 0.78,
            minChildSize: 0.25,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...selectedVariant.imagePaths.map((path) {
                            final cleanPath = path.trim();
                            if (cleanPath.isEmpty) return const SizedBox.shrink();
                            
                            final uri = Uri.tryParse(cleanPath);
                            final bool isNetwork = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
                            final bool isAssetPath = cleanPath.toLowerCase().startsWith('assets/') || selectedVariant.isAsset;
                            
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: isNetwork
                                    ? Image.network(
                                        cleanPath,
                                        height: 250,
                                        width: MediaQuery.of(context).size.width * 0.7,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _imageError(cleanPath),
                                      )
                                    : isAssetPath
                                        ? Image.asset(
                                            cleanPath,
                                            height: 250,
                                            width: MediaQuery.of(context).size.width * 0.7,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => _imageError(cleanPath),
                                          )
                                        : Image.file(
                                            File(cleanPath),
                                            height: 250,
                                            width: MediaQuery.of(context).size.width * 0.7,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => _imageError(cleanPath),
                                          ),
                              ),
                            );
                          }),
                          ...selectedVariant.videoPaths.map((path) {
                            final cleanPath = path.trim().replaceAll("'", "").replaceAll('"', "");
                            if (cleanPath.isEmpty) return const SizedBox.shrink();
                            
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: VideoPreviewPlayer(
                                  videoPath: cleanPath,
                                  isAsset: cleanPath.toLowerCase().startsWith('assets/'),
                                  height: 250,
                                  width: MediaQuery.of(context).size.width * 0.7,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Price
                    Row(
                      children: [
                        Text(
                          "Tk ${selectedVariant.price.toInt()}",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoBadge(
                          item.category,
                          Colors.blue.shade50,
                          Colors.blue.shade800,
                        ),
                        if (item.category == "Fabric" ||
                            item.materialDisplay != "N/A")
                          _infoBadge(
                            _materialLabelFor(item),
                            Colors.green.shade50,
                            Colors.green.shade800,
                          ),
                        _infoBadge(
                          "SKU: ${item.sku}",
                          Colors.grey.shade100,
                          Colors.grey.shade800,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 🎨 Color Selection (Interactive)
                    const Text(
                      "Select Color",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green.shade800
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.green.shade800
                                      : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  variant.colorName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Stock for ${selectedVariant.colorName}: ${selectedVariant.stock}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _infoBadge(
                          selectedVariant.stock < 10 ? "Low Stock" : "In Stock",
                          selectedVariant.stock < 10
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          selectedVariant.stock < 10
                              ? Colors.red
                              : Colors.green,
                        ),
                      ],
                    ),
                    if (item.category == "Fabric") ...[
                      const SizedBox(height: 25),
                      const Text(
                        "Care Instructions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _careInfoRow(
                        Icons.wash,
                        "Machine Washable",
                        item.canWash,
                        info: "Indicates whether the garment can be safely washed in a washing machine and the recommended washing conditions. Following these instructions helps maintain the fabric's quality, color, and shape.",
                      ),
                      _careInfoRow(
                        Icons.biotech,
                        "Bleach Allowed",
                        item.canBleach,
                        info: "Indicates whether bleach can be safely used on the fabric. Some materials may fade, weaken, or become damaged when exposed to bleach.",
                      ),
                      _careInfoRow(
                        Icons.dry_cleaning,
                        "Dry Clean Only",
                        item.canDryClean,
                        info: "Indicates whether the garment should be professionally cleaned using special solvents instead of water. This method is recommended for delicate fabrics or garments with special finishes.",
                      ),
                      _careInfoRow(
                        Icons.settings_input_component,
                        "Tumble Dry",
                        item.canTumbleDry,
                        info: "Tumble drying is the process of drying clothes in a clothes dryer (dryer machine) instead of hanging them to air dry. It indicates whether the garment is suitable for tumble drying and the recommended heat setting. Using the wrong drying method may cause shrinking or fabric damage.",
                      ),
                      _careInfoRow(
                        Icons.iron,
                        "Iron Level",
                        true,
                        trailing: item.ironLevel,
                        info: "Indicates the maximum ironing temperature that is safe for the fabric. Using excessive heat may damage, shrink, or burn the material.",
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoBadge(String label, Color bg, Color text) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 48,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: text,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _careInfoRow(
    IconData icon,
    String label,
    bool isOk, {
    String? trailing,
    String? info,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isOk ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          if (info != null)
            GestureDetector(
              onTap: () => _showInfoDialog(label, info),
              child: Icon(Icons.info_outline, size: 16, color: Colors.blue.shade300),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isOk ? Colors.black87 : Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              trailing ?? (isOk ? "Yes" : "No"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOk ? Colors.green.shade800 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(String path, bool isImage, bool isAsset, VoidCallback onRemove) {
    final cleanPath = path.trim();
    final uri = Uri.tryParse(cleanPath);
    final bool isNetwork = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final bool isAssetPath = cleanPath.toLowerCase().startsWith('assets/') || isAsset;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: isImage
                ? (isNetwork
                    ? Image.network(cleanPath, fit: BoxFit.cover, errorBuilder: (c, e, s) => _imageError(cleanPath))
                    : (isAssetPath 
                        ? Image.asset(cleanPath, fit: BoxFit.cover, errorBuilder: (c, e, s) => _imageError(cleanPath)) 
                        : Image.file(File(cleanPath), fit: BoxFit.cover, errorBuilder: (c, e, s) => _imageError(cleanPath))))
                : Container(
                    color: Colors.black87,
                    child: const Icon(Icons.videocam, color: Colors.white, size: 20),
                  ),
          ),
        ),
        Positioned(
          top: 0,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 10, color: Colors.white),
            ),
          ),
        ),
      ],
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
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
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

  Widget _buildMaterialBlendRow(
    FabricMaterialBlend blend,
    int index,
    List<FabricMaterialBlend> workingMaterialBlends,
    StateSetter setM,
  ) {
    final materialText = blend.material;
    final blendText = blend.blend;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: TextEditingController(text: materialText)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: materialText.length),
                ),
              onChanged: (value) => blend.material = value,
              decoration: InputDecoration(
                labelText: "Material Type",
                hintText: "Cotton, Polyester, Jamdani",
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (value) => setM(() => blend.material = value),
                  itemBuilder: (context) => _commonMaterials
                      .map(
                        (material) => PopupMenuItem<String>(
                          value: material,
                          child: Text(material),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: blendText)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: blendText.length),
                ),
              onChanged: (value) => blend.blend = value,
              decoration: const InputDecoration(
                labelText: "Blend",
                hintText: "95%",
              ),
            ),
          ),
          if (workingMaterialBlends.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () =>
                  setM(() => workingMaterialBlends.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Future<void> showItemForm({InventoryItem? item}) async {
    final name = TextEditingController(text: item?.name ?? "");
    final sku = TextEditingController(text: item?.sku ?? "");
    final desc = TextEditingController(text: item?.description ?? "");

    String category = item?.category ?? "Fabric";
    List<ProductColorVariant> workingVariants = item != null
        ? List.from(item.variants)
        : [
            ProductColorVariant(
              colorName: "",
              imagePaths: [],
              videoPaths: [],
              isAsset: false,
              price: 0,
              stock: 0,
            ),
          ];
    List<FabricMaterialBlend> workingMaterialBlends = _initialMaterialBlendsFor(
      item,
    );

    // Care states
    bool canWash = item?.canWash ?? true;
    bool canBleach = item?.canBleach ?? false;
    bool canDryClean = item?.canDryClean ?? true;
    bool canTumbleDry = item?.canTumbleDry ?? true;
    String ironLevel = item?.ironLevel ?? "Medium";
    // Feedback state for form
    String? formError;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (c, setM) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.92,
            minChildSize: 0.25,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
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
                    Text(
                      item == null ? "Add New Item" : "Edit Item",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    if (formError != null)
                      Container(
                        margin: const EdgeInsets.only(top: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                formError!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 25),

                    // 🏷 Category Selection
                    if (item == null)
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<String>(
                            initialValue: category,
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            iconEnabledColor: Colors.green.shade800,
                            decoration: InputDecoration(
                              labelText: "Category",
                              labelStyle: TextStyle(color: Colors.green.shade800),
                              prefixIcon: Icon(
                                Icons.category_outlined,
                                color: Colors.green.shade700,
                              ),
                              filled: true,
                              fillColor: Colors.green.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.green.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.green.shade100),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.green.shade800,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: ["Fabric", "Element"]
                                .map(
                                  (cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setM(() => category = v!),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              "Category: $category",
                              style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 25),

                    // 🌈 Multi-Color Variants Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Color Variants",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setM(
                              () => workingVariants.add(
                                ProductColorVariant(
                                  colorName: "",
                                  imagePaths: [],
                                  videoPaths: [],
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add Color"),
                          ),
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
                                          if (path.endsWith('.mp4') ||
                                              path.endsWith('.mov') ||
                                              path.endsWith('.avi')) {
                                            variant.videoPaths.add(file.path);
                                          } else {
                                            variant.imagePaths.add(file.path);
                                          }
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.shade100,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.collections,
                                      size: 30,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ...variant.imagePaths.map(
                                          (path) => _buildMediaThumbnail(
                                            path,
                                            true,
                                            variant.isAsset,
                                            () => setM(() => variant.imagePaths.remove(path)),
                                          ),
                                        ),
                                        ...variant.videoPaths.map(
                                          (path) => _buildMediaThumbnail(
                                            path,
                                            false,
                                            variant.isAsset,
                                            () => setM(() => variant.videoPaths.remove(path)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          onChanged: (v) =>
                                              variant.colorName = v,
                                          controller:
                                              TextEditingController(
                                                  text: variant.colorName,
                                                )
                                                ..selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset: variant
                                                            .colorName
                                                            .length,
                                                      ),
                                                    ),
                                          decoration: const InputDecoration(
                                            hintText: "Color",
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _buildColorPicker(variant, setM),
                                    ],
                                  ),
                                ),
                                if (workingVariants.length > 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => setM(
                                      () => workingVariants.removeAt(idx),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    onChanged: (v) =>
                                        variant.price = double.tryParse(v) ?? 0,
                                    controller:
                                        TextEditingController(
                                            text: variant.price > 0
                                                ? variant.price.toString()
                                                : "",
                                          )
                                          ..selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset:
                                                      (variant.price > 0
                                                              ? variant.price
                                                                    .toString()
                                                              : "")
                                                          .length,
                                                ),
                                              ),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "Price (Tk)",
                                      prefixText: "Tk ",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: TextField(
                                    onChanged: (v) =>
                                        variant.stock = int.tryParse(v) ?? 0,
                                    controller:
                                        TextEditingController(
                                            text: variant.stock > 0
                                                ? variant.stock.toString()
                                                : "",
                                          )
                                          ..selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset:
                                                      (variant.stock > 0
                                                              ? variant.stock
                                                                    .toString()
                                                              : "")
                                                          .length,
                                                ),
                                              ),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "Stock",
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
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: "Product Name (e.g. Pure Silk Saree)",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: desc,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Description",
                      ),
                    ),

                    const SizedBox(height: 10),
                    TextField(
                      controller: sku,
                      enabled: item == null,
                      decoration: InputDecoration(
                        labelText: "Product Code (SKU)",
                        helperText: item == null
                            ? null
                            : "SKU cannot be changed after creation",
                      ),
                    ),

                    if (category == "Fabric") ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Material Composition",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => setM(
                                () => workingMaterialBlends.add(
                                  FabricMaterialBlend(material: ""),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text("Add Material"),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...workingMaterialBlends.asMap().entries.map((entry) {
                        return _buildMaterialBlendRow(
                          entry.value,
                          entry.key,
                          workingMaterialBlends,
                          setM,
                        );
                      }),
                    ],

                    if (category == "Fabric") ...[
                      const SizedBox(height: 25),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Care Instructions",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCareSwitch(
                        "Machine Washable",
                        canWash,
                        (v) => setM(() => canWash = v),
                        info: "Indicates whether the garment can be safely washed in a washing machine and the recommended washing conditions. Following these instructions helps maintain the fabric's quality, color, and shape.",
                      ),
                      _buildCareSwitch(
                        "Bleach Allowed",
                        canBleach,
                        (v) => setM(() => canBleach = v),
                        info: "Indicates whether bleach can be safely used on the fabric. Some materials may fade, weaken, or become damaged when exposed to bleach.",
                      ),
                      _buildCareSwitch(
                        "Dry Clean Only",
                        canDryClean,
                        (v) => setM(() => canDryClean = v),
                        info: "Indicates whether the garment should be professionally cleaned using special solvents instead of water. This method is recommended for delicate fabrics or garments with special finishes.",
                      ),
                      _buildCareSwitch(
                        "Tumble Dry",
                        canTumbleDry,
                        (v) => setM(() => canTumbleDry = v),
                        info: "Tumble drying is the process of drying clothes in a clothes dryer (dryer machine) instead of hanging them to air dry. It indicates whether the garment is suitable for tumble drying and the recommended heat setting. Using the wrong drying method may cause shrinking or fabric damage.",
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 260,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showInfoDialog("Iron Level", "Indicates the maximum ironing temperature that is safe for the fabric. Using excessive heat may damage, shrink, or burn the material."),
                                child: Icon(Icons.info_outline, size: 20, color: Colors.blue.shade300),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField(
                                  initialValue: ironLevel,
                                  items: ["None", "Low", "Medium", "High"]
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text("Iron Level: $e"),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setM(() => ironLevel = v.toString()),
                                  decoration: const InputDecoration(labelText: "Ironing"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          disabledBackgroundColor: Colors.grey,
                        ),
                        onPressed: isSaving ? null : () async {
                          if (_retailerId == null) return;
                          
                          // Form Validation
                          String? error;
                          if (name.text.trim().isEmpty) {
                            error = "Product Name is required";
                          } else if (desc.text.trim().isEmpty) {
                            error = "Description is required";
                          } else if (item == null && sku.text.trim().isEmpty) {
                            error = "Product Code (SKU) is required";
                          } else if (workingVariants.isEmpty) {
                            error = "At least one color variant is required";
                          } else {
                            for (var v in workingVariants) {
                              if (v.colorName.trim().isEmpty) {
                                error = "Color name is required for all variants";
                                break;
                              }
                              if (v.imagePaths.isEmpty && v.videoPaths.isEmpty) {
                                error = "Media is required for all variants";
                                break;
                              }
                              if (v.price <= 0) {
                                error = "Price must be greater than 0";
                                break;
                              }
                              if (v.stock < 0) {
                                error = "Stock cannot be negative";
                                break;
                              }
                            }
                          }

                          if (category == "Fabric" && error == null) {
                            if (workingMaterialBlends.isEmpty || workingMaterialBlends.every((b) => b.material.trim().isEmpty)) {
                              error = "Material composition is required for fabrics";
                            }
                          }

                          if (error != null) {
                            setM(() => formError = error);
                            // Scroll to top to see error
                            scrollController.animateTo(
                              0, 
                              duration: const Duration(milliseconds: 300), 
                              curve: Curves.easeOut,
                            );
                            return;
                          }

                          // Clear previous error if any
                          setM(() {
                            formError = null;
                            isSaving = true;
                          });

                          // 🔄 Show a loading overlay or state if needed
                          // For simplicity, we'll just disable the button or use a local isSaving if we had one.
                          // But to keep UI same, we just proceed.

                          try {
                            List<ColorOption> finalColorOptions = [];
                            for (int i = 0; i < workingVariants.length; i++) {
                              final v = workingVariants[i];
                              // Upload new media to Cloudinary
                              final imageUrls = await _inventoryService.uploadMedia(v.imagePaths, folder: 'products/images');
                              final videoUrls = await _inventoryService.uploadMedia(v.videoPaths, folder: 'products/videos');
                              
                              finalColorOptions.add(ColorOption(
                                optionId: i + 1,
                                color: v.colorName,
                                image: imageUrls,
                                video: videoUrls,
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
                              materialType: category == "Fabric" 
                                ? workingMaterialBlends.where((b) => b.material.isNotEmpty).map((b) => MaterialBlend(type: b.material, blend: double.tryParse(b.blend.replaceAll('%', '')) ?? 0)).toList()
                                : [],
                              colorOptions: finalColorOptions,
                              description: desc.text,
                              careSymbol: careSymbols,
                            );

                            if (item == null) {
                              await _inventoryService.createProduct(product.toJson());
                            } else {
                              await _inventoryService.updateProduct(item.id, product.toJson());
                            }

                            if (context.mounted) Navigator.of(context).pop();

                            if (item == null) {
                              _showFeedback("Product added successfully!");
                            } else {
                              _showFeedback("Product updated successfully!");
                            }
                          } catch (e) {
                            debugPrint("Error saving product: $e");
                            setM(() {
                              isSaving = false;
                              formError = "Error saving product: $e";
                            });
                          }
                        },
                        child: Text(
                          item == null ? "Add Item" : "Save Changes",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isSaving)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 20),
                    Text(
                      "Saving Product...",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Please wait, uploading media",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  },
),
);
}


  Widget _buildCareSwitch(String label, bool value, Function(bool) onChanged, {String? info}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info != null)
              GestureDetector(
                onTap: () => _showInfoDialog(label, info),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.info_outline, size: 20, color: Colors.blue.shade300),
                ),
              ),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        Switch(
          value: value,
          activeThumbColor: Colors.green.shade700,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text(
          "Retailer Inventory",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _inventorySummary(items.length),
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
                    hintText: "Search your products by name or code",
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? "No items in inventory yet"
                                : "No products match your search",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.55,
                                mainAxisSpacing: 15,
                                crossAxisSpacing: 15,
                              ),
                          itemCount: filteredItems.length,
                          itemBuilder: (c, i) {
                            return _buildAnimatedGridCard(filteredItems[i], i);
                          },
                        ),
                ),
              ],
            ),
          ),

          // Top Feedback Banner
          if (_feedbackMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SafeArea(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _isFeedbackError
                              ? const Color(0xFFFFEBEE).withValues(alpha: 0.92)
                              : const Color(0xFFC8E6C9).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _isFeedbackError
                                ? const Color(0xFFFFCDD2)
                                : const Color(0xFF9CCC9F),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isFeedbackError
                                  ? const Color(0xFFD32F2F).withValues(alpha: 0.10)
                                  : const Color(0xFF2E7D32).withValues(alpha: 0.10),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isFeedbackError
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF4CAF50),
                                border: Border.all(
                                  color: _isFeedbackError
                                      ? const Color(0xFFEF9A9A)
                                      : const Color(0xFFA5D6A7),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _isFeedbackError ? Icons.close_rounded : Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _feedbackMessage!,
                                style: const TextStyle(
                                  color: Color(0xFF222222),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _feedbackMessage = null),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.black.withValues(alpha: 0.45),
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
          ),
        );
      },
      child: _buildProductCard(item),
    );
  }

  Widget _buildProductCard(InventoryItem item) {
    final selectedVariant = _selectedVariantFor(item);
    final variantIndex = selectedVariant == null
        ? -1
        : item.variants.indexOf(selectedVariant);
    final hasLowStockColor = _hasLowStockColor(item);

    return GestureDetector(
      onTap: () => _showProductPreview(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
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
                  _buildVariantImage(selectedVariant),
                  Positioned(
                    top: 8,
                    right: 8,
                    left: 8,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _actionBtn(
                              Icons.edit,
                              Colors.blue,
                              () => showItemForm(item: item),
                            ),
                            const SizedBox(width: 5),
                            _actionBtn(Icons.delete, Colors.red, () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Delete Product"),
                                  content: Text("Are you sure you want to delete ${item.name}?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  await _inventoryService.deleteProduct(item.id);
                                  _showFeedback("Product deleted successfully!");
                                } catch (_) {
                                  _showFeedback(
                                      "Couldn't delete the product. Please try again.",
                                      isError: true);
                                }
                              }
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedVariant == null
                            ? "No stock"
                            : "${selectedVariant.colorName}: ${selectedVariant.stock}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _materialLabelFor(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.sku,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 30,
                    child: item.variants.isEmpty
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "No colors",
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 10,
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.variants.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final variant = item.variants[index];
                              final isSelected = index == variantIndex;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedVariantIndexes[_itemKey(item)] =
                                        index;
                                  });
                                },
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 82,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.green.shade800
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.green.shade800
                                          : Colors.green.shade100,
                                    ),
                                  ),
                                  child: Text(
                                    variant.colorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.green.shade900,
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  if (hasLowStockColor) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        _lowStockTextFor(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        selectedVariant == null
                            ? "Tk 0"
                            : "Tk ${selectedVariant.price.toInt()}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        "Total: ${item.totalStock}",
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.category == "Fabric")
                        GestureDetector(
                          onTap: () => _showProductPreview(item),
                          child: Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.green.shade300,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantImage(ProductColorVariant? variant) {
    if (variant == null) return _imagePlaceholder();
    
    if (variant.imagePaths.isEmpty) {
      if (variant.videoPaths.isNotEmpty) {
        return Container(
          color: Colors.blue.shade50,
          child: const Icon(Icons.videocam, color: Colors.blue, size: 40),
        );
      }
      return _imagePlaceholder();
    }

    final path = variant.imagePaths.first.trim();
    if (path.isEmpty) return _imagePlaceholder();

    // Use Uri to reliably check for network scheme
    final uri = Uri.tryParse(path);
    final bool isNetwork = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (isNetwork) {
      return Image.network(
        path, 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _imageError(path),
      );
    }
    
    if (variant.isAsset || path.toLowerCase().startsWith('assets/')) {
      return Image.asset(
        path, 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _imageError(path),
      );
    }

    return Image.file(
      File(path), 
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _imageError(path),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.green.shade50,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.green.shade200,
      ),
    );
  }

  Widget _imageError(String path) {
    debugPrint("Error loading image at path: $path");
    return Container(
      color: Colors.red.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300),
          const SizedBox(height: 4),
          const Text("Error", style: TextStyle(fontSize: 8, color: Colors.red)),
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
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _inventorySummary(int itemCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 18,
            color: Colors.green.shade800,
          ),
          const SizedBox(width: 8),
          CountUpText(
            begin: 0,
            end: itemCount.toDouble(),
            style: TextStyle(
              color: Colors.green.shade900,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              "products currently available in inventory",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
    _animation = Tween<double>(
      begin: widget.begin,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.end != widget.end) {
      _animation = Tween<double>(
        begin: oldWidget.end,
        end: widget.end,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
        return Text(_animation.value.toInt().toString(), style: widget.style);
      },
    );
  }
}
