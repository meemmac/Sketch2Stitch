// lib/screens/customer/browsing/tailor_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';

class TailorDetailScreen extends StatefulWidget {
  final Tailor tailor;
  final void Function(String tailorId)? onTailorSelected;
  const TailorDetailScreen({
    super.key,
    required this.tailor,
    this.onTailorSelected,
  });

  @override
  State<TailorDetailScreen> createState() => _TailorDetailScreenState();
}

class _TailorDetailScreenState extends State<TailorDetailScreen> {
  bool _isFavorite = false;
  bool _showAllPortfolio = false;
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
        targetId: widget.tailor.id,
        targetRole: ReviewTargetRole.tailor,
        orderId: 'O001',
        rating: 5.0,
        comment: 'Excellent work! The suit fit perfectly and the quality was outstanding.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'R002',
        customerId: 'C002',
        targetId: widget.tailor.id,
        targetRole: ReviewTargetRole.tailor,
        orderId: 'O002',
        rating: 4.5,
        comment: 'Very professional and timely delivery. Would recommend to friends.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'R003',
        customerId: 'C003',
        targetId: widget.tailor.id,
        targetRole: ReviewTargetRole.tailor,
        orderId: 'O003',
        rating: 4.0,
        comment: 'Good quality work but delivery was a bit delayed.',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'R004',
        customerId: 'C004',
        targetId: widget.tailor.id,
        targetRole: ReviewTargetRole.tailor,
        orderId: 'O004',
        rating: 5.0,
        comment: 'Amazing attention to detail. Will definitely come back!',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Review(
        id: 'R005',
        customerId: 'C005',
        targetId: widget.tailor.id,
        targetRole: ReviewTargetRole.tailor,
        orderId: 'O005',
        rating: 4.5,
        comment: 'Great craftsmanship and very friendly service.',
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
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
                  _buildPortfolioSection(isSmallScreen, isMediumScreen),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isSmallScreen),
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
                      RatingStars(rating: widget.tailor.rating, size: ratingSize),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.tailor.rating}',
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
                        widget.tailor.phone,
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
    
    if (widget.tailor.portfolio != null && widget.tailor.portfolio!.isNotEmpty) {
      imageUrl = widget.tailor.portfolio!.first.image ?? 'assets/images/fab.jpg';
    }
    
    if (widget.tailor.profilePicture != null) {
      imageUrl = widget.tailor.profilePicture!;
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

  // ─── About Section ──────────────────────────────────────────────────────

  Widget _buildAboutSection(bool isSmallScreen) {
    String description = 'Professional tailoring services with years of experience.';
    if (widget.tailor.portfolio != null && widget.tailor.portfolio!.isNotEmpty) {
      final desc = widget.tailor.portfolio!.first.description;
      if (desc != null && desc.isNotEmpty) {
        description = desc;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
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

  // ─── Portfolio Section ─────────────────────────────────────────────────

  Widget _buildPortfolioSection(bool isSmallScreen, bool isMediumScreen) {
    final portfolioItems = widget.tailor.portfolio ?? [];
    
    if (portfolioItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = _showAllPortfolio 
        ? portfolioItems 
        : (portfolioItems.length > 4 ? portfolioItems.take(4).toList() : portfolioItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Portfolio',
              style: TextStyle(
                fontSize: isSmallScreen ? 18.0 : 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (portfolioItems.length > 4)
              TextButton(
                onPressed: () => setState(() => _showAllPortfolio = !_showAllPortfolio),
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
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13.0 : 15.0,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final portfolio = displayItems[index];
            return Container(
              margin: EdgeInsets.only(bottom: isSmallScreen ? 10.0 : 12.0),
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
                  // Image section
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox(
                      width: double.infinity,
                      height: isSmallScreen ? 140 : 160,
                      child: portfolio.image != null && portfolio.image!.isNotEmpty
                          ? Image.asset(
                              portfolio.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, size: 48, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, size: 48, color: Colors.grey),
                            ),
                    ),
                  ),
                  // Description section
                  if (portfolio.description != null && portfolio.description!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                      child: Text(
                        portfolio.description!,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13.0 : 14.0,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
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
                            'Be the first to review this tailor!',
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
    final Map<String, Map<String, String>> reviewDetails = {
      'R001': {'name': 'Rahul Ahmed', 'product': 'Three-Piece Suit'},
      'R002': {'name': 'Sadia Rahman', 'product': 'Wedding Lehenga'},
      'R003': {'name': 'Kamal Hossain', 'product': 'Business Blazer'},
      'R004': {'name': 'Tania Akhter', 'product': 'Evening Gown'},
      'R005': {'name': 'Shahid Khan', 'product': 'Kurta Set'},
    };

    final details = reviewDetails[review.id] ?? {'name': 'Anonymous', 'product': 'Product'};
    final customerName = details['name']!;
    final productName = details['product']!;
    final avatarSize = isSmallScreen ? 16.0 : 20.0;
    final nameSize = isSmallScreen ? 12.0 : 14.0;
    final commentSize = isSmallScreen ? 12.0 : 14.0;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
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
                    fontSize: isSmallScreen ? 12.0 : 14.0,
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
                    Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 4,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            productName,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10.0 : 12.0,
                              color: Colors.grey,
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
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.comment,
            style: TextStyle(
              fontSize: commentSize,
              color: Colors.grey,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            review.timeAgo,
            style: TextStyle(
              fontSize: isSmallScreen ? 10.0 : 12.0,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Bar ────────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isSmallScreen) {
    final padding = isSmallScreen ? 12.0 : 16.0;
    final verticalPadding = isSmallScreen ? 10.0 : 14.0;
    final fontSize = isSmallScreen ? 13.0 : 15.0;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _startConversation,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C5C44),
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10.0 : 14.0),
                side: const BorderSide(color: Color(0xFF2C5C44)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                isSmallScreen ? 'Chat' : 'Message',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _navigateToBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C5C44),
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10.0 : 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                isSmallScreen ? 'Book' : 'Book Now',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation Methods ──────────────────────────────────────────────

  void _startConversation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Start conversation with ${widget.tailor.name}'),
        backgroundColor: const Color(0xFF2C5C44),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToBooking() {
  if (widget.onTailorSelected != null) {
    Navigator.pop(context, widget.tailor.id);
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Book appointment with ${widget.tailor.name}'),
      backgroundColor: const Color(0xFF2C5C44),
      duration: const Duration(seconds: 2),
    ),
  );
}
}