// lib/screens/customer/browsing/browse_retailers_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/browsing/filter_data.dart';

/// Hardcoded sample retailers. Firestore has been removed for now — swap
/// this list back out for a service call whenever the backend is ready.
final List<Retailer> kHardcodedRetailers = [
  Retailer(
    id: 'r1',
    shopName: 'Dhaka Fabric House',
    email: 'contact@dhakafabric.com',
    phone: '01711000001',
    address: '12 New Market Road, Dhanmondi, Dhaka',
    rating: 4.8,
  ),
  Retailer(
    id: 'r2',
    shopName: 'Chowdhury Textiles',
    email: 'info@chowdhurytextiles.com',
    phone: '01711000002',
    address: '45 Islampur Road, Islampur, Dhaka',
    rating: 4.6,
  ),
  Retailer(
    id: 'r3',
    shopName: 'Silk & Lace Emporium',
    email: 'hello@silklace.com',
    phone: '01711000003',
    address: '7 Gausia Market, Elephant Road, Dhaka',
    rating: 4.9,
  ),
  Retailer(
    id: 'r4',
    shopName: 'Bengal Cotton Co.',
    email: 'sales@bengalcotton.com',
    phone: '01711000004',
    address: '89 Karwan Bazar, Tejgaon, Dhaka',
    rating: 4.3,
  ),
  Retailer(
    id: 'r5',
    shopName: 'Heritage Weaves',
    email: 'support@heritageweaves.com',
    phone: '01711000005',
    address: '3 Mirpur Road, Mohammadpur, Dhaka',
    rating: 4.7,
  ),
];

/// The actual retailers tab content, rendered as one page inside the
/// shared [BrowseShell] PageView. Header and navigation row live in the
/// shell; this widget only owns the hero, filter/category chips, and grid.
class RetailersPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final RetailersFilterData filterData; // Rating + Location

  const RetailersPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
  });

  @override
  State<RetailersPageBody> createState() => _RetailersPageBodyState();
}

class _RetailersPageBodyState extends State<RetailersPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedFilter = 'All';

  final List<Retailer> _retailers = kHardcodedRetailers;
  final List<String> _filters = ['All', 'Top Rated'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        final filteredRetailers = _retailers.where((r) {
          final matchesFilter = _selectedFilter == 'All' ||
              (_selectedFilter == 'Top Rated' && r.rating >= 4.5);
          final matchesSearch = r.shopName.toLowerCase().contains(searchQuery.toLowerCase());
          
          // Rating filter from shell
          final matchesRating = r.rating >= widget.filterData.minRating;
          
          // Location filter from shell
          final matchesLocation = widget.filterData.location == 'All' ||
              r.generalArea.toLowerCase().contains(widget.filterData.location.toLowerCase());
          
          return matchesFilter && matchesSearch && matchesRating && 
                 matchesLocation;
        }).toList();

        return Column(
          children: [
            _buildHeroSection(),
            _buildFilterChips(),
            Expanded(child: _buildRetailersGrid(filteredRetailers)),
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
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
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
            'Trusted Retailers',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Verified retailers with quality fabrics',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildHeroChip(Icons.verified, 'Authentic', isSmallScreen),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.price_check, 'Best Prices', isSmallScreen),
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
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter Chips ──────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _filters.map((filter) {
          return Padding(
            padding: EdgeInsets.only(right: isSmallScreen ? 4 : 6),
            child: _buildChip(
              filter,
              _selectedFilter == filter,
              () => setState(() => _selectedFilter = filter),
              isSmallScreen,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap, bool isSmall) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 14 : 16, 
          vertical: isSmall ? 6 : 7
        ),
        decoration: BoxDecoration(
          color: selected ? kSage : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kSage : kBorder,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 12 : 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ─── Retailers Grid ──────────────────────────────────────────────────────

  Widget _buildRetailersGrid(List<Retailer> retailers) {
    if (retailers.isEmpty) {
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
              'No retailers found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search terms',
              style: TextStyle(
                fontSize: 14,
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
      itemCount: retailers.length,
      itemBuilder: (context, index) => _buildRetailerCard(retailers[index], isSmallScreen),
    );
  }

  Widget _buildRetailerCard(Retailer retailer, bool isSmall) {
    final bool isTopRated = retailer.rating >= 4.8;

    // Use the first letter of shop name as fallback image
    final String initial = retailer.shopName.isNotEmpty ? retailer.shopName[0] : 'R';

    return GestureDetector(
      onTap: () {
        // Navigate to retailer detail
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
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: kSage.withValues(alpha: 0.12),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: isSmall ? 32 : 40,
                            fontWeight: FontWeight.bold,
                            color: kSageDark,
                          ),
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
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.3,
                          ),
                        ),
                        child: Text(
                          '⭐ Top Rated',
                          style: TextStyle(
                            fontSize: isSmall ? 9 : 11,
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
                            retailer.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmall ? 10 : 12,
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
                      retailer.shopName,
                      style: TextStyle(
                        fontSize: isSmall ? 14 : 16,
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
                            retailer.generalArea,
                            style: TextStyle(
                              fontSize: isSmall ? 11 : 12,
                              color: Colors.grey[600],
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
            ),
          ],
        ),
      ),
    );
  }
}