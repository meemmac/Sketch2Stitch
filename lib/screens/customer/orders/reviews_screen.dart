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
    required this.products,
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

  final List<CustomerReview> _reviews = [
    CustomerReview(
      recipientName: "FabriCo",
      recipientType: ReviewRecipient.retailer,
      rating: 5.0,
      dateLabel: "1 week ago",
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      comment: "Excellent quality and fast delivery. Very satisfied!",
      helpfulCount: 5,
      products: const [
        ReviewProduct(name: "Printed Voile", image: "assets/images/gorgeous.jpg", price: 3200),
      ],
    ),
    CustomerReview(
      recipientName: "Master Tailor Ahmed",
      recipientType: ReviewRecipient.tailor,
      rating: 4.8,
      dateLabel: "1 week ago",
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      comment: "The stitching is perfect and fits me exactly as I wanted. Highly recommended!",
      helpfulCount: 2,
      products: const [
        ReviewProduct(name: "Stitching Service - Kurti", image: "assets/images/ref2.jpg", price: 1500),
      ],
    ),
    CustomerReview(
      recipientName: "Bismillah Fabrics",
      recipientType: ReviewRecipient.retailer,
      rating: 4.0,
      dateLabel: "3 weeks ago",
      createdAt: DateTime.now().subtract(const Duration(days: 21)),
      comment: "Good quality fabric, but shipping took a bit longer than expected.",
      helpfulCount: 1,
      products: const [
        ReviewProduct(name: "Soft Georgette", image: "assets/images/fabrics_rolled.jpg", price: 2800),
      ],
    ),
    CustomerReview(
      recipientName: "Style Hub",
      recipientType: ReviewRecipient.retailer,
      rating: 5.0,
      dateLabel: "2 months ago",
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      comment: "The silk is absolutely stunning. Worth every penny!",
      helpfulCount: 8,
      products: const [
        ReviewProduct(name: "Banarasi Silk", image: "assets/images/silk.jpg", price: 6500),
      ],
    ),
    CustomerReview(
      recipientName: "Elegant Stitching",
      recipientType: ReviewRecipient.tailor,
      rating: 5.0,
      dateLabel: "2 months ago",
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      comment: "Best tailor experience ever. The fit is top-notch.",
      helpfulCount: 3,
      products: const [
        ReviewProduct(name: "Stitching Service - Lehenga", image: "assets/images/ref1.jpg", price: 4000),
      ],
    ),
  ];

  List<CustomerReview> get _filteredReviews {
    List<CustomerReview> list = List.from(_reviews);
    switch (_selectedFilter) {
      case "Retailer":
        return list.where((r) => r.recipientType == ReviewRecipient.retailer).toList();
      case "Tailor":
        return list.where((r) => r.recipientType == ReviewRecipient.tailor).toList();
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
            _buildReviewSummary(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                "My Past Reviews",
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
                  "4.8",
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => const Icon(
                      Icons.star,
                      color: Colors.orange,
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
                  "Total Reviews: ${_reviews.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Retailers: ${_reviews.where((r) => r.recipientType == ReviewRecipient.retailer).length}",
                  style: const TextStyle(color: Colors.black54),
                ),
                Text(
                  "Tailors: ${_reviews.where((r) => r.recipientType == ReviewRecipient.tailor).length}",
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
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  review.recipientType == ReviewRecipient.tailor ? "Tailor" : "Retailer",
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
          if (review.products.isNotEmpty) ...[
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
              errorBuilder: (_,__,___) => Container(
                width: 50, height: 50, color: Colors.grey[200],
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
