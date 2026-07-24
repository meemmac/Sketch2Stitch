import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/tailor_detail_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/browsing/filter_data.dart';

/// Hardcoded sample tailors with asset images.
final List<Tailor> kHardcodedTailors = [
  Tailor(
    id: 't1',
    name: 'Abdul Karim',
    email: 'karim.tailor@example.com',
    phone: '01811000001',
    address: '5 Banani Road, Banani, Dhaka',
    rating: 4.9,
    profilePicture: 'assets/images/fab.jpg',
    portfolio: [
      Portfolio(
        id: 'pf1',
        tailorId: 't1',
        image: 'assets/images/fab.jpg',
        description: 'Formal and informal wear specialist with 12 years experience.',
      ),
    ],
  ),
  Tailor(
    id: 't2',
    name: 'Rehana Begum',
    email: 'rehana.stitch@example.com',
    phone: '01811000002',
    address: '22 Gulshan Avenue, Gulshan, Dhaka',
    rating: 4.7,
    profilePicture: 'assets/images/silk.jpg',
    portfolio: [
      Portfolio(
        id: 'pf2',
        tailorId: 't2',
        image: 'assets/images/silk.jpg',
        description: 'Traditional and ethnic wear, saree blouses and lehengas.',
      ),
    ],
  ),
  Tailor(
    id: 't3',
    name: 'Mohammed Rafiq',
    email: 'rafiq.tailors@example.com',
    phone: '01811000003',
    address: ' Kotwali, Chittagong ',
    rating: 4.4,
    profilePicture: 'assets/images/textile.jpg',
    portfolio: [
      Portfolio(
        id: 'pf3',
        tailorId: 't3',
        image: 'assets/images/textile.jpg',
        description: 'Casual and daily wear, quick turnaround alterations.',
      ),
    ],
  ),
  Tailor(
    id: 't4',
    name: 'Fatima Noor',
    email: 'fatima.designs@example.com',
    phone: '01811000004',
    address: '3 Dhanmondi 27, Dhanmondi, Dhaka',
    rating: 4.8,
    profilePicture: 'assets/images/lace.jpg',
    portfolio: [
      Portfolio(
        id: 'pf4',
        tailorId: 't4',
        image: 'assets/images/lace.jpg',
        description: 'Bridal and formal wear, custom embroidery finishing.',
      ),
    ],
  ),
  Tailor(
    id: 't5',
    name: 'Kamal Hossain',
    email: 'kamal.tailor@example.com',
    phone: '01811000005',
    address: '15 Mirpur Road, Mirpur, Dhaka',
    rating: 4.6,
    profilePicture: 'assets/images/fab2.jpg',
    portfolio: [
      Portfolio(
        id: 'pf5',
        tailorId: 't5',
        image: 'assets/images/fab2.jpg',
        description: 'Quick stitching and alterations for all types of garments.',
      ),
    ],
  ),
];

/// The actual tailors tab content, rendered as one page inside the shared
/// [BrowseShell] PageView.
class TailorsPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final TailorsFilterData filterData;
  final void Function(String tailorId)? onTailorSelected;

  const TailorsPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
     this.onTailorSelected,
  });

  @override
  State<TailorsPageBody> createState() => _TailorsPageBodyState();
}

class _TailorsPageBodyState extends State<TailorsPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<Tailor> _tailors = kHardcodedTailors;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        final filteredTailors = _tailors.where((t) {
          final matchesSearch = t.name.toLowerCase().contains(searchQuery.toLowerCase());
          
          // Rating filter from shell
          final matchesRating = t.rating >= widget.filterData.minRating;
          
          // Location filter from shell
          final matchesLocation = widget.filterData.location == 'All' ||
              t.address.toLowerCase().contains(widget.filterData.location.toLowerCase());
          
          return matchesSearch && matchesRating && matchesLocation;
        }).toList();

        // Sort by rating based on filterData.sortBy
        if (widget.filterData.sortBy == 'ratingHighToLow') {
          filteredTailors.sort((a, b) => b.rating.compareTo(a.rating));
        } else if (widget.filterData.sortBy == 'ratingLowToHigh') {
          filteredTailors.sort((a, b) => a.rating.compareTo(b.rating));
        }

        return Column(
          children: [
            _buildHeroSection(),
            Expanded(child: _buildTailorsGrid(filteredTailors)),
          ],
        );
      },
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 8),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSageDark, kSage],
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
            'Skilled tailors for all your stitching needs',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildHeroChip(Icons.verified, 'Verified', isSmallScreen),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.star, 'Quality', isSmallScreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 12, vertical: isSmall ? 4 : 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
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

  // ─── Tailors Grid ──────────────────────────────────────────────────────

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
              'No tailors found',
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
      itemBuilder: (context, index) => _buildTailorCard(tailors[index], isSmallScreen),
    );
  }

  Widget _buildTailorCard(Tailor tailor, bool isSmall) {
    final bool isTopRated = tailor.rating >= 4.8;

    // Get specialty from portfolio description
    String specialty = 'Professional Tailoring';
    if (tailor.portfolio != null && tailor.portfolio!.isNotEmpty) {
      final desc = tailor.portfolio!.first.description ?? '';
      if (desc.isNotEmpty) {
        if (desc.length <= 30) {
          specialty = desc;
        } else {
          specialty = desc.substring(0, 30) + '...';
        }
      }
    }

    // Get image from profilePicture or use fallback
    String imageUrl = tailor.profilePicture ?? 'assets/images/fab.jpg';

    return GestureDetector(
     onTap: () async {
  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (context) => TailorDetailScreen(
        tailor: tailor,
        onTailorSelected: widget.onTailorSelected,
      ),
    ),
  );
  if (result != null && widget.onTailorSelected != null) {
    widget.onTailorSelected!(result);
  }
},
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image section with badges
            Flexible(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: kSage.withValues(alpha: 0.12),
                          child: Icon(Icons.person, size: isSmall ? 36 : 40, color: kSageDark),
                        ),
                      ),
                    ),
                  ),
                  // Top Rated Badge
                  if (isTopRated)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 8 : 10,
                          vertical: isSmall ? 4 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: kSage,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
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
                  // Rating Badge - Bottom Right
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 6 : 8,
                        vertical: isSmall ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
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
                  ),
                ],
              ),
            ),
            // Content section
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
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tailor.generalArea,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: isSmall ? 12 : 14,
                          color: kSage,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Tk ${tailor.deliveryCharge.toInt()}",
                          style: TextStyle(
                            fontSize: 11,
                            color: kSage,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}