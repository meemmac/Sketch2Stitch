import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/messaging/chat_screen.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/messaging_service.dart';
import 'package:sketch2stitch/services/user_session.dart';

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
  double _averageRating = 0.0;
  String _selectedFilter = "All reviews";

  final List<String> _customerNames = [
    'Rahul Ahmed',
    'Sadia Rahman',
    'Kamal Hossain',
    'Tania Akhter',
    'Shahid Khan',
    'Nadia Islam',
    'Faisal Ahmed',
  ];

  bool get _isCustomer => widget.userRole == UserRole.customer;

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
        comment:
            'Excellent work! The suit fit perfectly and the quality was outstanding.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'R002',
        customerId: 'C002',
        targetId: widget.tailor.id,
        targetRole: ReviewTargetRole.tailor,
        orderId: 'O002',
        rating: 4.5,
        comment:
            'Very professional and timely delivery. Would recommend to friends.',
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
        final sum = _reviews.fold(
          0.0,
          (total, review) => total + review.rating,
        );
        _averageRating = sum / _reviews.length;
      }
    });
  }

  String _getCustomerName(int index) =>
      _customerNames[index % _customerNames.length];

  void _showPortfolioOverlay(dynamic portfolioItem) {
    final imagePath = portfolioItem.image ?? '';
    final description =
        portfolioItem.description ?? 'No description available.';

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
                            ? Image.asset(
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

  void _startConversation() async {
    final myId = UserSession.instance.uid;
    if (myId == null) return;
    
    final myRole = UserSession.instance.role ?? UserRole.customer;

    // Check for existing conversation
    final messagingService = MessagingService();
    final existing = await messagingService.getConversationBetween(myId, widget.tailor.id);
    
    final conversation = existing ?? await messagingService.createConversation(
      customerId: myId,
      otherId: widget.tailor.id,
      otherRole: UserRole.tailor,
      orderId: 'GEN-${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.id,
          customerId: myId,
          otherUserId: widget.tailor.id,
          otherUserName: widget.tailor.name,
          otherUserRole: UserRole.tailor,
          currentUserRole: myRole,
          otherUserAvatar: widget.tailor.profilePicture,
          orderId: conversation.orderId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final isMediumScreen = screenWidth >= 380 && screenWidth < 600;
    final bool isUnavailable = widget.tailor.maxOrder == 0;

    return Scaffold(
      bottomNavigationBar: (_isCustomer && widget.onTailorSelected != null)
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
                    Colors.black.withValues(alpha: 0.8),
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
                            if (_isCustomer) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.3),
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
                onPressed: () => setState(() => _isFavorite = !_isFavorite),
              ),
            ]
          : [],
    );
  }

  Widget _buildCoverImage() {
    String imageUrl = 'assets/images/fab.jpg';

    if (widget.tailor.portfolio != null &&
        widget.tailor.portfolio!.isNotEmpty) {
      imageUrl =
          widget.tailor.portfolio!.first.image ?? 'assets/images/fab.jpg';
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.tailor.maxOrder == 0 
              ? null 
              : () => widget.onTailorSelected!(widget.tailor.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.tailor.maxOrder == 0 ? Colors.grey : Colors.green.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(
            widget.tailor.maxOrder == 0 ? "Currently Unavailable" : "Book This Tailor",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(bool isSmallScreen) {
    String description =
        widget.tailor.about ??
        'Professional tailoring services with years of experience.';
    if (widget.tailor.portfolio != null &&
        widget.tailor.portfolio!.isNotEmpty) {
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

  Widget _buildPortfolioSection(bool isSmallScreen, bool isMediumScreen) {
    final portfolioItems = widget.tailor.portfolio ?? [];

    if (portfolioItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = _showAllPortfolio
        ? portfolioItems
        : (portfolioItems.length > 4
              ? portfolioItems.take(4).toList()
              : portfolioItems);

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
            if (portfolioItems.length > 4)
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
                      color: Colors.black.withValues(alpha: 0.03),
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
                          child:
                              portfolio.image != null &&
                                  portfolio.image!.isNotEmpty
                              ? Image.asset(
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
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
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
                      Text(
                        'Be the first to review this tailor!',
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
                    _buildReviewsPageItem(filtered[index], index),
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
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < _averageRating.floor()
                          ? Icons.star
                          : (index < _averageRating.ceil()
                                ? Icons.star_half
                                : Icons.star_border),
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Overall Rating",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
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
                  "Total Reviews: ${_reviews.length}",
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
                if (val) setState(() => _selectedFilter = filter);
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
        return _reviews.where((r) => r.rating >= 5.0).toList();
      case "4 Star & above":
        return _reviews.where((r) => r.rating >= 4.0).toList();
      default:
        return List.from(_reviews);
    }
  }

  int _getRatingCount(double rating) =>
      _reviews.where((r) => r.rating == rating).length;

  Widget _buildReviewsPageItem(Review review, int index) {
    final customerName = _getCustomerName(index);

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
                starIndex < review.rating.floor()
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.orange,
                size: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "\"${review.comment}\"",
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}