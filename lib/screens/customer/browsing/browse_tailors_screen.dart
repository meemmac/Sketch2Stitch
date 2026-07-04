import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_fabrics_screen.dart';

class BrowseTailorsScreen extends StatefulWidget {
  const BrowseTailorsScreen({super.key});

  @override
  State<BrowseTailorsScreen> createState() => _BrowseTailorsScreenState();
}

class _BrowseTailorsScreenState extends State<BrowseTailorsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<Tailor> _tailors = [];
  final List<String> _filters = ['All', 'Top Rated', 'Premium', 'Fast Service'];

  // ─── Nav "scroll to switch page" state ──────────────────────────────────
  // _navDragOffset ranges from 0 (rest, "Browse Tailors" active) to
  // -_navDragMax (fully dragged left, "Browse Clothing" active -> navigates).
  late AnimationController _navAnimController;
  double _navDragOffset = 0;
  static const double _navDragMax = 140;

  double get _clothingProgress => (-_navDragOffset / _navDragMax).clamp(0.0, 1.0);
  double get _tailorsProgress => 1 - _clothingProgress;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _loadHardcodedData();
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  void _onNavDragUpdate(DragUpdateDetails details) {
    setState(() {
      _navDragOffset = (_navDragOffset + details.delta.dx).clamp(-_navDragMax, 0.0);
    });
  }

  void _snapNav(double target, {VoidCallback? onComplete}) {
    final tween = Tween<double>(begin: _navDragOffset, end: target);
    _navAnimController.reset();
    final curved = CurvedAnimation(parent: _navAnimController, curve: Curves.easeOut);
    late final Animation<double> anim;
    anim = tween.animate(curved)
      ..addListener(() {
        setState(() => _navDragOffset = anim.value);
      });
    _navAnimController.forward().whenComplete(() => onComplete?.call());
  }

  void _onNavDragEnd(DragEndDetails details) {
    // Crossed far enough left -> finish the slide and navigate to Fabrics.
    if (_clothingProgress >= 0.65) {
      _snapNav(-_navDragMax, onComplete: () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 280),
            pageBuilder: (context, animation, secondaryAnimation) =>
                const BrowseFabricsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              );
            },
          ),
        );
      });
    } else {
      // Didn't cross the threshold -> snap back to "Browse Tailors" active.
      _snapNav(0);
    }
  }

  void _loadHardcodedData() {
    final sampleReviews = [
      Review(
        id: 'r1',
        customerId: 'c1',
        targetId: 't1',
        targetRole: ReviewTargetRole.tailor,
        rating: 4.5,
        comment: 'Excellent work!',
        createdAt: DateTime.now(),
      ),
      Review(
        id: 'r2',
        customerId: 'c2',
        targetId: 't2',
        targetRole: ReviewTargetRole.tailor,
        rating: 3.5,
        comment: 'Good service',
        createdAt: DateTime.now(),
      ),
      Review(
        id: 'r3',
        customerId: 'c3',
        targetId: 't3',
        targetRole: ReviewTargetRole.tailor,
        rating: 4.0,
        comment: 'Very professional',
        createdAt: DateTime.now(),
      ),
    ];

    final samplePortfolios = [
      Portfolio(
        id: 'pf1',
        tailorId: 't1',
        image: 'https://picsum.photos/seed/portfolio1/400/500',
        description: 'Wedding dress',
      ),
    ];

    _tailors.addAll([
      Tailor(
        id: 't1',
        name: 'Master Stitch Tailors',
        email: 'master@tailor.com',
        phone: '+8801712345679',
        address: 'Farragate, Dhaka',
        licenses: ['License #12345'],
        rating: 4.5,
        reviewCount: 234,
        profileImage: 'https://picsum.photos/seed/masterstitch/200/200',
        description: 'Expert tailoring with 15 years experience. Specializing in wedding and formal wear.',
        portfolio: samplePortfolios,
        reviews: sampleReviews.where((r) => r.targetId == 't1').toList(),
      ),
      Tailor(
        id: 't2',
        name: 'Quick Stitch Express',
        email: 'quick@tailor.com',
        phone: '+8801712345680',
        address: 'Chateaugues, Dhaka',
        licenses: [],
        rating: 3.5,
        reviewCount: 134,
        profileImage: 'https://picsum.photos/seed/quickstitch/200/200',
        description: 'Fast and reliable tailoring with 10 years experience. Specializing in casual and daily wear.',
        portfolio: [],
        reviews: sampleReviews.where((r) => r.targetId == 't2').toList(),
      ),
      Tailor(
        id: 't3',
        name: 'Royal Stitch Express',
        email: 'royal@tailor.com',
        phone: '+8801712345684',
        address: 'Magars, Dhaka',
        licenses: ['License #22222'],
        rating: 4.0,
        reviewCount: 334,
        profileImage: 'https://picsum.photos/seed/royalstitch/200/200',
        description: 'Premium tailoring with 5 years experience. Specializing in traditional and ethnic wear.',
        portfolio: [],
        reviews: sampleReviews.where((r) => r.targetId == 't3').toList(),
      ),
      Tailor(
        id: 't4',
        name: 'Stitch Tailors',
        email: 'stitch@tailor.com',
        phone: '+8801712345685',
        address: 'Farragate, Dhaka',
        licenses: [],
        rating: 4.5,
        reviewCount: 234,
        profileImage: 'https://picsum.photos/seed/stitchtailors/200/200',
        description: 'Professional tailoring with 15 years experience. Specializing in wedding and formal wear.',
        portfolio: [],
        reviews: [],
      ),
      Tailor(
        id: 't5',
        name: 'Modern Fit Tailors',
        email: 'modern@tailor.com',
        phone: '+8801712345686',
        address: 'Farragate, Dhaka',
        licenses: ['License #33333'],
        rating: 4.5,
        reviewCount: 234,
        profileImage: 'https://picsum.photos/seed/modernfit/200/200',
        description: 'Modern tailoring with 15 years experience. Specializing in formal and informal wear.',
        portfolio: [],
        reviews: [],
      ),
      Tailor(
        id: 't6',
        name: 'Master Stitch Tailors',
        email: 'master2@tailor.com',
        phone: '+8801712345687',
        address: 'Farragate, Dhaka',
        licenses: ['License #44444'],
        rating: 4.5,
        reviewCount: 234,
        profileImage: 'https://picsum.photos/seed/masterstitch2/200/200',
        description: 'Expert tailoring with 15 years experience. Specializing in wedding and formal wear.',
        portfolio: [],
        reviews: [],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTailors = _tailors.where((t) {
      final matchesFilter = _selectedFilter == 'All' ||
          (_selectedFilter == 'Top Rated' && t.rating >= 4.5) ||
          (_selectedFilter == 'Premium' && t.hasLicense) ||
          (_selectedFilter == 'Fast Service' && t.reviewCount > 200);

      final matchesSearch = t.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (t.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      return matchesFilter && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          _buildHeroSection(),
          _buildNavigationRow(),
          _buildFilterChips(),
          Expanded(
            child: _buildTailorsList(filteredTailors),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          // Dashboard/Menu Icon
          IconButton(
            onPressed: () {
              // Open drawer later
            },
            icon: const Icon(
              Icons.menu,
              color: Color(0xFF224F34),
            ),
          ),
          const SizedBox(width: 8),
          // Logo
          Image.asset(
            'assets/images/transparent_logo.png',
            height: 45,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 45,
                width: 45,
                decoration: const BoxDecoration(
                  color: Color(0xFF224F34),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'S2S',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),

          // Search Bar
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Search tailors...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Cart
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: Color(0xFF224F34),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }


  // ─── Navigation Row ──────────────────────────────────────────────────────

  Widget _buildNavigationRow() {
    final clothingProgress = _clothingProgress;
    final tailorsProgress = _tailorsProgress;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onNavDragUpdate,
      onHorizontalDragEnd: _onNavDragEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Transform.translate(
            offset: Offset(_navDragOffset * 0.35, 0),
            child: Row(
              children: [
                Text(
                  'Browse Clothing and Elements',
                  style: TextStyle(
                    fontSize: _lerp(14, 19, clothingProgress),
                    fontWeight: clothingProgress > 0.5
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: Color.lerp(
                      const Color(0xFF224F34).withValues(alpha: 0.55),
                      const Color(0xFF224F34),
                      clothingProgress,
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                Text(
                  'Browse Tailors',
                  style: TextStyle(
                    fontSize: _lerp(13, 19, tailorsProgress),
                    fontWeight: tailorsProgress > 0.5
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: Color.lerp(
                      const Color(0xFF224F34).withValues(alpha: 0.55),
                      const Color(0xFF224F34),
                      tailorsProgress,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Browse Retailers',
                    style: TextStyle(
                      color: Color(0xFF224F34),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF64CD57), Color(0xFF224F34)],
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Find skilled tailors for all your stitching needs',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
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
              () {
                setState(() => _selectedFilter = filter);
              },
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
          color: selected ? const Color(0xFF224F34) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF224F34) : Colors.grey[300]!,
          ),
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

  // ─── Tailors List ──────────────────────────────────────────────────────

  Widget _buildTailorsList(List<Tailor> tailors) {
    if (tailors.isEmpty) {
      return const Center(
        child: Text(
          'No tailors found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tailors.length,
      itemBuilder: (context, index) {
        final tailor = tailors[index];
        return _buildTailorCard(tailor);
      },
    );
  }

  Widget _buildTailorCard(Tailor tailor) {
    // Extract specialty from description
    String specialty = 'Wedding & Formal Wear';
    if (tailor.description != null) {
      final desc = tailor.description!.toLowerCase();
      if (desc.contains('casual')) {
        specialty = 'Casual & Daily Wear';
      } else if (desc.contains('traditional') || desc.contains('ethnic')) {
        specialty = 'Traditional & Ethnic';
      } else if (desc.contains('formal') || desc.contains('informal')) {
        specialty = 'Formal & Informal Wear';
      }
    }

    // Extract experience from description
    String experience = '15 years';
    if (tailor.description != null) {
      final expMatch = RegExp(r'(\d+)\s*years?').firstMatch(tailor.description!);
      if (expMatch != null) {
        experience = '${expMatch.group(1)} years';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Image
          Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              color: Colors.grey[100],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: Image.network(
                tailor.profileImage ??
                    'https://picsum.photos/seed/${tailor.id}/200/200',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tailor.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    specialty,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RatingStars(rating: tailor.rating, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${tailor.rating} (${tailor.reviewCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tailor.generalArea,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Text(
                      experience,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Arrow
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}