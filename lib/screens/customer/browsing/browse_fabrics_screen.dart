import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';

/// Entry point kept for backward compatibility with existing navigation
/// calls (e.g. `Navigator.push(... BrowseFabricsScreen())`). It now opens
/// the shared [BrowseShell] on the Fabrics tab, so the user can swipe or
/// tap between Fabrics / Tailors / Retailers from anywhere.
class BrowseFabricsScreen extends StatelessWidget {
  const BrowseFabricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BrowseShell(initialIndex: 0);
  }
}

/// Hardcoded sample fabrics with assets images
final List<Product> kHardcodedProducts = [
  Product(
    id: 'p1',
    retailerId: 'r1',
    productName: 'Premium Egyptian Cotton',
    category: 'Cotton',
    materialType: '100% Cotton',
    colorOptions: [
      ColorOption(optionId: 1, color: 'White', image: 'assets/images/fab.jpg', price: 650, stock: 40),
      ColorOption(optionId: 2, color: 'Beige', image: 'assets/images/fab2.jpg', price: 650, stock: 25),
      ColorOption(optionId: 3, color: 'Blue', image: 'assets/images/fabric_waves.jpg', price: 700, stock: 15),
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
    materialType: '100% Silk',
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
    materialType: 'Wool Blend',
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
    materialType: '100% Linen',
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
    materialType: 'Nylon-Cotton Lace',
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
    materialType: 'Silk with Metallic Thread',
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
    materialType: 'Cotton Blend',
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
    materialType: '100% Cotton',
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
    materialType: 'Silk Blend',
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
    materialType: '100% Cotton',
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

/// The actual fabrics tab content, rendered as one page inside the
/// shared [BrowseShell] PageView. Header and navigation row live in the
/// shell; this widget only owns the hero, category chips, and grid.
class FabricsPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;

  const FabricsPageBody({super.key, required this.searchQuery});

  @override
  State<FabricsPageBody> createState() => _FabricsPageBodyState();
}

class _FabricsPageBodyState extends State<FabricsPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedCategory = 'All';

  // Hardcoded data — no Firestore for now.
  final List<Product> _products = kHardcodedProducts;
  final List<String> _categories = [
    'All',
    'Cotton',
    'Silk',
    'Wool',
    'Linen',
    'Lace',
    'Embroidery'
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        final filteredProducts = _products.where((p) {
          final matchesCategory =
              _selectedCategory == 'All' || p.category == _selectedCategory;
          final matchesSearch = p.productName
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
          return matchesCategory && matchesSearch;
        }).toList();

        return Column(
          children: [
            _buildHeroSection(),
            _buildCategoryChips(),
            Expanded(child: _buildProductGrid(filteredProducts)),
          ],
        );
      },
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSageDark, kSage],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium Fabrics for Your Style',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose from our wide selection of high-quality fabrics',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroChip(Icons.local_shipping, 'Free Delivery on Tk 500+'),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.verified, 'Quality Assured'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Chips ──────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildChip(
              category,
              _selectedCategory == category,
              () => setState(() => _selectedCategory = category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kSage : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kSage : kBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ─── Product Grid ──────────────────────────────────────────────────────

  Widget _buildProductGrid(List<Product> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No products found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: coverImage != null
                              ? Image.asset(
                                  coverImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: kSage.withValues(alpha: 0.12),
                                    child: const Icon(Icons.texture, size: 36, color: kSageDark),
                                  ),
                                )
                              : Container(
                                  color: kSage.withValues(alpha: 0.12),
                                  child: const Icon(Icons.texture, size: 36, color: kSageDark),
                                ),
                        ),
                      ),
                      if (outOfStock)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Out of Stock',
                              style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Content section
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          product.materialType,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.priceRange,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kSageDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: product.colorOptions
                              .take(4)
                              .map((option) => Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: _colorDot(option),
                                  ))
                              .toList(),
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

  Widget _colorDot(ColorOption option) {
    final color = _resolveColor(option.color);
    final bool outOfStock = option.stock <= 0;
    return Opacity(
      opacity: outOfStock ? 0.35 : 1.0,
      child: Container(
        width: 12,
        height: 12,
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