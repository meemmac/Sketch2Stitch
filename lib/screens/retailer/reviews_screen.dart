import 'package:flutter/material.dart';

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
  final int helpfulCount;
  final bool isHelpful;

  const UserReview({
    required this.userName,
    required this.rating,
    required this.dateLabel,
    required this.createdAt,
    required this.comment,
    required this.products,
    required this.helpfulCount,
    this.isHelpful = false,
  });

  UserReview copyWith({
    int? helpfulCount,
    bool? isHelpful,
  }) {
    return UserReview(
      userName: userName,
      rating: rating,
      dateLabel: dateLabel,
      createdAt: createdAt,
      comment: comment,
      products: products,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isHelpful: isHelpful ?? this.isHelpful,
    );
  }
}

class RetailerReviewsScreen extends StatefulWidget {
  final String shopName;
  const RetailerReviewsScreen({super.key, this.shopName = "Bismillah Kacchi House"});

  @override
  State<RetailerReviewsScreen> createState() => _RetailerReviewsScreenState();
}

class _RetailerReviewsScreenState extends State<RetailerReviewsScreen> {
  final Color primaryGreen = const Color(0xFF4F7942);
  String _selectedFilter = "Top reviews";

  final List<UserReview> _reviews = [
    UserReview(
      userName: "Tasphia",
      rating: 4.0,
      dateLabel: "2 months ago",
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      comment: "Denim quality was good but a little too expensive.",
      helpfulCount: 3,
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
      helpfulCount: 0,
      products: const [],
    ),
    UserReview(
      userName: "Israt",
      rating: 4.5,
      dateLabel: "2 days ago",
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      comment: "Excellent quality and fast delivery. Very satisfied!",
      helpfulCount: 5,
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
      helpfulCount: 1,
      products: const [
        ReviewProduct(name: "Printed Scarf", image: "assets/images/gorgeous.jpg", price: 3000),
      ],
    ),
  ];

  List<UserReview> get _filteredReviews {
    List<UserReview> sortedList = List.from(_reviews);
    switch (_selectedFilter) {
      case "Top reviews":
        // Sort by high rating first, then by helpful count
        sortedList.sort((a, b) {
          int ratingComp = b.rating.compareTo(a.rating);
          if (ratingComp != 0) return ratingComp;
          return b.helpfulCount.compareTo(a.helpfulCount);
        });
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
      body: SingleChildScrollView(
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
                const Text(
                  "4.2",
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < 4 ? Icons.star : Icons.star_half,
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "100+ All ratings",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _ratingBar(5, 0.8),
                _ratingBar(4, 0.4),
                _ratingBar(3, 0.2),
                _ratingBar(2, 0.1),
                _ratingBar(1, 0.3),
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
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setState(() {
                final index = _reviews.indexWhere((r) => r.userName == review.userName && r.createdAt == review.createdAt);
                if (index != -1) {
                  final current = _reviews[index];
                  if (current.isHelpful) {
                    _reviews[index] = current.copyWith(
                      helpfulCount: current.helpfulCount - 1,
                      isHelpful: false,
                    );
                  } else {
                    _reviews[index] = current.copyWith(
                      helpfulCount: current.helpfulCount + 1,
                      isHelpful: true,
                    );
                  }
                }
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  review.isHelpful ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                  size: 16,
                  color: review.isHelpful ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  review.helpfulCount > 0 ? "Helpful ${review.helpfulCount}" : "Helpful",
                  style: TextStyle(
                    color: review.isHelpful ? Colors.orange : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
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
            child: Image.asset(
              product.image,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
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
}
