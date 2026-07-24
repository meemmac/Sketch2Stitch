// lib/screens/customer/browsing/retailer_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/review.dart';
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
  bool _showAllProducts = false;
  List<Review> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    final sampleReviews = [
      Review(
        id: 'R001',
        customerId: 'C001',
        targetId: widget.retailer.id,
        targetRole: ReviewTargetRole.retailer,
        orderId: 'O001',
        rating: 5.0,
        comment: 'Very soft fabric and perfect stitching.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'R002',
        customerId: 'C002',
        targetId: widget.retailer.id,
        targetRole: ReviewTargetRole.retailer,
        orderId: 'O002',
        rating: 4.0,
        comment: 'Color is exactly like the picture.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'R003',
        customerId: 'C003',
        targetId: widget.retailer.id,
        targetRole: ReviewTargetRole.retailer,
        orderId: 'O003',
        rating: 5.0,
        comment: 'Excellent quality.',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'R004',
        customerId: 'C004',
        targetId: widget.retailer.id,
        targetRole: ReviewTargetRole.retailer,
        orderId: 'O004',
        rating: 4.5,
        comment: 'Great fabric quality and fast delivery.',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Review(
        id: 'R005',
        customerId: 'C005',
        targetId: widget.retailer.id,
        targetRole: ReviewTargetRole.retailer,
        orderId: 'O005',
        rating: 3.5,
        comment: 'Good product but packaging could be better.',
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
    ];

    setState(() {
      _reviews = sampleReviews;
      _isLoading = false;
      if (_reviews.isNotEmpty) {
        final sum = _reviews.fold(0.0, (total, review) => total + review.rating);
        _averageRating = sum / _reviews.length;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final isMediumScreen = screenWidth >= 380 && screenWidth < 600;
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isSmallScreen),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAboutSection(isSmallScreen),
                  const SizedBox(height: 24),
                  _buildProductsSection(isSmallScreen, isMediumScreen),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── App Bar ───────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(bool isSmallScreen) {
    final ratingSize = isSmallScreen ? 12.0 : 16.0;
    final fontSize = isSmallScreen ? 20.0 : 24.0;
    final buttonPadding = isSmallScreen ? 8.0 : 12.0;
    
    return SliverAppBar(
      expandedHeight: isSmallScreen ? 240 : 280,
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
          child: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: isSmallScreen ? 18 : 22,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildCoverImage(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
            ),
            Positioned(
              bottom: isSmallScreen ? 12 : 20,
              left: isSmallScreen ? 12 : 20,
              right: isSmallScreen ? 12 : 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.retailer.shopName,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RatingStars(rating: widget.retailer.rating, size: ratingSize),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.retailer.rating}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                          color: Colors.white70,
                        ),
                      ),
                      if (!isSmallScreen) ...[
                        const SizedBox(width: 12),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _showReviewsOverlay(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: buttonPadding * 1.5,
                            vertical: isSmallScreen ? 6.0 : 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reviews,
                                color: Colors.white,
                                size: isSmallScreen ? 16 : 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Reviews',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13.0 : 15.0,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: isSmallScreen ? 14 : 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.retailer.address,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11.0 : 13.0,
                                  color: Colors.white70,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_bike, size: 10, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '2.5 km • Tk 50',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: isSmallScreen ? 14 : 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.retailer.phone,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11.0 : 13.0,
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
            size: isSmallScreen ? 22 : 24,
          ),
          onPressed: () => setState(() => _isFavorite = !_isFavorite),
        ),
      ],
    );
  }

  // ─── Cover Image ──────────────────────────────────────────────────────

  Widget _buildCoverImage() {
    String imageUrl = 'assets/images/fab.jpg';
    
    if (widget.retailer.products != null && widget.retailer.products!.isNotEmpty) {
      final firstProduct = widget.retailer.products!.first;
      if (firstProduct.colorOptions.isNotEmpty) {
        final firstColor = firstProduct.colorOptions.first;
        if (firstColor.image != null && firstColor.image!.isNotEmpty) {
          imageUrl = firstColor.image!;
        }
      }
    }
    
    if (widget.retailer.profilePicture != null) {
      imageUrl = widget.retailer.profilePicture!;
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

  Widget _buildAboutSection(bool isSmallScreen) {
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
        Text(
          'About Shop',
          style: TextStyle(
            fontSize: isSmallScreen ? 18.0 : 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: isSmallScreen ? 14.0 : 15.0,
            color: Colors.grey,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ─── Products Section ─────────────────────────────────────────────────

  Widget _buildProductsSection(bool isSmallScreen, bool isMediumScreen) {
    final products = widget.retailer.products ?? [];
    
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Products',
              style: TextStyle(
                fontSize: isSmallScreen ? 18.0 : 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (products.length > 6)
              TextButton(
                onPressed: () => setState(() => _showAllProducts = !_showAllProducts),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8.0 : 16.0,
                    vertical: isSmallScreen ? 4.0 : 8.0,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showAllProducts ? 'Show Less' : 'See All',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13.0 : 15.0,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProductGrid(products, isSmallScreen, isMediumScreen),
      ],
    );
  }

  // ─── Product Grid ──────────────────────────────────────────────────────

  Widget _buildProductGrid(List<Product> products, bool isSmallScreen, bool isMediumScreen) {
    final displayProducts = _showAllProducts 
        ? products 
        : (products.length > 6 ? products.take(6).toList() : products);

    int crossAxisCount = 2;
    double aspectRatio = isSmallScreen ? 0.65 : 0.75;
    double spacing = isSmallScreen ? 8.0 : 12.0;
    double imageHeight = isSmallScreen ? 100.0 : 130.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        final String imageUrl = product.colorOptions.isNotEmpty && 
            product.colorOptions.first.image != null
            ? product.colorOptions.first.image!
            : 'assets/images/fab.jpg';
        
        return GestureDetector(
          onTap: () => _showProductDetailOverlay(context, product),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.asset(
                    imageUrl,
                    height: imageHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: imageHeight,
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image,
                        color: Colors.grey,
                        size: isSmallScreen ? 30 : 40,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.productName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.category,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10.0 : 12.0,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.palette,
                            size: isSmallScreen ? 10.0 : 12.0,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${product.colorOptions.length} colors',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 9.0 : 11.0,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
<<<<<<< HEAD
                      Text(
                        'Tk ${product.minPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13.0 : 15.0,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C5C44),
                        ),
=======
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tk ${product.minPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12.0 : 14.0,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2C5C44),
                              ),
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
>>>>>>> 977229e57af49ae7a87676d31f07edecd1bf7fb6
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

  // ─── Reviews Overlay ────────────────────────────────────────────────────

  void _showReviewsOverlay(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: isSmallScreen ? 500 : 600,
            ),
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Reviews',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18.0 : 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_reviews.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.rate_review, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No reviews yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Be the first to review this retailer!',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  _buildRatingSummary(isSmallScreen),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: _reviews.map((review) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildReviewCard(review, isSmallScreen),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Rating Summary ─────────────────────────────────────────────────────

  Widget _buildRatingSummary(bool isSmallScreen) {
    final starSize = isSmallScreen ? 32.0 : 40.0;
    final ratingSize = isSmallScreen ? 24.0 : 28.0;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: starSize,
                ),
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: ratingSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_reviews.length} Reviews',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.0 : 14.0,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildRatingRow(5, _getRatingCount(5.0), isSmallScreen),
                _buildRatingRow(4, _getRatingCount(4.0), isSmallScreen),
                _buildRatingRow(3, _getRatingCount(3.0), isSmallScreen),
                _buildRatingRow(2, _getRatingCount(2.0), isSmallScreen),
                _buildRatingRow(1, _getRatingCount(1.0), isSmallScreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(int stars, int count, bool isSmallScreen) {
    final total = _reviews.length;
    final percentage = total > 0 ? (count / total) : 0.0;
    final fontSize = isSmallScreen ? 10.0 : 12.0;
    final iconSize = isSmallScreen ? 12.0 : 14.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 1.0 : 2.0),
      child: Row(
        children: [
          Text(
            '$stars',
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
          ),
          Icon(
            Icons.star,
            color: Colors.amber,
            size: iconSize,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[200],
                color: percentage > 0 ? Colors.amber : Colors.grey[300],
                minHeight: isSmallScreen ? 4.0 : 6.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 25,
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  int _getRatingCount(double rating) {
    return _reviews.where((r) => r.rating == rating).length;
  }

  // ─── Review Card ──────────────────────────────────────────────────────

  Widget _buildReviewCard(Review review, bool isSmallScreen) {
    final Map<String, Map<String, dynamic>> reviewDetails = {
      'R001': {
        'name': 'Priya Sharma',
        'products': [
          {'name': 'Blue Cotton Kurti', 'quantity': 2, 'price': 850},
          {'name': 'Matching Thread', 'quantity': 1, 'price': 150},
        ]
      },
      'R002': {
        'name': 'Amina Rahman',
        'products': [
          {'name': 'Floral Dress', 'quantity': 1, 'price': 1200},
        ]
      },
      'R003': {
        'name': 'Nusrat Jahan',
        'products': [
          {'name': 'Linen Blazer', 'quantity': 1, 'price': 2500},
          {'name': 'Buttons Set', 'quantity': 1, 'price': 200},
        ]
      },
      'R004': {
        'name': 'Tahsin Ahmed',
        'products': [
          {'name': 'Silk Saree', 'quantity': 1, 'price': 3500},
        ]
      },
      'R005': {
        'name': 'Farhana Islam',
        'products': [
          {'name': 'Cotton Shirt', 'quantity': 3, 'price': 1800},
        ]
      },
    };

    final details = reviewDetails[review.id] ?? {'name': 'Anonymous', 'products': []};
    final customerName = details['name'] as String;
    final products = details['products'] as List<Map<String, dynamic>>;
    final avatarSize = isSmallScreen ? 18.0 : 22.0;
    final nameSize = isSmallScreen ? 13.0 : 15.0;
    final commentSize = isSmallScreen ? 13.0 : 15.0;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: avatarSize,
                backgroundColor: const Color(0xFF2C5C44).withValues(alpha: 0.1),
                child: Text(
                  customerName.isNotEmpty ? customerName[0] : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C5C44),
                    fontSize: isSmallScreen ? 13.0 : 15.0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: nameSize,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: isSmallScreen ? 14.0 : 16.0,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          review.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12.0 : 14.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          review.timeAgo,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11.0 : 12.0,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Ordered Products Section (like foodpanda)
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: isSmallScreen ? 14 : 16,
                      color: const Color(0xFF2C5C44),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ordered Items',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11.0 : 12.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...products.map((product) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${product['quantity']}x ${product['name']}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11.0 : 12.0,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      Text(
                        'Tk ${product['price']}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11.0 : 12.0,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2C5C44),
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.0 : 13.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Tk ${products.fold<int>(0, (sum, p) => sum + (p['price'] as int))}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.0 : 13.0,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C5C44),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          Text(
            review.comment,
            style: TextStyle(
              fontSize: commentSize,
              color: Colors.grey[700],
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
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