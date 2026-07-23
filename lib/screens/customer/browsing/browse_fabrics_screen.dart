import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/browsing/filter_data.dart';
import '../../../widgets/video_preview_player.dart';

/// Hardcoded sample fabrics with assets images (NO RATING)
final List<Product> kHardcodedProducts = [
  Product(
    id: 'p1',
    retailerId: 'r1',
    productName: 'Premium Egyptian Cotton',
    category: 'Cotton',
    materialType: 'Cotton',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/fab.jpg', video: 'assets/images/Videos/vid1.mp4', price: 650, stock: 40),
      ColorOption(optionId: 2, color: 'Beige', image: 'assets/images/fab2.jpg', video: 'assets/images/Videos/vid2.mp4', price: 650, stock: 25),
      ColorOption(optionId: 3, color: 'Blue', image: 'assets/images/fabric_waves.jpg', video: 'assets/images/Videos/vid3.mp4', price: 700, stock: 15),
      ColorOption(optionId: 4, color: 'Black', image: 'assets/images/textile.jpg', price: 700, stock: 0),
    ],
    description:
        'Soft, breathable Egyptian cotton perfect for shirts and casual wear. '
        'Pre-shrunk and colorfast, holds its shape wash after wash.',
    careSymbol: ['Machine wash cold', 'Do not bleach', 'Tumble dry low'],
  ),
  Product(
    id: 'p2',
    retailerId: 'r1',
    productName: 'Pure Mulberry Silk',
    category: 'Silk',
    materialType: 'Silk',
    colorOptions: [
      ColorOption(optionId: 1, color: 'Gold', image: 'assets/images/silk.jpg', price: 1800, stock: 10),
      ColorOption(optionId: 2, color: 'Pink', image: 'assets/images/saree.jpg', price: 1750, stock: 8),
      ColorOption(optionId: 3, color: 'Green', image: 'assets/images/gorgeous.jpg', price: 1750, stock: 5),
      ColorOption(optionId: 4, color: 'White', image: 'assets/images/gorgette.jpg', price: 1700, stock: 12),
    ],
    description:
        'Luxurious mulberry silk with a natural sheen, ideal for formal wear '
        'and sarees. Lightweight with a smooth, cool feel against the skin.',
    careSymbol: ['Dry clean only', 'Iron on low heat'],
  ),
  Product(
    id: 'p3',
    retailerId: 'r2',
    productName: 'Merino Wool Blend',
    category: 'Wool',
    materialType: 'Wool',
    colorOptions: [
      ColorOption(optionId: 1, color: 'Brown', image: 'assets/images/drawing_fabric.jpg', price: 950, stock: 18),
      ColorOption(optionId: 2, color: 'Black', image: 'assets/images/textile.jpg', price: 950, stock: 20),
      ColorOption(optionId: 3, color: 'Beige', image: 'assets/images/fabric_waves.jpg', price: 900, stock: 0),
    ],
    description:
        'Warm merino wool blend suited for winter jackets and blazers. '
        'Resists wrinkles and retains heat without feeling heavy.',
    careSymbol: ['Hand wash cold', 'Dry flat'],
  ),
  Product(
    id: 'p4',
    retailerId: 'r2',
    productName: 'Irish Linen Weave',
    category: 'Linen',
    materialType: 'Linen',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/fabrics_rolled.jpg', price: 780, stock: 30),
      ColorOption(optionId: 2, color: 'Beige', image: 'assets/images/fab.jpg', price: 780, stock: 22),
      ColorOption(optionId: 3, color: 'Blue', image: 'assets/images/fabric_waves.jpg', price: 820, stock: 14),
    ],
    description:
        'Classic Irish linen with a crisp hand-feel, great for summer shirts '
        'and trousers. Naturally breathable and gets softer with every wash.',
    careSymbol: ['Machine wash cold', 'Iron while damp'],
  ),
  Product(
    id: 'p5',
    retailerId: 'r3',
    productName: 'French Chantilly Lace',
    category: 'Lace',
    materialType: 'Lace',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/lace.jpg', price: 1200, stock: 6),
      ColorOption(optionId: 2, color: 'Black', image: 'assets/images/lace2.jpg', price: 1200, stock: 4),
      ColorOption(optionId: 3, color: 'Pink', image: 'assets/images/embroidery.jpg', price: 1250, stock: 0),
    ],
    description:
        'Delicate floral Chantilly lace, hand-finished scalloped edges. '
        'Popular for bridal wear and formal blouses.',
    careSymbol: ['Dry clean only', 'Do not bleach'],
  ),
  Product(
    id: 'p6',
    retailerId: 'r3',
    productName: 'Zardozi Embroidered Panel',
    category: 'Embroidery',
    materialType: 'Embroidery',
    colorOptions: [
      ColorOption(optionId: 1, color: 'Gold', image: 'assets/images/embroidery.jpg', price: 3200, stock: 3),
      ColorOption(optionId: 2, color: 'Green', image: 'assets/images/design.jpg', price: 3200, stock: 2),
      ColorOption(optionId: 3, color: 'Blue', image: 'assets/images/crochet.jpg', price: 3400, stock: 0),
    ],
    description:
        'Hand-embroidered zardozi work with metallic thread and sequins, '
        'crafted for statement pieces like lehengas and formal jackets.',
    careSymbol: ['Dry clean only'],
  ),
  Product(
    id: 'p7',
    retailerId: 'r1',
    productName: 'Premium Tassel Fabric',
    category: 'Cotton',
    materialType: 'Cotton',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/tassel.jpg', price: 550, stock: 35),
      ColorOption(optionId: 2, color: 'Blue', image: 'assets/images/drawing_fabric.jpg', price: 600, stock: 20),
    ],
    description:
        'Beautiful tassel fabric with intricate detailing. Perfect for '
        'curtains, upholstery, and decorative items.',
    careSymbol: ['Dry clean only', 'Do not iron directly'],
  ),
  Product(
    id: 'p8',
    retailerId: 'r2',
    productName: 'Handwoven Textile',
    category: 'Cotton',
    materialType: 'Cotton',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/textile.jpg', price: 850, stock: 15),
      ColorOption(optionId: 2, color: 'Beige', image: 'assets/images/fabric_waves.jpg', price: 850, stock: 10),
    ],
    description:
        'Handwoven textile with traditional patterns. Each piece is unique '
        'with slight variations that add to its charm.',
    careSymbol: ['Hand wash', 'Do not bleach', 'Air dry'],
  ),
  Product(
    id: 'p9',
    retailerId: 'r3',
    productName: 'Designer Silk Blend',
    category: 'Silk',
    materialType: 'Silk',
    colorOptions: [
      ColorOption(optionId: 1, color: 'Gold', image: 'assets/images/gorgeous.jpg', price: 2500, stock: 5),
      ColorOption(optionId: 2, color: 'Blue', image: 'assets/images/design.jpg', price: 2800, stock: 3),
    ],
    description:
        'Luxurious designer silk blend with a unique texture and finish. '
        'Perfect for high-end fashion and special occasions.',
    careSymbol: ['Dry clean only', 'Store in a cool place'],
  ),
  Product(
    id: 'p10',
    retailerId: 'r1',
    productName: 'Classic Cotton Weave',
    category: 'Cotton',
    materialType: 'Cotton',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/fab.jpg', price: 450, stock: 50),
      ColorOption(optionId: 2, color: 'Blue', image: 'assets/images/fab2.jpg', price: 500, stock: 30),
      ColorOption(optionId: 3, color: 'Green', image: 'assets/images/fabric_waves.jpg', price: 550, stock: 20),
    ],
    description:
        'Classic cotton weave fabric with a soft, comfortable feel. '
        'Ideal for everyday wear and casual outfits.',
    careSymbol: ['Machine wash warm', 'Tumble dry', 'Iron medium'],
  ),
];

