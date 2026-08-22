import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/models/customer.dart';
import 'package:sketch2stitch/services/review_service.dart';
import 'package:sketch2stitch/services/favorite_service.dart';
import 'package:sketch2stitch/services/browse_service.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';
import 'package:sketch2stitch/screens/customer/messaging/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Review Product Class ────────────────────────────────────────────────

class ReviewProduct {
  final String name;
  final String image;
  final double price;

  const ReviewProduct({
    required this.name,
    required this.image,
    required this.price,
  });
}

// ============================================================================
// RetailersPageBody
// ============================================================================

class RetailersPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final RetailersFilterData filterData;
  final UserRole userRole;
  final void Function(String retailerId)? onRetailerSelected;

  const RetailersPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
    this.userRole = UserRole.customer,
    this.onRetailerSelected,
  });

  @override
  State<RetailersPageBody> createState() => _RetailersPageBodyState();
}

class _RetailersPageBodyState extends State<RetailersPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BrowseService _browseService = BrowseService();
  final FavoriteService _favoriteService = FavoriteService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        return StreamBuilder<List<Retailer>>(
          stream: _browseService.getRetailersByFilter(
            minRating: widget.filterData.minRating > 0
                ? widget.filterData.minRating
                : null,
            location: widget.filterData.location != 'All'
                ? widget.filterData.location
                : null,
            sortBy: widget.filterData.sortBy,
            search: searchQuery.isNotEmpty ? searchQuery : null,
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
                      'Error loading retailers',
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

            final retailers = snapshot.data ?? [];

            if (retailers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Retailers found',
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

            return Column(
              children: [
                _buildHeroSection(),
                Expanded(
                  child: _buildRetailersGrid(retailers),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 8,
      ),
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
            'Quality Retailers',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trusted stores for premium fabrics and materials',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildHeroChip(Icons.verified, 'Authentic', isSmallScreen),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.price_check, 'Best Prices', isSmallScreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10 : 12,
        vertical: isSmall ? 4 : 5,
      ),
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

  Widget _buildRetailersGrid(List<Retailer> retailers) {
    if (retailers.isEmpty) {
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
              'No Retailers found',
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
    final cardAspectRatio = screenHeight < 700 ? 0.80 : 0.85;

    return GridView.builder(
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: cardAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: retailers.length,
      itemBuilder: (context, index) {
        final retailer = retailers[index];
        return _buildRetailerCard(retailer, isSmallScreen);
      },
    );
  }

  Widget _buildRetailerCard(Retailer retailer, bool isSmall) {
    final bool isTopRated = retailer.rating >= 4.8;
    String imageUrl = retailer.profilePicture ?? 'assets/images/fab.jpg';
    
    final bool isTailorOrRetailer = widget.userRole == UserRole.tailor || 
                                     widget.userRole == UserRole.retailer;

    return GestureDetector(
      onTap: () {
        if (widget.onRetailerSelected != null) {
          widget.onRetailerSelected!(retailer.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RetailerDetailScreen(
                retailer: retailer,
                userRole: widget.userRole,
                onRetailerSelected: widget.onRetailerSelected,
              ),
            ),
          );
        }
      },
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF6B8F71).withOpacity(0.12),
                                child: Icon(
                                  Icons.store,
                                  size: isSmall ? 36 : 40,
                                  color: const Color(0xFF4A7C59),
                                ),
                              ),
                            )
                          : Image.asset(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF6B8F71).withOpacity(0.12),
                                child: Icon(
                                  Icons.store,
                                  size: isSmall ? 36 : 40,
                                  color: const Color(0xFF4A7C59),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (isTopRated)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 8 : 10,
                          vertical: isSmall ? 4 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B8F71),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 0.3,
                          ),
                        ),
                        child: Text(
                          '⭐ Top Rated',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 6 : 8,
                        vertical: isSmall ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: isSmall ? 10 : 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            retailer.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                  isSmall ? 10 : 12,
                  isSmall ? 8 : 10,
                  isSmall ? 10 : 12,
                  isSmall ? 10 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      retailer.shopName,
                      style: TextStyle(
                        fontSize: isSmall ? 13 : 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmall ? 4 : 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: isSmall ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            retailer.generalArea,
                            style: TextStyle(
                              fontSize: isSmall ? 11 : 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isTailorOrRetailer) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '2.5 km',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
  }
}

// ============================================================================
// RetailerDetailScreen - WITH LIKED PRODUCTS SECTION
// ============================================================================

class RetailerDetailScreen extends StatefulWidget {
  final Retailer retailer;
  final VoidCallback? onBackPressed;
  final void Function(String retailerId)? onRetailerSelected;
  final UserRole userRole;

  const RetailerDetailScreen({
    super.key,
    required this.retailer,
    this.onBackPressed,
    this.onRetailerSelected,
    this.userRole = UserRole.customer,
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
  bool _isLoadingReviews = true;
  double _averageRating = 0.0;
  String _selectedFilter = "Top reviews";
  
  final ReviewService _reviewService = ReviewService();
  final FavoriteService _favoriteService = FavoriteService();
  final BrowseService _browseService = BrowseService();
  String? _currentUserId;

  List<Product> _products = [];
  bool _isLoadingProducts = true;

  // Cache for customer names
  final Map<String, String> _customerNameCache = {};
  
  // Cache for review products (Liked products)
  final Map<String, List<ReviewProduct>> _reviewProductsCache = {};
  
  // Stream subscription for reviews
  StreamSubscription? _reviewSubscription;

  // Categories
  final List<String> _elementCategories = ['Material'];
  final List<String> _fabricCategories = ['Fabric'];

  bool get _isCustomer => widget.userRole == UserRole.customer;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadReviewsUsingStream();
    _loadProducts();
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    _reviewSubscription?.cancel();
    super.dispose();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (_currentUserId != null) {
      try {
        final isFav = await _favoriteService
            .isFavoriteRetailer(_currentUserId!, widget.retailer.id)
            .first;
        setState(() {
          _isFavorite = isFav;
        });
      } catch (e) {
        // Ignore
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add favorites'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _favoriteService.toggleFavoriteRetailer(
        _currentUserId!, 
        widget.retailer.id
      );
      setState(() {
        _isFavorite = !_isFavorite;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Load reviews using stream that includes customer names and products
  void _loadReviewsUsingStream() {
    setState(() {
      _isLoading = true;
      _isLoadingReviews = true;
    });
    
    try {
      String retailerId = widget.retailer.id;
      
      _reviewSubscription?.cancel();
      
      _reviewSubscription = _reviewService.streamDetailedShopReviews(retailerId).listen(
        (detailedReviews) {
          
          if (!mounted) return;
          
          final reviews = <Review>[];
          final customerNames = <String, String>{};
          final reviewProducts = <String, List<ReviewProduct>>{};
          
          for (final item in detailedReviews) {
            final reviewMap = item['review'] as Map<String, dynamic>;
            final review = Review.fromJson(reviewMap);
            final userName = item['userName'] as String? ?? 'Customer';
            final productsList = item['products'] as List<dynamic>? ?? [];
            
            // Extract products (Liked products)
            final products = productsList.map((p) => ReviewProduct(
              name: p['name'] as String? ?? 'Unknown Product',
              image: p['image'] as String? ?? '',
              price: (p['price'] as num?)?.toDouble() ?? 0,
            )).toList();
            
            reviews.add(review);
            customerNames[review.customerId] = userName;
            reviewProducts[review.id] = products;
          }
          
          setState(() {
            _reviews = reviews;
            _customerNameCache.addAll(customerNames);
            _reviewProductsCache.addAll(reviewProducts);
            _isLoading = false;
            _isLoadingReviews = false;
            
            if (_reviews.isNotEmpty) {
              final sum = _reviews.fold(0.0, (total, review) => total + review.rating);
              _averageRating = sum / _reviews.length;
            } else {
              _averageRating = 0.0;
            }
          });
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isLoadingReviews = false;
              _reviews = [];
              _averageRating = 0.0;
            });
          }
        },
      );
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingReviews = false;
        _reviews = [];
        _averageRating = 0.0;
      });
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      String retailerId = widget.retailer.id;
      
      final allProducts = await _browseService.getProductsByFilter().first;
      
      List<Product> retailerProducts = [];
      
      if (retailerId.isNotEmpty) {
        retailerProducts = allProducts
            .where((p) => p.retailerId == retailerId)
            .toList();
      }
      
      if (retailerProducts.isEmpty) {
        try {
          final retailerSnapshot = await FirebaseFirestore.instance
              .collection('Retailer')
              .where('shopName', isEqualTo: widget.retailer.shopName)
              .limit(1)
              .get();
          
          if (retailerSnapshot.docs.isNotEmpty) {
            final doc = retailerSnapshot.docs.first;
            final foundRetailerId = doc.id;
            
            retailerProducts = allProducts
                .where((p) => p.retailerId == foundRetailerId)
                .toList();
          }
        } catch (e) {
        }
      }
      
      if (retailerProducts.isEmpty && widget.retailer.products != null) {
        retailerProducts = widget.retailer.products!;
      }
      
      if (retailerProducts.isNotEmpty) {
        for (final product in retailerProducts) {
        }
      }
      
      setState(() {
        _products = retailerProducts;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (widget.retailer.products != null) {
        setState(() {
          _products = widget.retailer.products!;
          _isLoadingProducts = false;
        });
      } else {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  bool _isElement(Product product) => _elementCategories.contains(product.category);
  bool _isFabric(Product product) => _fabricCategories.contains(product.category);

  List<Product> get _fabrics => _products.where((p) => _isFabric(p)).toList();
  List<Product> get _elements => _products.where((p) => _isElement(p)).toList();

  void _startConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: '${_currentUserId ?? 'customer'}_${widget.retailer.id}',
          customerId: _currentUserId ?? 'current_customer_id',
          otherUserId: widget.retailer.id,
          otherUserName: widget.retailer.shopName,
          otherUserRole: UserRole.retailer,
          otherUserAvatar: widget.retailer.profilePicture,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final isMediumScreen = screenWidth >= 380 && screenWidth < 600;
    
    final bool isTailorOrRetailer = widget.userRole == UserRole.tailor || 
                                     widget.userRole == UserRole.retailer;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isSmallScreen, isTailorOrRetailer),
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

  SliverAppBar _buildAppBar(bool isSmallScreen, bool isTailorOrRetailer) {
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
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: isSmallScreen ? 18 : 22,
          ),
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
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
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
                      RatingStars(
                        rating: widget.retailer.rating,
                        size: ratingSize,
                      ),
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
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
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
                            if (_isCustomer && !isTailorOrRetailer) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_bike,
                                      size: 10,
                                      color: Colors.white,
                                    ),
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
                      Icon(
                        Icons.phone,
                        size: isSmallScreen ? 14 : 16,
                        color: Colors.white70,
                      ),
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
      actions: _isCustomer
          ? [
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
                onPressed: _toggleFavorite,
              ),
            ]
          : [],
    );
  }

  Widget _buildCoverImage() {
    String imageUrl = 'assets/images/fab.jpg';
    
    if (widget.retailer.profilePicture != null && 
        widget.retailer.profilePicture!.isNotEmpty) {
      imageUrl = widget.retailer.profilePicture!;
    }
    
    if (imageUrl == 'assets/images/fab.jpg' && _products.isNotEmpty) {
      final firstProduct = _products.first;
      if (firstProduct.colorOptions.isNotEmpty) {
        final firstColor = firstProduct.colorOptions.first;
        if (firstColor.image.isNotEmpty) {
          imageUrl = firstColor.image.first;
        }
      }
    }
    
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.store, size: 80, color: Colors.grey),
        ),
      );
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
    String description = widget.retailer.about ?? 
        'Quality products with excellent customer service.';

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
                  vertical: isSmallScreen ? 6.0 : 8.0,
                ),
                decoration: BoxDecoration(
                  color: _showFabrics ? const Color(0xFF2C5C44) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Fabrics (${_fabrics.length})',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12.0 : 13.0,
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
                  vertical: isSmallScreen ? 6.0 : 8.0,
                ),
                decoration: BoxDecoration(
                  color: !_showFabrics ? const Color(0xFF2C5C44) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Elements (${_elements.length})',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12.0 : 13.0,
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

  Widget _buildProductsSection(bool isSmallScreen, bool isMediumScreen) {
    final products = _showFabrics ? _fabrics : _elements;

    if (_isLoadingProducts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF6B8F71)),
        ),
      );
    }

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
                  style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProductGrid(products, isSmallScreen, isMediumScreen),
      ],
    );
  }

  Widget _buildProductGrid(
    List<Product> products,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    final displayProducts = _showAllProducts
        ? products
        : (products.length > 6 ? products.take(6).toList() : products);
    final screenWidth = MediaQuery.of(context).size.width;
    final spacing = isSmallScreen ? 8.0 : 10.0;
    final imageHeight = isSmallScreen ? 100.0 : 120.0;
    final contentPadding = isSmallScreen ? 6.0 : 8.0;
    final fontSize = isSmallScreen ? 10.0 : 11.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 0.75,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        final coverImage = product.colorOptions.isNotEmpty
            ? (product.colorOptions.first.image.isNotEmpty ? product.colorOptions.first.image.first : null)
            : null;
        final bool outOfStock = product.colorOptions.every((c) => c.stock <= 0);
        final bool isElement = _isElement(product);

        return GestureDetector(
          onTap: () => _showProductDetailOverlay(context, product),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        width: double.infinity,
                        height: imageHeight,
                        color: Colors.grey[100],
                        child: coverImage != null && coverImage.isNotEmpty
                            ? (coverImage.startsWith('http')
                                ? Image.network(
                                    coverImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                          color: const Color(0xFF6B8F71).withOpacity(0.12),
                                          child: Icon(
                                            isElement ? Icons.category : Icons.texture,
                                            size: isSmallScreen ? 28 : 32,
                                            color: const Color(0xFF4A7C59),
                                          ),
                                        ),
                                  )
                                : Image.asset(
                                    coverImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                          color: const Color(0xFF6B8F71).withOpacity(0.12),
                                          child: Icon(
                                            isElement ? Icons.category : Icons.texture,
                                            size: isSmallScreen ? 28 : 32,
                                            color: const Color(0xFF4A7C59),
                                          ),
                                        ),
                                  ))
                            : Container(
                                color: const Color(0xFF6B8F71).withOpacity(0.12),
                                child: Icon(
                                  isElement ? Icons.category : Icons.texture,
                                  size: isSmallScreen ? 28 : 32,
                                  color: const Color(0xFF4A7C59),
                                ),
                              ),
                      ),
                    ),
                    if (!isElement)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 4 : 6,
                            vertical: isSmallScreen ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 0.3,
                            ),
                          ),
                          child: Text(
                            _materialBadgeText(product),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 7 : 8,
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
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 4 : 6,
                            vertical: isSmallScreen ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 0.3,
                            ),
                          ),
                          child: Text(
                            'Out of Stock',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 7 : 8,
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
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 3),
                      Text(
                        product.priceRange,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4A7C59),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!outOfStock && product.colorOptions.isNotEmpty) ...[
                        SizedBox(height: isSmallScreen ? 2 : 3),
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
    final double size = isSmall ? 8 : 10;
    return Opacity(
      opacity: outOfStock ? 0.35 : 1.0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5),
        ),
      ),
    );
  }

  Color _resolveColor(String name) {
    switch (name.toLowerCase()) {
      case 'white': return Colors.white;
      case 'black': return Colors.black;
      case 'pink': return Colors.pink[200]!;
      case 'blue': return Colors.blue[300]!;
      case 'green': return Colors.green[300]!;
      case 'beige': return const Color(0xFFE8DCC8);
      case 'brown': return Colors.brown[300]!;
      case 'gold': return const Color(0xFFD4AF37);
      case 'silver': return Colors.grey[400]!;
      case 'purple': return Colors.purple[300]!;
      default: return Colors.grey[300]!;
    }
  }

  String _materialBadgeText(Product product) {
    if (product.materialType.isEmpty) return "N/A";
    final material = product.materialType.first.type;
    if (material.isEmpty || material == "N/A") return "N/A";
    if (material.contains('%')) return material;
    if (material.contains(',')) {
      final parts = material.split(',').map((s) => s.trim()).toList();
      final hasPercentages = parts.any((p) => p.contains('%'));
      if (hasPercentages) return material;
      return "100% $material";
    }
    return "100% $material";
  }

  void _showReviewsOverlay(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _buildReviewsPage()),
    );
  }

  // ─── Reviews Page ─────────────────────────────────────────────────────────

  Widget _buildReviewsPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ratings & Reviews",
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.retailer.shopName,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _isLoadingReviews = true;
              });
              _loadReviewsUsingStream();
            },
          ),
        ],
      ),
      body: _isLoadingReviews
          ? const Center(child: CircularProgressIndicator())
          : StatefulBuilder(
              builder: (context, setState) {
                final filtered = _getFilteredReviews();
                
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRatingSummary(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Text(
                          "Reviews",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildFilterChips(setState),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text("No reviews found yet."),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) =>
                              _buildReviewsPageItem(filtered[index]),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRatingSummary() {
    final totalReviews = _reviews.length;
    
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
                  totalReviews > 0 ? _averageRating.toStringAsFixed(1) : '0.0',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) {
                      double starVal = index + 1;
                      IconData icon;
                      if (_averageRating >= starVal) {
                        icon = Icons.star;
                      } else if (_averageRating >= starVal - 0.5) {
                        icon = Icons.star_half;
                      } else {
                        icon = Icons.star_border;
                      }
                      return Icon(
                        icon,
                        color: Colors.orange,
                        size: 18,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$totalReviews reviews",
                  style: TextStyle(
                    color: totalReviews > 0 ? Colors.grey : Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _ratingBar(5, _getRatingCount(5.0)),
                _ratingBar(4, _getRatingCount(4.0)),
                _ratingBar(3, _getRatingCount(3.0)),
                _ratingBar(2, _getRatingCount(2.0)),
                _ratingBar(1, _getRatingCount(1.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(int star, int count) {
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

  int _getRatingCount(double rating) {
    return _reviews.where((r) => r.rating.round() == rating.round()).length;
  }

  Widget _buildFilterChips(StateSetter setState) {
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
                if (val) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                }
              },
              selectedColor: const Color(0xFF1E232C),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                ),
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

  Widget _buildReviewsPageItem(Review review) {
    final customerName = _customerNameCache[review.customerId] ?? 'Customer';
    final products = _reviewProductsCache[review.id] ?? [];
    
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating.floor() ? Icons.star : Icons.star_border,
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
            review.comment.isNotEmpty ? review.comment : 'No comment provided.',
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
                itemBuilder: (context, index) => _buildProductMiniCard(products[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductMiniCard(ReviewProduct product) {
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
            child: _buildImage(product.image, 50, 50),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  "Tk ${product.price.toInt()}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String path, double width, double height) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint("ReviewScreen: Error loading network image: $path - $error");
          return _imagePlaceholder(width, height);
        },
      );
    } else if (path.isNotEmpty) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint("ReviewScreen: Error loading asset image: $path - $error");
          return _imagePlaceholder(width, height);
        },
      );
    } else {
      return _imagePlaceholder(width, height);
    }
  }

  Widget _imagePlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, color: Colors.grey),
    );
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
        customerId: _currentUserId,
        favoriteService: _favoriteService,
      ),
    );
  }
}