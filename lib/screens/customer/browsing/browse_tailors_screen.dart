import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';

/// Entry point kept for backward compatibility with existing navigation
/// calls (e.g. `Navigator.push(... BrowseTailorsScreen())`). It now opens
/// the shared [BrowseShell] on the Tailors tab.
class BrowseTailorsScreen extends StatelessWidget {
  const BrowseTailorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BrowseShell(initialIndex: 1);
  }
}

/// Hardcoded sample tailors with asset images.
final List<Tailor> kHardcodedTailors = [
  Tailor(
    id: 't1',
    name: 'Abdul Karim',
    email: 'karim.tailor@example.com',
    phone: '01811000001',
    address: '5 Banani Road, Banani, Dhaka',
    rating: 4.9,
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
    address: '10 Uttara Sector 7, Uttara, Dhaka',
    rating: 4.4,
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
/// [BrowseShell] PageView. Header and navigation row (including the
/// tab-switch transition) live in the shell now; this widget only owns
/// the hero, filter chips, and grid.
class TailorsPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;

  const TailorsPageBody({super.key, required this.searchQuery});

  @override
  State<TailorsPageBody> createState() => _TailorsPageBodyState();
}

class _TailorsPageBodyState extends State<TailorsPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedFilter = 'All';

  // Hardcoded data — no Firestore for now.
  final List<Tailor> _tailors = kHardcodedTailors;
  final List<String> _filters = ['All', 'Top Rated', 'Premium', 'Fast Service'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        final filteredTailors = _tailors.where((t) {
          final matchesFilter = _selectedFilter == 'All' ||
              (_selectedFilter == 'Top Rated' && t.rating >= 4.8) ||
              (_selectedFilter == 'Premium' && t.rating >= 4.7) ||
              (_selectedFilter == 'Fast Service' && t.rating >= 4.5);

          final matchesSearch = t.name.toLowerCase().contains(searchQuery.toLowerCase());

          return matchesFilter && matchesSearch;
        }).toList();

        return Column(
          children: [
            _buildHeroSection(),
            _buildFilterChips(),
            Expanded(child: _buildTailorsGrid(filteredTailors)),
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
            'Expert Tailors at Your Service',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Find skilled tailors for all your stitching needs',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroChip(Icons.verified, 'Verified Professionals'),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.star, 'Quality Guaranteed'),
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
            child: _buildFilterChip(
              filter,
              _selectedFilter == filter,
              () => setState(() => _selectedFilter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
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

  // ─── Tailors Grid ──────────────────────────────────────────────────────

  Widget _buildTailorsGrid(List<Tailor> tailors) {
    if (tailors.isEmpty) {
      return const Center(
        child: Text('No tailors found', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
      itemCount: tailors.length,
      itemBuilder: (context, index) => _buildTailorCard(tailors[index]),
    );
  }

  Widget _buildTailorCard(Tailor tailor) {
    final bool showTopRated = tailor.rating >= 4.8;
    final bool isPremium = tailor.rating >= 4.7;
    final bool isFastService = tailor.rating >= 4.5;

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

    String specialty = 'Professional Tailoring';
    if (tailor.portfolio != null && tailor.portfolio!.isNotEmpty) {
      final desc = tailor.portfolio!.first.description?.toLowerCase() ?? '';
      if (desc.contains('casual')) {
        specialty = 'Casual & Daily Wear';
      } else if (desc.contains('traditional') || desc.contains('ethnic')) {
        specialty = 'Traditional & Ethnic';
      } else if (desc.contains('formal') || desc.contains('informal')) {
        specialty = 'Formal & Informal Wear';
      } else if (desc.isNotEmpty) {
        specialty = desc;
      }
    }

    // Get image from portfolio or use fallback
    String imageUrl = 'assets/images/fab.jpg';
    if (tailor.portfolio != null && tailor.portfolio!.isNotEmpty) {
      imageUrl = tailor.portfolio!.first.image ?? 'assets/images/fab.jpg';
    }

    return GestureDetector(
      onTap: () {
        // Navigate to tailor detail
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
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.person, size: 50, color: Colors.grey),
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
                          tailor.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          specialty,
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
                            RatingStars(rating: tailor.rating, size: 12),
                            const SizedBox(width: 4),
                            Text('${tailor.rating}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                tailor.generalArea,
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