/// Hardcoded sample elements with assets images
final List<Product> kHardcodedElements = [
  Product(
    id: 'e1',
    retailerId: 'r1',
    productName: 'Premium Zipper',
    category: 'Fasteners',
    materialType: 'Metal',
    colorOptions: [
      ColorOption(optionId: 1, color: 'Silver', image: 'assets/images/zipper.jpg', video: 'assets/images/Videos/vid1.mp4', price: 120, stock: 100),
      ColorOption(optionId: 2, color: 'Gold', image: 'assets/images/zipper_gold.jpg', price: 150, stock: 50),
      ColorOption(optionId: 3, color: 'Black', image: 'assets/images/zipper.jpg', price: 130, stock: 75),
    ],
    description:
        'High-quality metal zippers with smooth operation. '
        'Perfect for jackets, bags, and formal wear.',
    careSymbol: ['Do not iron directly', 'Clean with damp cloth'],
  ),
  Product(
    id: 'e2',
    retailerId: 'r1',
    productName: 'Decorative Buttons Set',
    category: 'Buttons',
    materialType: 'Plastic',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/buttons.jpg', price: 80, stock: 200),
      ColorOption(optionId: 2, color: 'Black', image: 'assets/images/buttons.jpg', price: 80, stock: 150),
      ColorOption(optionId: 3, color: 'Gold', image: 'assets/images/buttons.jpg', price: 100, stock: 100),
    ],
    description:
        'Elegant button sets in various sizes and finishes. '
        'Suitable for shirts, blazers, and decorative purposes.',
    careSymbol: ['Hand wash', 'Do not bleach'],
  ),
  Product(
    id: 'e3',
    retailerId: 'r2',
    productName: 'Sewing Thread Collection',
    category: 'Threads',
    materialType: 'Cotton',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/thread.jpg', price: 45, stock: 300),
      ColorOption(optionId: 2, color: 'Black', image: 'assets/images/thread.jpg', price: 45, stock: 250),
      ColorOption(optionId: 3, color: 'Beige', image: 'assets/images/thread.jpg', price: 45, stock: 200),
    ],
    description:
        'Premium quality sewing thread in essential colors. '
        'Strong and durable for all your stitching needs.',
    careSymbol: ['Store in cool dry place'],
  ),
  Product(
    id: 'e4',
    retailerId: 'r2',
    productName: 'Pearl Embellishments',
    category: 'Embellishments',
    materialType: 'Glass',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/pearls.jpg', price: 200, stock: 80),
      ColorOption(optionId: 2, color: 'Pink', image: 'assets/images/pearls.jpg', price: 220, stock: 60),
    ],
    description:
        'Beautiful pearl embellishments for bridal and formal wear. '
        'Adds elegance to any garment or accessory.',
    careSymbol: ['Dry clean only', 'Handle with care'],
  ),
  Product(
    id: 'e5',
    retailerId: 'r3',
    productName: 'Lace Trim',
    category: 'Trims',
    materialType: 'Lace',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/lace_trim.jpg', price: 180, stock: 40),
      ColorOption(optionId: 2, color: 'Black', image: 'assets/images/lace_trim.jpg', price: 180, stock: 35),
    ],
    description:
        'Fine lace trim with delicate patterns. '
        'Perfect for adding feminine touches to garments.',
    careSymbol: ['Hand wash', 'Do not bleach'],
  ),
  Product(
    id: 'e6',
    retailerId: 'r3',
    productName: 'Ribbon Collection',
    category: 'Ribbons',
    materialType: 'Satin',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/ribbon.jpg', price: 60, stock: 150),
      ColorOption(optionId: 2, color: 'Gold', image: 'assets/images/ribbon.jpg', price: 70, stock: 120),
      ColorOption(optionId: 3, color: 'Blue', image: 'assets/images/ribbon.jpg', price: 65, stock: 100),
    ],
    description:
        'Versatile satin ribbons in various colors and widths. '
        'Ideal for gift wrapping, bows, and garment decoration.',
    careSymbol: ['Iron on low heat', 'Do not bleach'],
  ),
];

