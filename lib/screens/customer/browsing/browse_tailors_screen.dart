import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/services/browse_service.dart';
import 'package:sketch2stitch/services/favorite_service.dart';
import 'package:sketch2stitch/services/review_service.dart';
import 'package:sketch2stitch/services/portfolio_service.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/messaging/chat_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// TailorsPageBody
// ============================================================================

class TailorsPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final TailorsFilterData filterData;
  final void Function(String tailorId)? onTailorSelected;
  final UserRole userRole;

  const TailorsPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
    this.onTailorSelected,
    this.userRole = UserRole.customer,
  });

  @override
  State<TailorsPageBody> createState() => _TailorsPageBodyState();
}

class _TailorsPageBodyState extends State<TailorsPageBody>
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
        return StreamBuilder<List<Tailor>>(
          stream: _browseService.getTailorsByFilter(
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
                      'Error loading tailors',
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

            final tailors = snapshot.data ?? [];

            if (tailors.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Tailors found',
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
                  child: _buildTailorsGrid(tailors),
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
            'Expert Tailors',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Skilled professionals for your custom designs',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildHeroChip(Icons.verified, 'Verified', isSmallScreen),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.star, 'Quality Assured', isSmallScreen),
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

  Widget _buildTailorsGrid(List<Tailor> tailors) {
    if (tailors.isEmpty) {
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
              'No Tailors found',
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
      itemCount: tailors.length,
      itemBuilder: (context, index) {
        final tailor = tailors[index];
        return _buildTailorCard(tailor, isSmallScreen);
      },
    );
  }

  Widget _buildTailorCard(Tailor tailor, bool isSmall) {
    final bool isTopRated = tailor.rating >= 4.8;
    final bool isFull = tailor.maxOrder == 0;
    String imageUrl = tailor.profilePicture ?? 'assets/images/fab.jpg';
    
    // Check if user is Tailor or Retailer
    final bool isTailorOrRetailer = widget.userRole == UserRole.tailor || 
                                     widget.userRole == UserRole.retailer;

    return GestureDetector(
      onTap: () {
        if (widget.onTailorSelected != null) {
          widget.onTailorSelected!(tailor.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TailorDetailScreen(
                tailor: tailor,
                userRole: widget.userRole,
                onTailorSelected: widget.onTailorSelected,
              ),
            ),
          );
        }
      },
      child: Opacity(
        opacity: isFull ? 0.65 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFull ? Colors.grey.shade300 : const Color(0xFFE8ECF0), 
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isFull ? 0.02 : 0.05),
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
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            isFull ? Colors.black.withOpacity(0.2) : Colors.transparent,
                            BlendMode.darken,
                          ),
                          child: imageUrl.startsWith('http')
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFF6B8F71).withOpacity(0.12),
                                    child: Icon(
                                      Icons.person,
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
                                      Icons.person,
                                      size: isSmall ? 36 : 40,
                                      color: const Color(0xFF4A7C59),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (isTopRated && !isFull)
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFull)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmall ? 6 : 8,
                                vertical: isSmall ? 3 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "Fully Booked",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmall ? 9 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Container(
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
                                  tailor.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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
                        tailor.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: isFull ? Colors.grey.shade700 : Colors.black,
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
                            color: isFull ? Colors.grey.shade400 : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              tailor.generalArea,
                              style: TextStyle(
                                fontSize: 11,
                                color: isFull ? Colors.grey.shade400 : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Only show delivery info for customers
                      if (!isTailorOrRetailer) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.directions_bike_outlined,
                              size: isSmall ? 12 : 14,
                              color: isFull ? Colors.grey.shade400 : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "1.8 km",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isFull ? Colors.grey.shade400 : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TailorDetailScreen - FIXED REVIEW LOADING
// ============================================================================

class TailorDetailScreen extends StatefulWidget {
  final Tailor tailor;
  final void Function(String tailorId)? onTailorSelected;
  final UserRole userRole;

  const TailorDetailScreen({
    super.key,
    required this.tailor,
    this.onTailorSelected,
    this.userRole = UserRole.customer,
  });

  @override
  State<TailorDetailScreen> createState() => _TailorDetailScreenState();
}

class _TailorDetailScreenState extends State<TailorDetailScreen> {
  bool _isFavorite = false;
  bool _showAllPortfolio = false;
  List<Review> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingReviews = true;
  double _averageRating = 0.0;
  String _selectedFilter = "All reviews";
  
  final ReviewService _reviewService = ReviewService();
  final FavoriteService _favoriteService = FavoriteService();
  final PortfolioService _portfolioService = PortfolioService();
  String? _currentUserId;
  
  List<Portfolio> _portfolioItems = [];
  bool _isLoadingPortfolio = true;

  bool get _isCustomer => widget.userRole == UserRole.customer;
  bool get isUnavailable => widget.tailor.maxOrder == 0;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadReviews();
    _loadPortfolio();
    _checkFavoriteStatus();
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
            .isFavoriteTailor(_currentUserId!, widget.tailor.id)
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
      await _favoriteService.toggleFavoriteTailor(_currentUserId!, widget.tailor.id);
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

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _isLoadingReviews = true;
    });
    try {
      // Load reviews for this tailor with targetRole = 'tailor'
      final reviews = await _reviewService.getReviewsByTargetId(
        widget.tailor.id,
        ReviewTargetRole.tailor,
        limit: 50,
      );
      
      print('✅ Loaded ${reviews.length} reviews for tailor: ${widget.tailor.name} (ID: ${widget.tailor.id})');
      
      // Debug: Print each review to verify data
      for (final review in reviews) {
        print('   - Review: rating=${review.rating}, comment=${review.comment}, customer=${review.customerId}');
      }
      
      setState(() {
        _reviews = reviews;
        _isLoading = false;
        _isLoadingReviews = false;
        if (_reviews.isNotEmpty) {
          final sum = _reviews.fold(0.0, (total, review) => total + review.rating);
          _averageRating = sum / _reviews.length;
        } else {
          _averageRating = 0.0;
        }
      });
    } catch (e) {
      print('❌ Error loading reviews: $e');
      setState(() {
        _isLoading = false;
        _isLoadingReviews = false;
        _reviews = [];
        _averageRating = 0.0;
      });
    }
  }

  // FIXED: Updated _loadPortfolio to handle both manual and auto-generated IDs
  Future<void> _loadPortfolio() async {
    setState(() => _isLoadingPortfolio = true);
    try {
      // First check if tailor has portfolio in the object
      if (widget.tailor.portfolio != null && widget.tailor.portfolio!.isNotEmpty) {
        print('📦 Using portfolio from tailor object: ${widget.tailor.portfolio!.length} items');
        setState(() {
          _portfolioItems = widget.tailor.portfolio!;
          _isLoadingPortfolio = false;
        });
        return;
      }
      
      // Load from Firestore using PortfolioService
      print('🔍 Loading portfolio for tailor: ${widget.tailor.id}, Name: ${widget.tailor.name}');
      
      // Try direct query first
      final result = await _portfolioService.getTailorPortfolio(
        widget.tailor.id,
        pageSize: 20,
      );
      
      print('✅ Loaded ${result.items.length} portfolio items for tailor ${widget.tailor.id}');
      if (result.items.isNotEmpty) {
        for (final item in result.items) {
          print('   - Portfolio item: ${item.id}, image: ${item.image}, description: ${item.description}');
        }
      }
      
      setState(() {
        _portfolioItems = result.items;
        _isLoadingPortfolio = false;
      });
      
      // If still no portfolio items, try alternative approach
      if (_portfolioItems.isEmpty) {
        print('⚠️ No portfolio items found, trying fallback method...');
        await _loadPortfolioFallback();
      }
    } catch (e) {
      print('❌ Error loading portfolio: $e');
      // Try fallback method
      await _loadPortfolioFallback();
    }
  }

  // Fallback method to try finding portfolio by tailor name
  Future<void> _loadPortfolioFallback() async {
    try {
      print('🔍 Fallback: Trying to find portfolio by tailor name: ${widget.tailor.name}');
      
      // Get all portfolio items and filter by tailor name
      final allPortfolioSnapshot = await FirebaseFirestore.instance
          .collection('Portfolio')
          .get();
      
      final List<Portfolio> foundItems = [];
      
      for (final doc in allPortfolioSnapshot.docs) {
        final data = doc.data();
        final tailorId = data['tailorId'] as String?;
        
        if (tailorId != null) {
          // Check if this tailorId exists and matches the name
          final tailorDoc = await FirebaseFirestore.instance
              .collection('Tailor')
              .doc(tailorId)
              .get();
          
          if (tailorDoc.exists) {
            final tailorData = tailorDoc.data();
            final name = tailorData?['name'] as String?;
            if (name == widget.tailor.name) {
              foundItems.add(Portfolio.fromJson({...data, 'id': doc.id}));
              print('   ✅ Found portfolio item for tailor: $name');
            }
          }
        }
      }
      
      if (foundItems.isNotEmpty) {
        print('✅ Fallback: Found ${foundItems.length} portfolio items for tailor: ${widget.tailor.name}');
        setState(() {
          _portfolioItems = foundItems;
          _isLoadingPortfolio = false;
        });
      } else {
        print('❌ Fallback: No portfolio items found for tailor: ${widget.tailor.name}');
        setState(() => _isLoadingPortfolio = false);
      }
    } catch (e) {
      print('❌ Fallback error: $e');
      setState(() => _isLoadingPortfolio = false);
    }
  }

  void _showPortfolioOverlay(Portfolio portfolioItem) {
    final imagePath = portfolioItem.image ?? '';
    final description = portfolioItem.description ?? 'No description available.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 320,
                        child: imagePath.isNotEmpty
                            ? (imagePath.startsWith('http')
                                ? Image.network(
                                    imagePath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                          color: Colors.green.shade50,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  )
                                : Image.asset(
                                    imagePath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                          color: Colors.green.shade50,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  ))
                            : Container(
                                color: Colors.green.shade50,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: '${_currentUserId ?? 'customer'}_${widget.tailor.id}',
          customerId: _currentUserId ?? 'current_customer_id',
          otherUserId: widget.tailor.id,
          otherUserName: widget.tailor.name,
          otherUserRole: UserRole.tailor,
          otherUserAvatar: widget.tailor.profilePicture,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    
    // Check if user is Tailor or Retailer
    final bool isTailorOrRetailer = widget.userRole == UserRole.tailor || 
                                     widget.userRole == UserRole.retailer;

    return Scaffold(
      bottomNavigationBar: (_isCustomer && !isUnavailable)
          ? _buildBookButton()
          : null,
      body: Column(
        children: [
          if (isUnavailable)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 10,
              ),
              color: Colors.red.shade800,
              child: const Text(
                "Sorry, currently unavailable",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          Expanded(
            child: CustomScrollView(
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
                        _buildPortfolioSection(isSmallScreen),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
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
                    widget.tailor.name,
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
                        rating: widget.tailor.rating,
                        size: ratingSize,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.tailor.rating}',
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
                                widget.tailor.address,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11.0 : 13.0,
                                  color: Colors.white70,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Only show delivery info for customers
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
                                      '1.8 km • Tk 40',
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
                          widget.tailor.phone,
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

    if (widget.tailor.profilePicture != null && 
        widget.tailor.profilePicture!.isNotEmpty) {
      imageUrl = widget.tailor.profilePicture!;
    }
    
    if (imageUrl == 'assets/images/fab.jpg' && _portfolioItems.isNotEmpty) {
      final firstItem = _portfolioItems.first;
      if (firstItem.image != null && firstItem.image!.isNotEmpty) {
        imageUrl = firstItem.image!;
      }
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.person, size: 80, color: Colors.grey),
        ),
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.person, size: 80, color: Colors.grey),
      ),
    );
  }

  Widget _buildBookButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (widget.onTailorSelected != null) {
              widget.onTailorSelected!(widget.tailor.id);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Booking feature coming soon!'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            "Book This Tailor",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(bool isSmallScreen) {
    String description = widget.tailor.about ?? 
        'Professional tailoring services with years of experience.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
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

  Widget _buildPortfolioSection(bool isSmallScreen) {
    if (_isLoadingPortfolio) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Color(0xFF6B8F71)),
        ),
      );
    }

    if (_portfolioItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = _showAllPortfolio
        ? _portfolioItems
        : (_portfolioItems.length > 4
              ? _portfolioItems.take(4).toList()
              : _portfolioItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Portfolio',
              style: TextStyle(
                fontSize: isSmallScreen ? 16.0 : 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_portfolioItems.length > 4)
              TextButton(
                onPressed: () =>
                    setState(() => _showAllPortfolio = !_showAllPortfolio),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8.0 : 16.0,
                    vertical: isSmallScreen ? 4.0 : 8.0,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showAllPortfolio ? 'Show Less' : 'See All',
                  style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: isSmallScreen ? 8.0 : 12.0,
            mainAxisSpacing: isSmallScreen ? 8.0 : 12.0,
            childAspectRatio: isSmallScreen ? 0.7 : 0.75,
          ),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final portfolio = displayItems[index];
            return GestureDetector(
              onTap: () => _showPortfolioOverlay(portfolio),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: portfolio.image != null &&
                              portfolio.image!.isNotEmpty
                              ? (portfolio.image!.startsWith('http')
                                  ? Image.network(
                                      portfolio.image!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image,
                                              size: 32,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    )
                                  : Image.asset(
                                      portfolio.image!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image,
                                              size: 32,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    ))
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image,
                                    size: 32,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (portfolio.description != null &&
                        portfolio.description!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                        child: Text(
                          portfolio.description!,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11.0 : 12.0,
                            color: Colors.grey[700],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showReviewsOverlay(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildReviewsPage(),
      ),
    );
  }

  // FIXED: Build reviews page with proper data from Firestore
  Widget _buildReviewsPage() {
    final filtered = _getFilteredReviews();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Customer Reviews",
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.tailor.name,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: () {
              _loadReviews();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReviewsPageSummary(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                "Feedback from Customers",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            _buildReviewsPageFilterChips(),
            const SizedBox(height: 16),
            if (_isLoadingReviews)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    color: Color(0xFF6B8F71),
                  ),
                ),
              )
            else if (_reviews.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
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
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.filter_alt_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No reviews match this filter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Try selecting a different filter',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
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
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    _buildReviewsPageItem(filtered[index]),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsPageSummary() {
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
                    (index) => Icon(
                      totalReviews > 0 && index < _averageRating.floor()
                          ? Icons.star
                          : (totalReviews > 0 && index < _averageRating.ceil()
                                ? Icons.star_half
                                : Icons.star_border),
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalReviews > 0 ? "Overall Rating" : "No ratings yet",
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Reviews: $totalReviews",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
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
          Text(
            "$star",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star, color: Colors.orange, size: 10),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.grey.shade100,
                color: Colors.orange,
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsPageFilterChips() {
    final filters = ["All reviews", "5 Star", "4 Star & above"];
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
                  setState(() => _selectedFilter = filter);
                }
              },
              selectedColor: const Color(0xFF2C5C44),
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
    switch (_selectedFilter) {
      case "5 Star":
        return _reviews.where((r) => r.rating >= 4.5).toList();
      case "4 Star & above":
        return _reviews.where((r) => r.rating >= 4.0).toList();
      default:
        return List.from(_reviews);
    }
  }

  int _getRatingCount(double rating) {
    return _reviews.where((r) => r.rating.round() == rating.round()).length;
  }

  Widget _buildReviewsPageItem(Review review) {
    // Try to get customer name from review or use fallback
    String customerName = 'Customer';
    if (review.customerId.isNotEmpty) {
      // You can fetch customer name from Firestore if needed
      // For now, use a hash-based fallback
      final hash = review.customerId.hashCode.abs();
      final names = ['Alex', 'Sam', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Avery'];
      customerName = names[hash % names.length];
    }
    
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                review.timeAgo,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (starIndex) => Icon(
                starIndex < review.rating.round()
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.orange,
                size: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            review.comment.isNotEmpty ? review.comment : 'No comment provided.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}