import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';
import 'package:sketch2stitch/services/browse_service.dart';
import 'package:sketch2stitch/services/favorite_service.dart';
import 'package:sketch2stitch/services/customer_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Material Blend Class ─────────────────────────────────────────────

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

  factory FabricMaterialBlend.fromMaterialType(Map<String, dynamic> materialType) {
    final type = materialType['type'] as String? ?? '';
    final blend = materialType['blend'] as int? ?? 0;
    return FabricMaterialBlend(
      material: type,
      blend: blend > 0 ? '$blend%' : '',
    );
  }
}

// ─── Product Data with Material Blends ─────────────────────────────

class FabricProductData {
  final Product product;
  final List<FabricMaterialBlend> materialBlends;

  FabricProductData({
    required this.product,
    this.materialBlends = const [],
  });

  String get materialDisplay {
    final cleanBlends = materialBlends
        .where((blend) => blend.material.trim().isNotEmpty)
        .map((blend) => blend.displayText)
        .where((text) => text.trim().isNotEmpty)
        .toList();

    if (cleanBlends.isNotEmpty) {
      return cleanBlends.join(", ");
    }
    return product.materialType.isNotEmpty ? product.materialType.first.type : "N/A";
  }

  List<String> get materialBlendList {
    return materialBlends
        .where((blend) => blend.material.trim().isNotEmpty)
        .map((blend) => blend.displayText)
        .where((text) => text.trim().isNotEmpty)
        .toList();
  }

  factory FabricProductData.fromProduct(Product product) {
    List<FabricMaterialBlend> blends = [];
    
    if (product.materialType.isNotEmpty) {
      for (final materialType in product.materialType) {
        blends.add(FabricMaterialBlend(
          material: materialType.type,
          blend: materialType.blend > 0 
              ? '${materialType.blend.toInt()}%' 
              : '',
        ));
      }
    }
    
    return FabricProductData(
      product: product,
      materialBlends: blends,
    );
  }
}

// ─── FabricsPageBody ────────────────────────────────────────────────────

class FabricsPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final ProductFilterData filterData;
  final bool showFabrics;
  final UserRole userRole;

  const FabricsPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
    this.showFabrics = true,
    this.userRole = UserRole.customer,
  });

  @override
  State<FabricsPageBody> createState() => _FabricsPageBodyState();
}

