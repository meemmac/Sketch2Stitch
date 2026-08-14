import 'package:flutter/material.dart';
import 'dart:async';
import '../../../services/review_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/review.dart';
import '../../../models/user_role.dart';
import '../../../models/tailor.dart';

class TailorReview {
  final String customerName;
  final double rating;
  final String dateLabel;
  final DateTime createdAt;
  final String comment;

  const TailorReview({
    required this.customerName,
    required this.rating,
    required this.dateLabel,
    required this.createdAt,
    required this.comment,
  });
}

class TailorReviewsScreen extends StatefulWidget {
  final String tailorName;
  const TailorReviewsScreen({super.key, this.tailorName = "Master Tailor Ahmed"});

  @override
  State<TailorReviewsScreen> createState() => _TailorReviewsScreenState();
}

class _TailorReviewsScreenState extends State<TailorReviewsScreen> {
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();
  StreamSubscription? _reviewsSubscription;
  StreamSubscription? _statsSubscription;

  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalRatings = 0;
  Map<int, int> _ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  String _currentTailorName = "Loading...";

  final Color primaryGreen = const Color(0xFF4F7942);
  String _selectedFilter = "All reviews";

  List<TailorReview> _allReviews = [];

  @override
  void initState() {
    super.initState();
    _currentTailorName = widget.tailorName;
    _loadData();
  }

  @override
  void dispose() {
    _reviewsSubscription?.cancel();
    _statsSubscription?.cancel();
    super.dispose();
  }

  void _loadData() async {
    final tailorId = _authService.currentUser?.uid;
    debugPrint("TailorReviewsScreen: Loading data for Tailor ID: $tailorId");
    if (tailorId == null) {
      debugPrint("TailorReviewsScreen: No logged in user found.");
      return;
    }

    // Fetch tailor profile for the name if it's default
    if (_currentTailorName == "Master Tailor Ahmed" || _currentTailorName == "Loading...") {
      final profile = await _authService.getUserProfile(tailorId, UserRole.tailor);
      if (profile != null && profile is Tailor && mounted) {
        setState(() {
          _currentTailorName = profile.name;
        });
      }
    }

    // Listen to stats
    _statsSubscription = _reviewService.streamTailorReviewStats(tailorId).listen((stats) {
      debugPrint("TailorReviewsScreen: Received stats: $stats");
      if (!mounted) return;
      setState(() {
        _averageRating = stats['average'] ?? 0.0;
        _totalRatings = stats['total'] ?? 0;
        _ratingDistribution = Map<int, int>.from(stats['distribution'] ?? {});
      });
    });

    // Listen to reviews
    _reviewsSubscription = _reviewService.streamDetailedTailorReviews(tailorId).listen((data) {
      debugPrint("TailorReviewsScreen: Received ${data.length} reviews from stream.");
      if (!mounted) return;
      setState(() {
        _allReviews = data.map((item) {
          final reviewMap = item['review'];
          final review = Review.fromJson(reviewMap);

          return TailorReview(
            customerName: item['userName'] ?? 'Anonymous',
            rating: review.rating,
            dateLabel: review.timeAgo,
            createdAt: review.createdAt,
            comment: review.comment,
          );
        }).toList();
        _isLoading = false;
      });
    });
  }

  List<TailorReview> get _filteredReviews {
    List<TailorReview> list = List.from(_allReviews);
    switch (_selectedFilter) {
      case "5 Star":
        return list.where((r) => r.rating >= 5.0).toList();
      case "4 Star & above":
        return list.where((r) => r.rating >= 4.0).toList();
      default:
        return list;
    }
  }

  /*
  final List<TailorReview> _dummyReviews = [
    TailorReview(
      customerName: "Maria Doe",
      rating: 4.8,
      dateLabel: "1 week ago",
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      comment: "The stitching is perfect and fits me exactly as I wanted. Highly recommended!",
    ),
    TailorReview(
      customerName: "Nishat Tasnim",
      rating: 5.0,
      dateLabel: "2 months ago",
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      comment: "Best tailor experience ever. The fit is top-notch.",
    ),
    TailorReview(
      customerName: "Israt Jahan",
      rating: 4.5,
      dateLabel: "3 months ago",
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      comment: "Good work, but took a bit longer to deliver.",
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Customer Reviews",
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _currentTailorName,
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
            _buildReviewSummary(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                "Feedback from Customers",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            _buildFilterChips(),
            const SizedBox(height: 16),
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

  Widget _buildReviewSummary() {
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
                  "Total Reviews: $_totalRatings",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
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
          Text("$star", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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

  Widget _buildFilterChips() {
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
              selectedColor: primaryGreen,
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

  Widget _buildReviewItem(TailorReview review) {
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
              Text(
                review.customerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                review.dateLabel,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          Text(
            "\"${review.comment}\"",
            style: const TextStyle(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}