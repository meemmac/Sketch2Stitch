import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/widgets/dashboard_drawer.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/messaging/conversations_screen.dart';

class RetailerDetailScreen extends StatefulWidget {
  final Retailer retailer;
  final VoidCallback? onBackPressed;
  final void Function(String retailerId)? onRetailerSelected;
  final AppUserRole userRole;

  const RetailerDetailScreen({
    super.key,
    required this.retailer,
    this.onBackPressed,
    this.onRetailerSelected,
    this.userRole = AppUserRole.customer,
  });

  @override
  State<RetailerDetailScreen> createState() => _RetailerDetailScreenState();
}

class _RetailerDetailScreenState extends State<RetailerDetailScreen> {
  bool _isFavorite = false;
  bool _showAllProducts = false;
  bool _showFabrics = true;
  List<Review> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;
  String _selectedFilter = "Top reviews";

  final List<String> _customerNames = [
    'Priya Sharma', 'Amina Rahman', 'Nusrat Jahan', 'Tahsin Ahmed', 'Farhana Islam',
    'Rafi Hasan', 'Sadia Akhter'
  ];

  final List<String> _productImages = [
    'assets/images/fab.jpg', 'assets/images/silk.jpg', 'assets/images/lace.jpg',
    'assets/images/textile.jpg', 'assets/images/fab2.jpg', 'assets/images/gorgeous.jpg',
  ];

  final List<String> _elementCategories = [
    'Fasteners', 'Buttons', 'Threads', 'Embellishments', 'Trims', 'Ribbons'
  ];

  bool get _isCustomer => widget.userRole == AppUserRole.customer;

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
        comment: 'Great quality products! Everything matched the description perfectly.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'R002',
        customerId: 'C002',
        targetId: widget.retailer.id,
        targetRole: ReviewTargetRole.retailer,
        orderId: 'O002',
        rating: 4.5,
        comment: 'Quick delivery and excellent packaging. Will order again.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'R003',
        customerId: 'C003',
        targetId: widget.retailer.id,
        targetRole: ReviewTargetRole.retailer,
        orderId: 'O003',
        rating: 4.0,
        comment: 'Good products but shipping was a bit delayed.',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'R004',
        customerId: 'C004',
        targetId: widget.retailer.id,
        targetRole: ReviewTargetRole.retailer,
        orderId: 'O004',
        rating: 4.5,
        comment: 'Great quality and fast delivery.',
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

  String _getCustomerName(int index) => _customerNames[index % _customerNames.length];
  String _getProductName(int index, List<String> productNames) => productNames.isEmpty ? 'Product ${index + 1}' : productNames[index % productNames.length];
  String _getProductImage(int index) => _productImages[index % _productImages.length];
  double _getProductPrice(int index, List<double> productPrices) => productPrices.isEmpty ? 0 : productPrices[index % productPrices.length];

  bool _isElement(Product product) => _elementCategories.contains(product.category);
  bool _isFabric(Product product) => !_isElement(product);

  List<Product> get _fabrics => widget.retailer.products?.where((p) => _isFabric(p)).toList() ?? [];
  List<Product> get _elements => widget.retailer.products?.where((p) => _isElement(p)).toList() ?? [];

