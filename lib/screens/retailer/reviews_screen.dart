import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/review_service.dart';
import '../../services/auth_service.dart';
import '../../models/review.dart';

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

class UserReview {
  final String userName;
  final double rating;
  final String dateLabel;
  final DateTime createdAt;
  final String comment;
  final List<ReviewProduct> products;

  const UserReview({
    required this.userName,
    required this.rating,
    required this.dateLabel,
    required this.createdAt,
    required this.comment,
    required this.products,
  });
}

class RetailerReviewsScreen extends StatefulWidget {
  final String shopName;
const RetailerReviewsScreen({super.key, required this.shopName});

  @override
  State<RetailerReviewsScreen> createState() => _RetailerReviewsScreenState();
}

class _RetailerReviewsScreenState extends State<RetailerReviewsScreen> {
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();
  StreamSubscription? _reviewsSubscription;
  StreamSubscription? _statsSubscription;

  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalRatings = 0;
  Map<int, int> _ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

  final Color primaryGreen = const Color(0xFF4F7942);
  String _selectedFilter = "Top reviews";

  List<UserReview> _allReviews = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _reviewsSubscription?.cancel();
    _statsSubscription?.cancel();
    super.dispose();
  }

  void _loadData() {
    final retailerId = _authService.currentUser?.uid;
    if (retailerId == null) {
       setState(() => _isLoading = false);
      return;
    }

    // Listen to stats
    _statsSubscription = _reviewService.streamShopReviewStats(retailerId).listen((stats) {
      if (!mounted) return;
      setState(() {
        _averageRating = stats['average'] ?? 0.0;
        _totalRatings = stats['total'] ?? 0;
        _ratingDistribution = Map<int, int>.from(stats['distribution'] ?? {});
      });
    });

    // Listen to reviews
    _reviewsSubscription = _reviewService.streamDetailedShopReviews(retailerId).listen((data) {
      if (!mounted) return;
      setState(() {
        _allReviews = data.map((item) {
          final reviewMap = item['review'];
          final review = Review.fromJson(reviewMap);
          final productsList = item['products'] as List<dynamic>;

          return UserReview(
            userName: item['userName'] ?? 'Anonymous',
            rating: review.rating,
            dateLabel: review.timeAgo,
            createdAt: review.createdAt,
            comment: review.comment,
            products: productsList.map((p) => ReviewProduct(
              name: p['name'],
              image: p['image'],
              price: p['price'],
            )).toList(),
          );
        }).toList();
        _isLoading = false;
      });
       }, onError: (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  List<UserReview> get _filteredReviews {
    List<UserReview> sortedList = List.from(_allReviews);
    switch (_selectedFilter) {
      case "Top reviews":
        // Sort by high rating first
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

/*
  final List<UserReview> _dummyReviews = [
    UserReview(
      userName: "Tasphia",
      rating: 4.0,
      dateLabel: "2 months ago",
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      comment: "Denim quality was good but a little too expensive.",
      products: const [
        ReviewProduct(name: "Premium Egyptian Cotton", image: "assets/images/fabrics_rolled.jpg", price: 3250),
        ReviewProduct(name: "Denim Patchwork", image: "assets/images/denim.jpg", price: 1950),
      ],
    ),
    UserReview(
      userName: "Nishat",
      rating: 5.0,
      dateLabel: "Today",
      createdAt: DateTime.now(),
      comment: "great",
      products: const [],
    ),
    UserReview(
      userName: "Israt",
      rating: 4.5,
      dateLabel: "2 days ago",
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      comment: "Excellent quality and fast delivery. Very satisfied!",
      products: const [
        ReviewProduct(name: "Golden Silk Blend", image: "assets/images/silk.jpg", price: 5400),
      ],
    ),
    UserReview(
      userName: "Riya",
      rating: 2.0,
      dateLabel: "1 week ago",
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      comment: "The color was slightly different than the photo.",
      products: const [
        ReviewProduct(name: "Printed Scarf", image: "assets/images/gorgeous.jpg", price: 3000),
      ],
    ),
  ];
*/

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReviews;

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
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.shopName,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
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
                _buildFilterChips(),
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
                    itemBuilder: (context, index) => _buildReviewItem(filtered[index]),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
    );
  }

  Widget _buildRatingSummary() {
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
                  "$_totalRatings All ratings",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _ratingBar(5, _totalRatings == 0 ? 0 : (_ratingDistribution[5] ?? 0) / _totalRatings),
                _ratingBar(4, _totalRatings == 0 ? 0 : (_ratingDistribution[4] ?? 0) / _totalRatings),
                _ratingBar(3, _totalRatings == 0 ? 0 : (_ratingDistribution[3] ?? 0) / _totalRatings),
                _ratingBar(2, _totalRatings == 0 ? 0 : (_ratingDistribution[2] ?? 0) / _totalRatings),
                _ratingBar(1, _totalRatings == 0 ? 0 : (_ratingDistribution[1] ?? 0) / _totalRatings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(int star, double percent) {
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

  Widget _buildFilterChips() {
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
                  setState(() => _selectedFilter = filter);
                }
              },
              selectedColor: const Color(0xFF6B8F71),
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

  Widget _buildReviewItem(UserReview review) {
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
            review.userName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                "• ${review.dateLabel}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (review.products.isNotEmpty) ...[
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
                itemCount: review.products.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _buildProductMiniCard(review.products[index]),
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
}