/// The actual fabrics/elements tab content, rendered as one page inside the
/// shared [BrowseShell] PageView.
class FabricsPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final ProductFilterData filterData;
  final bool showFabrics;

  const FabricsPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
    this.showFabrics = true,
  });

  @override
  State<FabricsPageBody> createState() => _FabricsPageBodyState();
}

class _FabricsPageBodyState extends State<FabricsPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<Product> _fabrics = kHardcodedProducts;
  final List<Product> _elements = kHardcodedElements;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        // Use fabrics or elements based on showFabrics flag
        final products = widget.showFabrics ? _fabrics : _elements;
        final type = widget.showFabrics ? 'Fabrics' : 'Elements';
        
        // Filter products
        final filteredProducts = products.where((p) {
          final matchesSearch = p.productName
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
          final productMinPrice = p.minPrice;
          final matchesPrice = productMinPrice >= widget.filterData.minPrice &&
              productMinPrice <= widget.filterData.maxPrice;
          final matchesColor = widget.filterData.color == 'All' || 
              p.colorOptions.any((c) => c.color == widget.filterData.color);
          final matchesMaterial = widget.filterData.materialType == 'All' || 
              p.category == widget.filterData.materialType ||
              p.materialType == widget.filterData.materialType;
          return matchesSearch && matchesPrice && 
                 matchesColor && matchesMaterial;
        }).toList();

        // Sort based on filterData.sortBy
        if (widget.filterData.sortBy == 'lowToHigh') {
          filteredProducts.sort((a, b) => a.minPrice.compareTo(b.minPrice));
        } else if (widget.filterData.sortBy == 'highToLow') {
          filteredProducts.sort((a, b) => b.minPrice.compareTo(a.minPrice));
        }

        return Column(
          children: [
            _buildHeroSection(type),
            Expanded(
              child: _buildProductGrid(filteredProducts, type),
            ),
          ],
        );
      },
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection(String type) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 8),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSageDark, kSage],
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
              color: Colors.white.withValues(alpha: 0.9),
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
        color: Colors.white.withValues(alpha: 0.2),
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

  // ─── Product Grid ──────────────────────────────────────────────────────

  Widget _buildProductGrid(List<Product> products, String type) {
    if (products.isEmpty) {
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
              'No $type found',
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

    return GridView.builder(
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: cardAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final coverImage = product.colorOptions.isNotEmpty
            ? product.colorOptions.first.image
            : null;
        final bool outOfStock =
            product.colorOptions.every((c) => c.stock <= 0);

        return GestureDetector(
          onTap: () => _showProductDetailOverlay(context, product),
          child: Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image section with category badge
                Flexible(
                  flex: 5,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: coverImage != null
                              ? Image.asset(
                                  coverImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: kSage.withValues(alpha: 0.12),
                                    child: Icon(
                                      type == 'Fabrics' ? Icons.texture : Icons.category,
                                      size: isSmallScreen ? 36 : 40,
                                      color: kSageDark,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: kSage.withValues(alpha: 0.12),
                                  child: Icon(
                                    type == 'Fabrics' ? Icons.texture : Icons.category,
                                    size: isSmallScreen ? 36 : 40,
                                    color: kSageDark,
                                  ),
                                ),
                        ),
                      ),
                      // Category Badge - Top Right
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 10, 
                            vertical: isSmallScreen ? 4 : 5
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.3,
                            ),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      // Out of Stock Badge - Top Left
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
                              color: Colors.red.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
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
                // Content section
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
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.priceRange,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kSageDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_bike, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 2),
                                Text(
                                  'Tk 50',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        if (!outOfStock) ...[
                          Row(
                            children: product.colorOptions
                                .take(4)
                                .map((option) => Padding(
                                      padding: EdgeInsets.only(right: isSmallScreen ? 3 : 4),
                                      child: _colorDot(option, isSmallScreen),
                                    ))
                                .toList(),
                          ),
                        ],
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

  Widget _colorDot(ColorOption option, bool isSmall) {
    final color = _resolveColor(option.color);
    final bool outOfStock = option.stock <= 0;
    final double size = isSmall ? 14 : 16;
    return Opacity(
      opacity: outOfStock ? 0.35 : 1.0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: kBorder, width: 0.5),
        ),
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

  void _showProductDetailOverlay(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(product: product),
    );
  }
}