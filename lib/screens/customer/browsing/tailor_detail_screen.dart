// lib/screens/customer/browsing/tailor_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';

class TailorDetailScreen extends StatefulWidget {
  final Tailor tailor;

  const TailorDetailScreen({
    super.key,
    required this.tailor,
  });

  @override
  State<TailorDetailScreen> createState() => _TailorDetailScreenState();
}

class _TailorDetailScreenState extends State<TailorDetailScreen> {
  bool _isFavorite = false;
  bool _showAllReviews = false;
  bool _showAllPortfolio = false;

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
                  // Cover Image (from database - portfolio)
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
                  // Tailor info on image
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tailor.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingStars(rating: widget.tailor.rating, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.tailor.rating}',
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
                                widget.tailor.address,
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
                              widget.tailor.phone,
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
                  // About Section (from database - portfolio description)
                  _buildAboutSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Portfolio (from database)
                  _buildPortfolioSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Reviews (from database)
                  _buildReviewsSection(),
                  
                  const SizedBox(height: 80), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Cover Image ──────────────────────────────────────────────────────

  Widget _buildCoverImage() {
    String imageUrl = 'assets/images/fab.jpg';
    if (widget.tailor.portfolio != null && widget.tailor.portfolio!.isNotEmpty) {
      imageUrl = widget.tailor.portfolio!.first.image ?? 'assets/images/fab.jpg';
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

  Widget _buildAboutSection() {
    // Get description from portfolio (database)
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
        const Text(
          'About',
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

  // ─── Portfolio Section ─────────────────────────────────────────────────

  Widget _buildPortfolioSection() {
    final portfolioImages = widget.tailor.portfolio ?? [];
    
    if (portfolioImages.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = _showAllPortfolio 
        ? portfolioImages 
        : (portfolioImages.length > 3 ? portfolioImages.take(3).toList() : portfolioImages);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Portfolio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (portfolioImages.length > 3)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllPortfolio = !_showAllPortfolio;
                  });
                },
                child: Text(_showAllPortfolio ? 'Show Less' : 'See All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _showAllPortfolio ? 260 : 120,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _showAllPortfolio ? 3 : 1,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            scrollDirection: _showAllPortfolio ? Axis.vertical : Axis.horizontal,
            itemCount: displayItems.length,
            physics: _showAllPortfolio ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  _navigateToPortfolioDetail(displayItems[index]);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      displayItems[index].image ?? 'assets/images/fab.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Reviews Section ───────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    // Sample reviews - in production, these would come from the Reviews collection
    // where targetId == tailor.id and targetRole == 'tailor'
    final List<Map<String, dynamic>> sampleReviews = [
      {
        'name': 'Rahul Ahmed',
        'rating': 5.0,
        'comment': 'Excellent work! The suit fit perfectly and the quality was outstanding.',
        'time': '2 days ago',
      },
      {
        'name': 'Sadia Rahman',
        'rating': 4.5,
        'comment': 'Very professional and timely delivery. Would recommend to friends.',
        'time': '1 week ago',
      },
      {
        'name': 'Kamal Hossain',
        'rating': 4.0,
        'comment': 'Good quality work but delivery was a bit delayed.',
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

  // ─── Bottom Bar ────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              onPressed: () {
                _startConversation();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C5C44),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF2C5C44)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Message',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _navigateToBooking();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C5C44),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Book Now',
                style: TextStyle(
                  fontSize: 15,
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

  void _navigateToPortfolioDetail(Portfolio portfolio) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View portfolio item details'),
        backgroundColor: const Color(0xFF2C5C44),
      ),
    );
  }

  void _startConversation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Start conversation with ${widget.tailor.name}'),
        backgroundColor: const Color(0xFF2C5C44),
      ),
    );
  }

  void _navigateToBooking() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Book appointment with ${widget.tailor.name}'),
        backgroundColor: const Color(0xFF2C5C44),
      ),
    );
  }
}