import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sketch2stitch/services/review_service.dart';
import 'package:sketch2stitch/models/review.dart' as db;

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

enum ReviewRecipient { retailer, tailor }

class CustomerReview {
  final String recipientName;
  final ReviewRecipient recipientType;
  final double rating;
  final String dateLabel;
  final DateTime createdAt;
  final String comment;
  final List<ReviewProduct> products;
  final int helpfulCount;
  final bool isHelpful;

  const CustomerReview({
    required this.recipientName,
    required this.recipientType,
    required this.rating,
    required this.dateLabel,
    required this.createdAt,
    required this.comment,
    this.products = const [],
    required this.helpfulCount,
    this.isHelpful = false,
  });

  CustomerReview copyWith({
    int? helpfulCount,
    bool? isHelpful,
  }) {
    return CustomerReview(
      recipientName: recipientName,
      recipientType: recipientType,
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

class CustomerReviewsScreen extends StatefulWidget {
  final String customerName;
  const CustomerReviewsScreen({super.key, this.customerName = "Maria Doe"});

  @override
  State<CustomerReviewsScreen> createState() => _CustomerReviewsScreenState();
}

class _CustomerReviewsScreenState extends State<CustomerReviewsScreen> {
  final Color primaryGreen = const Color(0xFF4F7942);
  String _selectedFilter = "All reviews";
  Stream<List<Map<String, dynamic>>>? _reviewStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _reviewStream = ReviewService().streamDetailedCustomerReviews(uid);
    }
  }

  /// Data Translation: Map backend structures to visual components.
  List<CustomerReview> _mapFromBackend(List<Map<String, dynamic>> backendReviews) {
    return backendReviews.map((item) {
      final db.Review review = item['review'];
      final String recipientName = item['recipientName'];
      final List<Map<String, dynamic>> productsData = item['products'] ?? [];

      return CustomerReview(
        recipientName: recipientName,
        recipientType: review.targetRole == db.ReviewTargetRole.tailor 
            ? ReviewRecipient.tailor 
            : ReviewRecipient.retailer,
        rating: review.rating,
        dateLabel: _timeAgo(review.createdAt),
        createdAt: review.createdAt,
        comment: review.comment,
        helpfulCount: 0,
        products: productsData.map((p) => ReviewProduct(
          name: p['name'],
          image: p['image'],
          price: p['price'],
        )).toList(),
      );
    }).toList();
  }

  String _timeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 30) return "${(diff.inDays / 30).floor()} months ago";
    if (diff.inDays > 7) return "${(diff.inDays / 7).floor()} weeks ago";
    if (diff.inDays > 0) return "${diff.inDays} days ago";
    if (diff.inHours > 0) return "${diff.inHours} hours ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes} minutes ago";
    return "just now";
  }

  List<CustomerReview> _applyFilter(List<CustomerReview> reviews) {
    switch (_selectedFilter) {
      case "Retailer":
        return reviews.where((r) => r.recipientType == ReviewRecipient.retailer).toList();
      case "Tailor":
        return reviews.where((r) => r.recipientType == ReviewRecipient.tailor).toList();
      default:
        return reviews;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || _reviewStream == null) {
      return const Scaffold(body: Center(child: Text("Please sign in to view history.")));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _reviewStream,
      builder: (context, snapshot) {
        debugPrint("ReviewsScreen: StreamBuilder update. State: ${snapshot.connectionState}");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final reviews = _mapFromBackend(snapshot.data ?? []);
        final filtered = _applyFilter(reviews);

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
                  "My Reviews",
                  style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Logged in as ${widget.customerName}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: ReviewService().getReviewSummaryStats(uid),
                  builder: (context, statsSnap) {
                    return _buildReviewSummary(statsSnap.data, reviews.length);
                  }
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    "My Past Reviews",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildFilterChips(),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                   const Padding(
                     padding: EdgeInsets.all(32.0),
                     child: Center(child: Text("No reviews match the current filter.", style: TextStyle(color: Colors.grey))),
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
    );
  }

  Widget _buildReviewSummary(Map<String, dynamic>? stats, int totalCount) {
    final avg = stats?['averageRating'] ?? 0.0;
    final retailerCount = stats?['retailerReviews'] ?? 0;
    final tailorCount = stats?['tailorReviews'] ?? 0;

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
                  avg.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star,
                      color: index < avg.floor() ? Colors.orange : Colors.grey.shade300,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Average Rating Given",
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
                  "Total Reviews: $totalCount",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Retailers: $retailerCount",
                  style: const TextStyle(color: Colors.black54),
                ),
                Text(
                  "Tailors: $tailorCount",
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ["All reviews", "Retailer", "Tailor"];
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

  Widget _buildReviewItem(CustomerReview review) {
    final themeColor = review.recipientType == ReviewRecipient.tailor ? Colors.orange : Colors.blue;
    final isTailor = review.recipientType == ReviewRecipient.tailor;

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
                review.recipientName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTailor ? "Tailor" : "Retailer",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ],
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
            "\"${review.comment}\"",
            style: const TextStyle(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
          ),
          if (!isTailor && review.products.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Related Items",
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
            child: Image.asset(
              product.image,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.shopping_bag, size: 20),
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
