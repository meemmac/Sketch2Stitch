import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_fabrics_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_tailors_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_retailers_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/test_cloudinary_screen.dart'; // Add this import

/// Shared shell for the three "Browse" tabs (Fabrics/Clothing, Tailors,
/// Retailers). Provides one header, one animated navigation row, and a
/// swipeable [PageView] so switching tabs feels like a standard app
/// (tap a label OR swipe left/right, both animate smoothly together).
class BrowseShell extends StatefulWidget {
  /// 0 = Fabrics/Clothing, 1 = Tailors, 2 = Retailers
  final int initialIndex;

  const BrowseShell({super.key, this.initialIndex = 0});

  @override
  State<BrowseShell> createState() => _BrowseShellState();
}

class _BrowseShellState extends State<BrowseShell> {
  static const List<String> _tabLabels = [
    'Browse Clothing and Elements',
    'Browse Tailors',
    'Browse Retailers',
  ];

  static const List<String> _searchHints = [
    'Search fabrics...',
    'Search tailors...',
    'Search retailers...',
  ];

  late final PageController _pageController;
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.toDouble();
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    // .page is null on the very first frame before the PageView lays out.
    final value = _pageController.page;
    if (value != null && value != _page) {
      setState(() => _page = value);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _page.round().clamp(0, _tabLabels.length - 1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              _buildHeader(currentIndex),
              _buildNavigationRow(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    FabricsPageBody(searchQuery: _searchNotifier),
                    TailorsPageBody(searchQuery: _searchNotifier),
                    RetailersPageBody(searchQuery: _searchNotifier),
                  ],
                ),
              ),
            ],
          ),
          
          // Cloudinary Test Floating Action Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TestCloudinaryScreen(),
                  ),
                );
              },
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              tooltip: 'Test Cloudinary Upload',
              child: const Icon(Icons.cloud_upload),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader(int currentIndex) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // Open drawer later
            },
            icon: const Icon(Icons.menu, color: kSage),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/transparent_logo.png',
            height: 45,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 45,
                width: 45,
                decoration: const BoxDecoration(
                  color: kSage,
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
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: kSagePale,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: TextField(
                onChanged: (value) => _searchNotifier.value = value,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: _searchHints[currentIndex],
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: kSage,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation Row ──────────────────────────────────────────────────────
  // Tapping a label animates the PageView; swiping the PageView animates
  // the labels — both routes drive the same `_page` value so the row and
  // the content always stay perfectly in sync.

  Widget _buildNavigationRow() {
    return SizedBox(
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_tabLabels.length, (index) {
            // 1.0 when this tab is fully active, fading to 0.0 as the
            // page scrolls a full page away.
            final t = (1 - (_page - index).abs()).clamp(0.0, 1.0);
            final fontSize = lerpDouble(14, 18, t)!;
            final color = Color.lerp(
              kSage.withValues(alpha: 0.5),
              kSage,
              t,
            );
            final weight = t > 0.5 ? FontWeight.bold : FontWeight.w600;

            return Padding(
              padding: const EdgeInsets.only(right: 22),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _goToPage(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 120),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: weight,
                        color: color,
                      ),
                      child: Text(_tabLabels[index]),
                    ),
                    const SizedBox(height: 4),
                    // Sliding underline that fades in/out with activity.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      height: 2.5,
                      width: lerpDouble(0, 28, t),
                      decoration: BoxDecoration(
                        color: kSage.withValues(alpha: t),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}