class _FabricsPageBodyState extends State<FabricsPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BrowseService _browseService = BrowseService();
  final FavoriteService _favoriteService = FavoriteService();
  final CustomerService _customerService = CustomerService();
  
  String? _currentUserId;
  Map<String, String> _retailerNames = {};
  Map<String, GeoPoint?> _retailerLocations = {};

  // Categories that are considered "Elements" (non-fabric items)
  final List<String> _elementCategories = [
    'Material',
  ];

  // Categories that are considered "Fabrics"
  final List<String> _fabricCategories = [
    'Fabric',
  ];

  bool _isElement(Product product) =>
      _elementCategories.contains(product.category);
  
  bool _isFabric(Product product) =>
      _fabricCategories.contains(product.category);

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadRetailerNames();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  Future<void> _loadRetailerNames() async {
    try {
      final retailersSnapshot = await FirebaseFirestore.instance
          .collection('Retailer')
          .get();
      
      final Map<String, String> names = {};
      final Map<String, GeoPoint?> locations = {};
      for (final doc in retailersSnapshot.docs) {
        final data = doc.data();
        names[doc.id] = data['shopName'] as String? ?? 'Unknown Retailer';
        locations[doc.id] = data['location'] is GeoPoint ? data['location'] as GeoPoint : null;
      }

      setState(() {
        _retailerNames = names;
        _retailerLocations = locations;
      });
    } catch (e) {
      // retailer names/locations stay empty; getters fall back per-id
    }
  }

  String _getRetailerName(String retailerId) {
    return _retailerNames[retailerId] ?? 'Unknown Retailer';
  }

  GeoPoint? _getRetailerLocation(String retailerId) {
    return _retailerLocations[retailerId];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        final materialFilter = widget.filterData.materialTypes.contains('All') 
            ? null 
            : widget.filterData.materialTypes.first;
        
        final selectedColors = widget.filterData.colors.contains('All')
            ? null
            : widget.filterData.colors;
        
        final searchTerm = searchQuery.isNotEmpty ? searchQuery : null;

        return StreamBuilder<List<Product>>(
          stream: _browseService.getProductsByFilter(
            category: null,
            materialType: materialFilter,
            minPrice: widget.filterData.minPrice > 0 ? widget.filterData.minPrice : null,
            maxPrice: widget.filterData.maxPrice < 5000 ? widget.filterData.maxPrice : null,
            colors: selectedColors,
            sortBy: widget.filterData.sortBy,
            search: searchTerm,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error?.toString() ?? 'Unknown error',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting && 
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6B8F71),
                ),
              );
            }

            final products = snapshot.data ?? [];
            
            List<Product> filteredProducts;
            if (widget.showFabrics) {
              filteredProducts = products.where((p) => _isFabric(p)).toList();
            } else {
              filteredProducts = products.where((p) => _isElement(p)).toList();
            }
            
            final fabricDataList = filteredProducts
                .map((product) => FabricProductData.fromProduct(product))
                .toList();

            if (fabricDataList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.showFabrics ? 'No Fabrics found' : 'No Elements found',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your filters or search terms',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            if (widget.filterData.sortBy == 'lowToHigh') {
              fabricDataList.sort((a, b) => a.product.minPrice.compareTo(b.product.minPrice));
            } else if (widget.filterData.sortBy == 'highToLow') {
              fabricDataList.sort((a, b) => b.product.minPrice.compareTo(a.product.minPrice));
            }

            return Column(
              children: [
                _buildHeroSection(widget.showFabrics ? 'Fabrics' : 'Elements'),
                Expanded(
                  child: _buildFabricGrid(fabricDataList),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSection(String type) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 8),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A7C59), Color(0xFF6B8F71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium $type',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'High-quality materials for your style',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildHeroChip(Icons.local_shipping, 'Delivery Available', isSmallScreen),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.verified, 'Quality Assured', isSmallScreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 12, vertical: isSmall ? 4 : 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: isSmall ? 12 : 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabricGrid(List<FabricProductData> fabrics) {
    if (fabrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Fabrics found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search terms',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 400;
    final spacing = isSmallScreen ? 10.0 : 12.0;
    final cardAspectRatio = screenHeight < 700 ? 0.72 : 0.78;

    // Check if user is Tailor or Retailer
    final bool isTailorOrRetailer = widget.userRole == UserRole.tailor || 
                                     widget.userRole == UserRole.retailer;

    return GridView.builder(
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: cardAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: fabrics.length,
      itemBuilder: (context, index) {
        final fabricData = fabrics[index];
        final product = fabricData.product;
        final coverImage = product.colorOptions.isNotEmpty && product.colorOptions.first.image.isNotEmpty
            ? product.colorOptions.first.image.first
            : null;
        final bool outOfStock =
            product.colorOptions.every((c) => c.stock <= 0);

        final retailerName = _getRetailerName(product.retailerId);
        final materialDisplay = fabricData.materialDisplay;

        // Check if this is an element (Material category) - don't show material blend for elements
        final bool isElement = _isElement(product);
        // Show material badge ONLY for Fabrics (not for Elements)
        final bool showMaterialBadge = widget.showFabrics && !isElement && materialDisplay != "N/A";

        return GestureDetector(
          onTap: () => isElement
              ? _showElementDetailOverlay(context, product)
              : _showFabricDetailOverlay(context, fabricData),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  flex: 5,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: coverImage != null && coverImage.isNotEmpty
                              ? (coverImage.startsWith('http')
                                  ? Image.network(
                                      coverImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _imageFallback(isSmallScreen),
                                    )
                                  : Image.asset(
                                      coverImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _imageFallback(isSmallScreen),
                                    ))
                              : _imageFallback(isSmallScreen),
                        ),
                      ),
                      // Show material badge ONLY for Fabrics (not for Elements)
                      if (showMaterialBadge)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6 : 8, 
                              vertical: isSmallScreen ? 3 : 4
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 0.3,
                              ),
                            ),
                            child: Text(
                              materialDisplay,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 9 : 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if (outOfStock)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 8 : 10, 
                              vertical: isSmallScreen ? 4 : 5
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 0.3,
                              ),
                            ),
                            child: Text(
                              'Out of Stock',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isSmallScreen ? 10 : 12,
                      isSmallScreen ? 8 : 10,
                      isSmallScreen ? 10 : 12,
                      isSmallScreen ? 10 : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.productName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 3),
                        Text(
                          retailerName,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Text(
                          product.priceRange,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4A7C59),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: outOfStock
                                  ? const SizedBox.shrink()
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: product.colorOptions
                                          .take(4)
                                          .map((option) => Padding(
                                                padding: EdgeInsets.only(right: isSmallScreen ? 3 : 4),
                                                child: _colorDot(option.color, isSmallScreen),
                                              ))
                                          .toList(),
                                    ),
                            ),
                            // Only show delivery info for customers
                            if (!isTailorOrRetailer)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_bike, size: isSmallScreen ? 14 : 16, color: const Color.fromARGB(255, 107, 106, 106)),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Tk 50',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: const Color.fromARGB(255, 107, 106, 106),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _colorDot(String colorName, bool isSmall) {
    final color = _resolveColor(colorName);
    final double size = isSmall ? 14 : 16;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5),
      ),
    );
  }

  Color _resolveColor(String name) {
    switch (name.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'black':
        return Colors.black;
      case 'pink':
        return Colors.pink[200]!;
      case 'blue':
        return Colors.blue[300]!;
      case 'green':
        return Colors.green[300]!;
      case 'beige':
        return const Color(0xFFE8DCC8);
      case 'brown':
        return Colors.brown[300]!;
      case 'gold':
        return const Color(0xFFD4AF37);
      case 'silver':
        return Colors.grey[400]!;
      case 'purple':
        return Colors.purple[300]!;
      default:
        return Colors.grey[300]!;
    }
  }

  Widget _imageFallback(bool isSmall) {
    return Container(
      color: const Color(0xFF6B8F71).withOpacity(0.12),
      child: Icon(
        Icons.texture,
        size: isSmall ? 36 : 40,
        color: const Color(0xFF4A7C59),
      ),
    );
  }

  void _showFabricDetailOverlay(BuildContext context, FabricProductData fabricData) {
    if (_currentUserId != null) {
      _customerService.addToLastViewed(_currentUserId!, fabricData.product.id);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(
        product: fabricData.product,
        isFabric: true,
        retailerName: _getRetailerName(fabricData.product.retailerId),
        retailerLocation: _getRetailerLocation(fabricData.product.retailerId),
        materialBlends: fabricData.materialBlendList,
        userRole: widget.userRole,
        customerId: _currentUserId,
        favoriteService: _favoriteService,
      ),
    );
  }

  void _showElementDetailOverlay(BuildContext context, Product product) {
    if (_currentUserId != null) {
      _customerService.addToLastViewed(_currentUserId!, product.id);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(
        product: product,
        isFabric: false,
        retailerName: _getRetailerName(product.retailerId),
        retailerLocation: _getRetailerLocation(product.retailerId),
        userRole: widget.userRole,
        customerId: _currentUserId,
        favoriteService: _favoriteService,
      ),
    );
  }
}