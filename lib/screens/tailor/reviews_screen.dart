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

class TailorReview {
  final String customerName;
  final double rating;
  final String dateLabel;
  final DateTime createdAt;
  final String comment;
  final List<ReviewProduct> products;
  final int helpfulCount;
  final bool isHelpful;

  const TailorReview({
    required this.customerName,
    required this.rating,
    required this.dateLabel,
    required this.createdAt,
    required this.comment,
    required this.products,
    required this.helpfulCount,
    this.isHelpful = false,
  });

  TailorReview copyWith({
    int? helpfulCount,
    bool? isHelpful,
  }) {
    return TailorReview(
      customerName: customerName,
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

class TailorReviewsScreen extends StatefulWidget {
  final String tailorName;
  const TailorReviewsScreen({super.key, this.tailorName = "Master Tailor Ahmed"});

  @override
  State<TailorReviewsScreen> createState() => _TailorReviewsScreenState();
}

class _TailorReviewsScreenState extends State<TailorReviewsScreen> {
  final Color primaryGreen = const Color(0xFF4F7942);
  String _selectedFilter = "All reviews";

  final List<TailorReview> _reviews = [
    TailorReview(
      customerName: "Maria Doe",
      rating: 4.8,
      dateLabel: "1 week ago",
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      comment: "The stitching is perfect and fits me exactly as I wanted. Highly recommended!",
      helpfulCount: 2,
      products: const [
        ReviewProduct(name: "Stitching Service - Kurti", image: "assets/images/ref2.jpg", price: 1500),
      ],
    ),
    TailorReview(
      customerName: "Nishat Tasnim",
      rating: 5.0,
      dateLabel: "2 months ago",
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      comment: "Best tailor experience ever. The fit is top-notch.",
      helpfulCount: 3,
      products: const [
        ReviewProduct(name: "Stitching Service - Lehenga", image: "assets/images/ref1.jpg", price: 4000),
      ],
    ),
    TailorReview(
      customerName: "Israt Jahan",
      rating: 4.5,
      dateLabel: "3 months ago",
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      comment: "Good work, but took a bit longer to deliver.",
      helpfulCount: 1,
      products: const [
        ReviewProduct(name: "Stitching Service - Saree Blouse", image: "assets/images/ref3.jpg", price: 2000),
      ],
    ),
  ];

  List<TailorReview> get _filteredReviews {
    List<TailorReview> list = List.from(_reviews);
    switch (_selectedFilter) {
      case "5 Star":
        return list.where((r) => r.rating >= 5.0).toList();
      case "4 Star & above":
        return list.where((r) => r.rating >= 4.0).toList();
      default:
        return list;
    }
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
              "Customer Reviews",
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.tailorName,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
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
                const Text(
                  "4.7",
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
                _ratingBar(5, 0.8),
                _ratingBar(4, 0.6),
                _ratingBar(3, 0.1),
                _ratingBar(2, 0.0),
                _ratingBar(1, 0.0),
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
          if (review.products.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Reviewed Work",
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
              errorBuilder: (_,__,___) => Container(
                width: 50, height: 50, color: Colors.grey[200],
                child: const Icon(Icons.content_cut, size: 20),
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
                  "Service Tk ${product.price.toInt()}",
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
