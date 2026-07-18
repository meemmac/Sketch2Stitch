// lib/screens/customer/browsing/retailer_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';

class RetailerDetailScreen extends StatefulWidget {
  final Retailer retailer;

  const RetailerDetailScreen({
    super.key,
    required this.retailer,
  });

  @override
  State<RetailerDetailScreen> createState() => _RetailerDetailScreenState();
}

class _RetailerDetailScreenState extends State<RetailerDetailScreen> {
  bool _isFavorite = false;
  bool _showAllReviews = false;
  bool _showAllProducts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover Image (from database - products)
                  _buildCoverImage(),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  // Retailer info on image
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.retailer.shopName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingStars(rating: widget.retailer.rating, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.retailer.rating}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.retailer.address,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.retailer.phone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
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
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isFavorite = !_isFavorite;
                  });
                },
              ),
            ],
          ),
          
          // Body Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Section (from database - products description)
                  _buildAboutSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Products (from database)
                  _buildProductsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Reviews (from database)
                  _buildReviewsSection(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cover Image ──────────────────────────────────────────────────────

  Widget _buildCoverImage() {
    String imageUrl = 'assets/images/fab.jpg';
    
    // Try to get image from first product's first color option
    if (widget.retailer.products != null && widget.retailer.products!.isNotEmpty) {
      final firstProduct = widget.retailer.products!.first;
      if (firstProduct.colorOptions.isNotEmpty) {
        // Get the first color option's image
        final firstColor = firstProduct.colorOptions.first;
        if (firstColor.image != null && firstColor.image!.isNotEmpty) {
          imageUrl = firstColor.image!;
        }
      }
    }
    
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.store, size: 80, color: Colors.grey),
      ),
    );
  }

  // ─── About Section ──────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    // Get description from products (database)
    String description = 'Quality products with excellent customer service.';
    if (widget.retailer.products != null && widget.retailer.products!.isNotEmpty) {
      final desc = widget.retailer.products!.first.description;
      if (desc.isNotEmpty) {
        description = desc;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Shop',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ─── Products Section ─────────────────────────────────────────────────

  Widget _buildProductsSection() {
    final products = widget.retailer.products ?? [];
    
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show only 3 products when not showing all
    final displayProducts = _showAllProducts ? products : (products.length > 3 ? products.take(3).toList() : products);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (products.length > 3)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllProducts = !_showAllProducts;
                  });
                },
                child: Text(_showAllProducts ? 'Show Less' : 'See All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Use different layouts based on show all state
        _showAllProducts 
            ? _buildAllProductsGrid(products)
            : _buildHorizontalProductList(displayProducts),
      ],
    );
  }

  // ─── Horizontal Product List (Preview Mode) ────────────────────────────

  Widget _buildHorizontalProductList(List<Product> products) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final product = products[index];
          final String imageUrl = product.colorOptions.isNotEmpty && 
              product.colorOptions.first.image != null
              ? product.colorOptions.first.image!
              : 'assets/images/fab.jpg';
          
          return GestureDetector(
            onTap: () {
              _showProductDetailOverlay(context, product);
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Image.asset(
                      imageUrl,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                  // Product Info
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${product.colorOptions.length} colors',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Tk ${product.minPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C5C44),
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
        },
      ),
    );
  }

  // ─── All Products Grid (Show All Mode) ─────────────────────────────────

  Widget _buildAllProductsGrid(List<Product> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final String imageUrl = product.colorOptions.isNotEmpty && 
            product.colorOptions.first.image != null
            ? product.colorOptions.first.image!
            : 'assets/images/fab.jpg';
        
        return GestureDetector(
          onTap: () {
            _showProductDetailOverlay(context, product);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.asset(
                    imageUrl,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 130,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                // Product Info
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.productName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.palette,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${product.colorOptions.length} colors',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tk ${product.minPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C5C44),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Reviews Section ───────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    // Sample reviews - in production, these would come from the Reviews collection
    // where targetId == retailer.id and targetRole == 'retailer'
    final List<Map<String, dynamic>> sampleReviews = [
      {
        'name': 'Priya Sharma',
        'rating': 5.0,
        'comment': 'Great quality fabrics! The products matched the description perfectly.',
        'time': '3 days ago',
      },
      {
        'name': 'Amit Kumar',
        'rating': 4.5,
        'comment': 'Quick delivery and excellent packaging. Will order again.',
        'time': '1 week ago',
      },
      {
        'name': 'Sneha Patel',
        'rating': 4.0,
        'comment': 'Good products but shipping was a bit delayed.',
        'time': '2 weeks ago',
      },
    ];

    final displayReviews = _showAllReviews ? sampleReviews : sampleReviews.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sampleReviews.length > 2)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllReviews = !_showAllReviews;
                  });
                },
                child: Text(_showAllReviews ? 'Show Less' : 'See All'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...displayReviews.map((review) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildReviewCard(
            review['name'] as String,
            review['rating'] as double,
            review['comment'] as String,
            review['time'] as String,
          ),
        )),
      ],
    );
  }

  Widget _buildReviewCard(String name, double rating, String comment, String time) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[200],
                child: Text(
                  name[0],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        RatingStars(rating: rating, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          rating.toString(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Product Detail Overlay ──────────────────────────────────────────

  void _showProductDetailOverlay(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(product: product),
    );
  }
}