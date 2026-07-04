import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/mdi.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

const _categories = [
  'All Fabrics and elements',
  'Cotton',
  'Silk',
  'Wool',
  'Linen',
  'Lace',
  'Embroidery',
];

class FabricItem {
  const FabricItem({
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.priceTk,
    required this.color1,
    required this.color2,
    required this.imageColor,
  });

  final String name;
  final String category;
  final double rating;
  final int reviewCount;
  final int priceTk;
  final String color1;
  final String color2;
  final Color imageColor;
}

const _fabrics = [
  FabricItem(
    name: 'Premium Cotton Fabric',
    category: 'Cotton',
    rating: 4.5,
    reviewCount: 234,
    priceTk: 230,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFFD4C5A9),
  ),
  FabricItem(
    name: 'Silk Blend Fabric',
    category: 'Silk',
    rating: 4.7,
    reviewCount: 334,
    priceTk: 330,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFFB8A9C9),
  ),
  FabricItem(
    name: 'Linen Casual Fabric',
    category: 'Linen',
    rating: 3.5,
    reviewCount: 200,
    priceTk: 130,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFFC8B89A),
  ),
  FabricItem(
    name: 'Wool Blend Fabric',
    category: 'Wool',
    rating: 4.5,
    reviewCount: 234,
    priceTk: 200,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFF9B8EA0),
  ),
  FabricItem(
    name: 'Satin Silk Fabric',
    category: 'Silk',
    rating: 4.7,
    reviewCount: 334,
    priceTk: 330,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFFA8C5B8),
  ),
  FabricItem(
    name: 'Dubai Cherry Fabric',
    category: 'Linen',
    rating: 3.5,
    reviewCount: 200,
    priceTk: 130,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFFB85C6E),
  ),
  FabricItem(
    name: 'Neck Embroidery Design',
    category: 'Embroidery',
    rating: 3.5,
    reviewCount: 200,
    priceTk: 130,
    color1: 'Yellow',
    color2: 'Pink',
    imageColor: Color(0xFFE8D5A3),
  ),
  FabricItem(
    name: 'Denim Fabric',
    category: 'Cotton',
    rating: 4.7,
    reviewCount: 334,
    priceTk: 330,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFF5B7FA6),
  ),
  FabricItem(
    name: 'Linen Fabric',
    category: 'Linen',
    rating: 3.5,
    reviewCount: 200,
    priceTk: 130,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFFCDBF9E),
  ),
  FabricItem(
    name: 'Gotapatti Tassels',
    category: 'Lace',
    rating: 4.7,
    reviewCount: 334,
    priceTk: 330,
    color1: 'White',
    color2: 'Pink',
    imageColor: Color(0xFFE8C88A),
  ),
];

// ─── Page ────────────────────────────────────────────────────────────────────

class BrowseClothingPage extends StatefulWidget {
  const BrowseClothingPage({super.key});

  @override
  State<BrowseClothingPage> createState() => _BrowseClothingPageState();
}

class _BrowseClothingPageState extends State<BrowseClothingPage> {
  int _selectedCategory = 0;

  List<FabricItem> get _filtered {
    if (_selectedCategory == 0) return _fabrics;
    final cat = _categories[_selectedCategory];
    return _fabrics.where((f) => f.category == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const _Header(),
          _CategoryBar(
            selectedIndex: _selectedCategory,
            onSelected: (i) => setState(() => _selectedCategory = i),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          Expanded(
            child: _ProductGrid(items: _filtered),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF64CD57), Color(0xFF81D875), Color(0xFFD8F0D5)],
          stops: [0.0, 0.25, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          // Logo
          const Text(
            'Sketch2Stitch',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: Color(0xFF224F34),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 12),
          // Search bar
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0E8E8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF6A9C89)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: const [
                  Iconify(Mdi.magnify, color: Color(0xFF6A9C89), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Searches for fabrics and elements...',
                      style: TextStyle(
                        color: Color(0xFF6A9C89),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Cart icon
          Stack(
            children: [
              IconButton(
               icon: const Iconify(Mdi.cart,
    color: Color(0xFF16423C), size: 24),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF224F34),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          // User avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF224F34), width: 2),
              color: const Color(0xFFE8F4EE),
            ),
            child: const Iconify(Mdi.account,
                color: Color(0xFF224F34), size: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Category bar ────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF64CD57)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6A9C89)),
              ),
              alignment: Alignment.center,
              child: Text(
                _categories[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.black : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Product grid ─────────────────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.items});

  final List<FabricItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items in this category',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.60,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _ProductCard(item: items[i]),
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});

  final FabricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF16423C), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: item.imageColor,
                  ),
                  child: CustomPaint(
                    painter: _FabricTexturePainter(),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFF6A9C89)),
                    ),
                    child: Text(
                      item.category,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info section
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Rating
                  Row(
                    children: [
                      const Iconify(Mdi.star,
                          color: Color(0xFFFDE807), size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${item.rating} (${item.reviewCount})',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Price + color chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tk ${item.priceTk}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16423C),
                        ),
                      ),
                      Row(
                        children: [
                          _ColorChip(label: item.color1),
                          const SizedBox(width: 4),
                          _ColorChip(label: item.color2),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Add to cart
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF224F34),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Color chip ───────────────────────────────────────────────────────────────

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF4DD),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF6F6F6)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.black87),
      ),
    );
  }
}

// ─── Fabric texture painter ───────────────────────────────────────────────────

class _FabricTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    const spacing = 18.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_FabricTexturePainter old) => false;
}