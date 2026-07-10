import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';

/// Entry point kept for backward compatibility with existing navigation
/// calls (e.g. `Navigator.push(... BrowseRetailersScreen())`). It now
/// opens the shared [BrowseShell] on the Retailers tab.
class BrowseRetailersScreen extends StatelessWidget {
  const BrowseRetailersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BrowseShell(initialIndex: 2);
  }
}

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

  const RetailersPageBody({super.key, required this.searchQuery});

  @override
  State<RetailersPageBody> createState() => _RetailersPageBodyState();
}

class _RetailersPageBodyState extends State<RetailersPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedFilter = 'All';

  // Hardcoded data — no Firestore for now.
  final List<Retailer> _retailers = kHardcodedRetailers;
  final List<String> _filters = ['All', 'Top Rated', 'Premium', 'Fast Service'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        final filteredRetailers = _retailers.where((r) {
          final matchesFilter = _selectedFilter == 'All' ||
              (_selectedFilter == 'Top Rated' && r.rating >= 4.8) ||
              (_selectedFilter == 'Premium' && r.rating >= 4.7) ||
              (_selectedFilter == 'Fast Service' && r.rating >= 4.5);

          final matchesSearch = r.shopName.toLowerCase().contains(searchQuery.toLowerCase());

          return matchesFilter && matchesSearch;
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C5C44), Color(0xFF4E8B6F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trusted Fabric Retailers',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Shop from verified retailers with the best quality fabrics',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroChip(Icons.verified, 'Authentic Products'),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.price_check, 'Best Prices'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ─── Filter Chips ──────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildChip(
              filter,
              _selectedFilter == filter,
              () => setState(() => _selectedFilter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2C5C44) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF2C5C44) : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
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
      return const Center(
        child: Text('No retailers found', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: retailers.length,
      itemBuilder: (context, index) => _buildRetailerCard(retailers[index]),
    );
  }

  Widget _buildRetailerCard(Retailer retailer) {
    final bool showTopRated = retailer.rating >= 4.8;
    final bool isPremium = retailer.rating >= 4.7;
    final bool isFastService = retailer.rating >= 4.5;

    // Determine which badge to show (priority: Top Rated > Premium > Fast Service)
    String? badgeText;
    Color? badgeColor;
    if (showTopRated) {
      badgeText = 'Top Rated';
      badgeColor = Colors.orange;
    } else if (isPremium) {
      badgeText = 'Premium';
      badgeColor = Colors.purple;
    } else if (isFastService) {
      badgeText = 'Fast Service';
      badgeColor = Colors.blue;
    }

    return GestureDetector(
      onTap: () {
        // Navigate to retailer detail
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[200],
                      child: Image.asset(
                        'assets/images/fab.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.store, size: 50, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  if (badgeText != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          retailer.shopName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fabric Store',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            RatingStars(rating: retailer.rating, size: 12),
                            const SizedBox(width: 4),
                            Text('${retailer.rating}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                retailer.generalArea,
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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