  void _startConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationsScreen(
          customerId: 'current_customer_id',
        ),
      ),
    );
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
                  if (_fabrics.isNotEmpty && _elements.isNotEmpty)
                    _buildCategoryToggle(isSmallScreen),
                  const SizedBox(height: 12),
                  _buildProductsSection(isSmallScreen, isMediumScreen),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryToggle(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showFabrics = true),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12.0 : 16.0,
                  vertical: isSmallScreen ? 8.0 : 10.0,
                ),
                decoration: BoxDecoration(
                  color: _showFabrics ? const Color(0xFF2C5C44) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Fabrics (${_fabrics.length})',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13.0 : 14.0,
                      fontWeight: FontWeight.w600,
                      color: _showFabrics ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showFabrics = false),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12.0 : 16.0,
                  vertical: isSmallScreen ? 8.0 : 10.0,
                ),
                decoration: BoxDecoration(
                  color: !_showFabrics ? const Color(0xFF2C5C44) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Elements (${_elements.length})',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13.0 : 14.0,
                      fontWeight: FontWeight.w600,
                      color: !_showFabrics ? Colors.white : Colors.grey[700],
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

  SliverAppBar _buildAppBar(bool isSmallScreen) {
    final ratingSize = isSmallScreen ? 12.0 : 14.0;
    final fontSize = isSmallScreen ? 20.0 : 22.0;
    
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
          child: Icon(Icons.arrow_back, color: Colors.white, size: isSmallScreen ? 18 : 22),
        ),
        onPressed: () {
          if (widget.onBackPressed != null) {
            widget.onBackPressed!();
          } else {
            Navigator.pop(context);
          }
        },
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
                          fontSize: isSmallScreen ? 12.0 : 13.0,
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
                            horizontal: isSmallScreen ? 12.0 : 16.0,
                            vertical: isSmallScreen ? 6.0 : 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reviews,
                                color: Colors.white,
                                size: isSmallScreen ? 14 : 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isSmallScreen ? 'Reviews' : 'See Reviews',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11.0 : 13.0,
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
                      Icon(Icons.location_on, size: isSmallScreen ? 14 : 16, color: Colors.white70),
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
                            if (_isCustomer) ...[
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
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone, size: isSmallScreen ? 14 : 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.retailer.phone,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11.0 : 13.0,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
      actions: _isCustomer ? [
        IconButton(
          icon: Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: isSmallScreen ? 22 : 24,
          ),
          onPressed: _startConversation,
        ),
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.white,
            size: isSmallScreen ? 22 : 24,
          ),
          onPressed: () => setState(() => _isFavorite = !_isFavorite),
        ),
      ] : [],
    );
  }

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

  Widget _buildAboutSection(bool isSmallScreen) {
    String description = widget.retailer.about ?? 'Quality products with excellent customer service.';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Shop',
          style: TextStyle(
            fontSize: isSmallScreen ? 16.0 : 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: isSmallScreen ? 13.0 : 14.0,
            color: Colors.grey,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection(bool isSmallScreen, bool isMediumScreen) {
    final products = _showFabrics ? _fabrics : _elements;

    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(
                _showFabrics ? Icons.texture : Icons.category,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                _showFabrics ? 'No fabrics available' : 'No elements available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _showFabrics ? 'Fabrics' : 'Elements',
              style: TextStyle(
                fontSize: isSmallScreen ? 16.0 : 18.0,
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
                    fontSize: isSmallScreen ? 12.0 : 14.0,
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

  Widget _buildProductGrid(List<Product> products, bool isSmallScreen, bool isMediumScreen) {
    final displayProducts = _showAllProducts ? products : (products.length > 6 ? products.take(6).toList() : products);
    final screenWidth = MediaQuery.of(context).size.width;
    final spacing = isSmallScreen ? 10.0 : 12.0;
    
    final cardWidth = (screenWidth - (spacing * 3)) / 2;
    final cardHeight = isSmallScreen ? 220.0 : 240.0;
    final imageHeight = isSmallScreen ? 130.0 : 150.0;
    final contentPadding = isSmallScreen ? 8.0 : 10.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: cardWidth / cardHeight,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        final coverImage = product.colorOptions.isNotEmpty
            ? product.colorOptions.first.image
            : null;
        final bool outOfStock =
            product.colorOptions.every((c) => c.stock <= 0);
        final bool isElement = _isElement(product);

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
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: Container(
                        width: double.infinity,
                        height: imageHeight,
                        color: Colors.grey[100],
                        child: coverImage != null
                            ? Image.asset(
                                coverImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: kSage.withValues(alpha: 0.12),
                                  child: Icon(
                                    isElement ? Icons.category : Icons.texture,
                                    size: isSmallScreen ? 36 : 40,
                                    color: kSageDark,
                                  ),
                                ),
                              )
                            : Container(
                                color: kSage.withValues(alpha: 0.12),
                                child: Icon(
                                  isElement ? Icons.category : Icons.texture,
                                  size: isSmallScreen ? 36 : 40,
                                  color: kSageDark,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 8, 
                          vertical: isSmallScreen ? 3 : 4
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.3,
                          ),
                        ),
                        child: Text(
                          product.category,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 9 : 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    if (outOfStock)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6 : 8, 
                            vertical: isSmallScreen ? 3 : 4
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.3,
                            ),
                          ),
                          child: Text(
                            'Out of Stock',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 9 : 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.all(contentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.productName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      Text(
                        product.priceRange,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w700,
                          color: kSageDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!outOfStock && product.colorOptions.isNotEmpty) ...[
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Wrap(
                          spacing: isSmallScreen ? 2 : 3,
                          runSpacing: 2,
                          children: product.colorOptions
                              .take(4)
                              .map((option) => _colorDot(option, isSmallScreen))
                              .toList(),
                        ),
                      ],
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

  Widget _colorDot(ColorOption option, bool isSmall) {
    final color = _resolveColor(option.color);
    final bool outOfStock = option.stock <= 0;
    final double size = isSmall ? 10 : 12;
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

  void _showReviewsOverlay(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _buildReviewsPage()),
    );
  }

  Widget _buildReviewsPage() {
    final filtered = _getFilteredReviews();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ratings & Reviews",
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.retailer.shopName,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReviewsPageSummary(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                "Reviews",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            _buildReviewsPageFilterChips(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_reviews.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.rate_review, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No reviews yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                      SizedBox(height: 4),
                      Text('Be the first to review this retailer!', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) => _buildReviewsPageItem(filtered[index], index),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsPageSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < _averageRating.floor()
                          ? Icons.star
                          : (index < _averageRating.ceil() ? Icons.star_half : Icons.star_border),
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_reviews.length}+ All ratings",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _reviewsPageRatingBar(5, _getRatingCount(5.0)),
                _reviewsPageRatingBar(4, _getRatingCount(4.0)),
                _reviewsPageRatingBar(3, _getRatingCount(3.0)),
                _reviewsPageRatingBar(2, _getRatingCount(2.0)),
                _reviewsPageRatingBar(1, _getRatingCount(1.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewsPageRatingBar(int star, int count) {
    final total = _reviews.length;
    final percent = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text("$star", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Icon(Icons.star, color: Colors.orange, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.grey.shade100,
                color: Colors.orange,
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsPageFilterChips() {
    final filters = ["Top reviews", "Newest", "Highest rating", "Lowest rating"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = filter);
              },
              selectedColor: const Color(0xFF1E232C),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Review> _getFilteredReviews() {
    List<Review> sortedList = List.from(_reviews);
    switch (_selectedFilter) {
      case "Top reviews":
        sortedList.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case "Newest":
        sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case "Highest rating":
        sortedList.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case "Lowest rating":
        sortedList.sort((a, b) => a.rating.compareTo(b.rating));
        break;
    }
    return sortedList;
  }

  int _getRatingCount(double rating) => _reviews.where((r) => r.rating == rating).length;

  Widget _buildReviewsPageItem(Review review, int index) {
    final customerName = _getCustomerName(index);
    final productNames = widget.retailer.products?.map((p) => p.productName).toList() ?? [];
    final productPrices = widget.retailer.products?.map((p) => p.minPrice).toList() ?? [];
    final products = _getReviewProducts(index, productNames, productPrices);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customerName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (starIndex) => Icon(
                    starIndex < review.rating.floor() ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "• ${review.timeAgo}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Liked products",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _buildReviewsPageProductCard(products[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsPageProductCard(Map<String, dynamic> product) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              product['image'],
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.texture, size: 20, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  "Tk ${(product['price'] as double).toInt()}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getReviewProducts(int index, List<String> productNames, List<double> productPrices) {
    final products = <Map<String, dynamic>>[];
    final productName = _getProductName(index, productNames);
    final productImage = _getProductImage(index);
    final productPrice = _getProductPrice(index, productPrices);
    
    if (productName.isNotEmpty) {
      products.add({
        'name': productName,
        'image': productImage,
        'price': productPrice,
      });
    }
    
    if (productNames.length > index + 1) {
      products.add({
        'name': productNames[index + 1],
        'image': _getProductImage(index + 1),
        'price': productPrices[index + 1],
      });
    }
    
    return products;
  }

  void _showProductDetailOverlay(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(
        product: product,
        isFabric: _isFabric(product),
        retailerName: widget.retailer.shopName,
        userRole: widget.userRole,
      ),
    );
  }
}