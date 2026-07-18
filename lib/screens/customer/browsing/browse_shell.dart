import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_fabrics_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_tailors_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_retailers_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/browsing/filter_data.dart';
import '../../../widgets/dashboard_drawer.dart';

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
    'Browse Fabrics',
    'Browse Elements',
    'Browse Tailors',
    'Browse Retailers',
  ];

  static const List<String> _searchHints = [
    'Search fabrics...',
    'Search elements...',
    'Search tailors...',
    'Search retailers...',
  ];

  static const List<String> _locations = [
    'All',
    'Dhaka',
    'Chittagong',
    'Rajshahi',
    'Khulna',
    'Sylhet',
    'Barishal',
    'Rangpur',
  ];

  static const List<String> _materialTypes = [
    'All',
    'Cotton',
    'Silk',
    'Wool',
    'Linen',
    'Lace',
    'Embroidery',
    'Polyester',
    'Nylon',
    'Rayon',
    'Denim',
    'Leather',
    'Velvet',
    'Satin',
  ];

  // Element "type" options mirror the element categories (Fasteners,
  // Buttons, Threads, etc.) rather than fabric materials, since elements
  // are tagged/filtered by category, not by textile material.
  static const List<String> _elementTypes = [
    'All',
    'Fasteners',
    'Buttons',
    'Threads',
    'Embellishments',
    'Trims',
    'Ribbons',
  ];

  static const List<String> _colorOptions = [
    'All',
    'White',
    'Black',
    'Red',
    'Blue',
    'Green',
    'Gold',
    'Silver',
    'Pink',
    'Beige',
    'Brown',
    'Purple',
  ];

  late final PageController _pageController;
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');
  double _page = 0;

  // ─── Tab-Specific Filter Values ──────────────────────────────────────

  // Fabrics Filters (Price, Color, Material Type) - NO RATING
  double _fabricsMinPrice = 0;
  double _fabricsMaxPrice = 5000;
  String _fabricsSelectedColor = 'All';
  String _fabricsSelectedMaterial = 'All';
  String _fabricsSortBy = 'default'; // 'default', 'lowToHigh', 'highToLow'

  // Elements Filters (Price, Color, Material Type) - NO RATING
  double _elementsMinPrice = 0;
  double _elementsMaxPrice = 5000;
  String _elementsSelectedColor = 'All';
  String _elementsSelectedMaterial = 'All';
  String _elementsSortBy = 'default'; // 'default', 'lowToHigh', 'highToLow'

  // Tailors Filters (Rating, Location)
  double _tailorsMinRating = 0;
  String _tailorsSelectedLocation = 'All';
  String _tailorsSortBy = 'default'; // 'default', 'ratingHighToLow', 'ratingLowToHigh'

  // Retailers Filters (Rating, Location)
  double _retailersMinRating = 0;
  String _retailersSelectedLocation = 'All';
  String _retailersSortBy = 'default'; // 'default', 'ratingHighToLow', 'ratingLowToHigh'

  bool _showFilterOverlay = false;
  bool _showSearchOverlay = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.toDouble();
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
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

  void _toggleFilterOverlay() {
    setState(() {
      _showFilterOverlay = !_showFilterOverlay;
    });
  }

  void _toggleSearchOverlay() {
    setState(() {
      _showSearchOverlay = !_showSearchOverlay;
    });
  }

  void _applyFilters() {
    setState(() {
      _showFilterOverlay = false;
    });
    _searchNotifier.value = _searchNotifier.value;
  }

  void _resetFilters() {
    setState(() {
      // Reset Fabrics filters
      _fabricsMinPrice = 0;
      _fabricsMaxPrice = 5000;
      _fabricsSelectedColor = 'All';
      _fabricsSelectedMaterial = 'All';
      _fabricsSortBy = 'default';

      // Reset Elements filters
      _elementsMinPrice = 0;
      _elementsMaxPrice = 5000;
      _elementsSelectedColor = 'All';
      _elementsSelectedMaterial = 'All';
      _elementsSortBy = 'default';

      // Reset Tailors filters
      _tailorsMinRating = 0;
      _tailorsSelectedLocation = 'All';
      _tailorsSortBy = 'default';

      // Reset Retailers filters
      _retailersMinRating = 0;
      _retailersSelectedLocation = 'All';
      _retailersSortBy = 'default';

      _showFilterOverlay = false;
    });
    _searchNotifier.value = _searchNotifier.value;
  }

  bool get _hasActiveFilters {
    final currentIndex = _page.round().clamp(0, _tabLabels.length - 1);

    if (currentIndex == 0) {
      // Fabrics tab - NO RATING
      return _fabricsMinPrice > 0 ||
          _fabricsMaxPrice < 5000 ||
          _fabricsSelectedColor != 'All' ||
          _fabricsSelectedMaterial != 'All' ||
          _fabricsSortBy != 'default';
    } else if (currentIndex == 1) {
      // Elements tab - NO RATING
      return _elementsMinPrice > 0 ||
          _elementsMaxPrice < 5000 ||
          _elementsSelectedColor != 'All' ||
          _elementsSelectedMaterial != 'All' ||
          _elementsSortBy != 'default';
    } else if (currentIndex == 2) {
      // Tailors tab - Rating + Location
      return _tailorsMinRating > 0 ||
          _tailorsSelectedLocation != 'All' ||
          _tailorsSortBy != 'default';
    } else {
      // Retailers tab - Rating + Location
      return _retailersMinRating > 0 ||
          _retailersSelectedLocation != 'All' ||
          _retailersSortBy != 'default';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _page.round().clamp(0, _tabLabels.length - 1);

    // Create tab-specific filter data
    final fabricsFilterData = FabricsFilterData(
      minPrice: _fabricsMinPrice,
      maxPrice: _fabricsMaxPrice,
      color: _fabricsSelectedColor,
      materialType: _fabricsSelectedMaterial,
      sortBy: _fabricsSortBy,
    );

    final elementsFilterData = ElementsFilterData(
      minPrice: _elementsMinPrice,
      maxPrice: _elementsMaxPrice,
      color: _elementsSelectedColor,
      materialType: _elementsSelectedMaterial,
      sortBy: _elementsSortBy,
    );

    final tailorsFilterData = TailorsFilterData(
      minRating: _tailorsMinRating,
      location: _tailorsSelectedLocation,
      sortBy: _tailorsSortBy,
    );

    final retailersFilterData = RetailersFilterData(
      minRating: _retailersMinRating,
      location: _retailersSelectedLocation,
      sortBy: _retailersSortBy,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const DashboardDrawer(initialRole: AppUserRole.customer),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(currentIndex),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F9F1), // Matches theme sage/pale colors
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: TextField(
                    onChanged: (value) => _searchNotifier.value = value,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 22, color: Colors.grey),
                      hintText: _searchHints[currentIndex],
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              _buildNavigationRow(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    FabricsPageBody(
                      searchQuery: _searchNotifier,
                      filterData: fabricsFilterData,
                      showFabrics: true,
                    ),
                    FabricsPageBody(
                      searchQuery: _searchNotifier,
                      filterData: elementsFilterData,
                      showFabrics: false,
                    ),
                    TailorsPageBody(
                      searchQuery: _searchNotifier,
                      filterData: tailorsFilterData,
                    ),
                    RetailersPageBody(
                      searchQuery: _searchNotifier,
                      filterData: retailersFilterData,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Filter Overlay
          if (_showFilterOverlay)
            GestureDetector(
              onTap: _toggleFilterOverlay,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: GestureDetector(
                  onTap: () {},
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 60, left: 16, right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildFilterPanel(currentIndex),
                    ),
                  ),
                ),
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
        bottom: 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: kSage, size: 24),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(
            'assets/images/transparent_logo.png',
            height: 40,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 40,
                width: 40,
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
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                onPressed: _toggleFilterOverlay,
                icon: Icon(
                  Icons.filter_list,
                  color: _showFilterOverlay || _hasActiveFilters ? kSage : Colors.black87,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          if (currentIndex == 0 || currentIndex == 1) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.black87,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
            onPressed: () {
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ─── Filter Panel ──────────────────────────────────────────────────────

  Widget _buildFilterPanel(int currentTab) {
    if (currentTab == 0) {
      return _buildFabricsFilterPanel();
    } else if (currentTab == 1) {
      return _buildElementsFilterPanel();
    } else if (currentTab == 2) {
      return _buildTailorsFilterPanel();
    } else {
      return _buildRetailersFilterPanel();
    }
  }

  // ─── Search Panel ────────────────────────────────────────────────────────

  Widget _buildSearchPanel(int currentIndex) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Search',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: _toggleSearchOverlay,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 13,
                    color: kSage,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: kSagePale,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder, width: 0.5),
            ),
            child: TextField(
              onChanged: (value) => _searchNotifier.value = value,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: _searchHints[currentIndex],
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                hintStyle: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Fabrics Filter Panel (NO RATING) ─────────────────────────────

  Widget _buildFabricsFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 480),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Fabrics',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reset All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Price Range
            const Text(
              'Price Range',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tk ${_fabricsMinPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Tk ${_fabricsMaxPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(_fabricsMinPrice, _fabricsMaxPrice),
              min: 0,
              max: 5000,
              divisions: 50,
              activeColor: kSage,
              inactiveColor: Colors.grey.shade300,
              onChanged: (values) {
                setState(() {
                  _fabricsMinPrice = values.start;
                  _fabricsMaxPrice = values.end;
                });
              },
            ),
            const SizedBox(height: 6),

            // Sort by Price (small toggle buttons)
            const Text(
              'Sort by Price',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildSortChip(
                  label: 'Low to High',
                  icon: Icons.arrow_upward,
                  value: 'lowToHigh',
                  isFabrics: true,
                ),
                const SizedBox(width: 8),
                _buildSortChip(
                  label: 'High to Low',
                  icon: Icons.arrow_downward,
                  value: 'highToLow',
                  isFabrics: true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Color Filter
            const Text(
              'Color',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _colorOptions.map((color) {
                final isSelected = _fabricsSelectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _fabricsSelectedColor = color;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? kSage : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kSage : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (color != 'All')
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _resolveColor(color),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 0.5),
                            ),
                          ),
                        if (color != 'All') const SizedBox(width: 4),
                        Text(
                          color,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Material Type Filter
            const Text(
              'Material Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _materialTypes.map((material) {
                final isSelected = _fabricsSelectedMaterial == material;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _fabricsSelectedMaterial = material;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? kSage : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kSage : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      material,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Elements Filter Panel (NO RATING) ───────────────────────────

  Widget _buildElementsFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 480),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Elements',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reset All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Price Range
            const Text(
              'Price Range',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tk ${_elementsMinPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Tk ${_elementsMaxPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(_elementsMinPrice, _elementsMaxPrice),
              min: 0,
              max: 5000,
              divisions: 50,
              activeColor: kSage,
              inactiveColor: Colors.grey.shade300,
              onChanged: (values) {
                setState(() {
                  _elementsMinPrice = values.start;
                  _elementsMaxPrice = values.end;
                });
              },
            ),
            const SizedBox(height: 6),

            // Sort by Price (small toggle buttons)
            const Text(
              'Sort by Price',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildSortChip(
                  label: 'Low to High',
                  icon: Icons.arrow_upward,
                  value: 'lowToHigh',
                  isFabrics: false,
                ),
                const SizedBox(width: 8),
                _buildSortChip(
                  label: 'High to Low',
                  icon: Icons.arrow_downward,
                  value: 'highToLow',
                  isFabrics: false,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Color Filter
            const Text(
              'Color',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _colorOptions.map((color) {
                final isSelected = _elementsSelectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _elementsSelectedColor = color;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? kSage : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kSage : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (color != 'All')
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _resolveColor(color),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 0.5),
                            ),
                          ),
                        if (color != 'All') const SizedBox(width: 4),
                        Text(
                          color,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Type Filter (element categories, e.g. Buttons, Threads)
            const Text(
              'Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _elementTypes.map((material) {
                final isSelected = _elementsSelectedMaterial == material;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _elementsSelectedMaterial = material;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? kSage : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kSage : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      material,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Small pill-style sort toggle button used under the Price Range slider.
  // Tapping the already-selected chip clears the sort back to 'default'.
  Widget _buildSortChip({
    required String label,
    required IconData icon,
    required String value,
    required bool isFabrics,
  }) {
    final sortBy = isFabrics ? _fabricsSortBy : _elementsSortBy;
    final isSelected = sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isFabrics) {
            _fabricsSortBy = isSelected ? 'default' : value;
          } else {
            _elementsSortBy = isSelected ? 'default' : value;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? kSage : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kSage : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Small pill-style rating sort chip for the Tailors filter panel.
  Widget _buildTailorsSortChip({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _tailorsSortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tailorsSortBy = isSelected ? 'default' : value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? kSage : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kSage : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Small pill-style rating sort chip for the Retailers filter panel.
  Widget _buildRetailersSortChip({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _retailersSortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _retailersSortBy = isSelected ? 'default' : value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? kSage : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kSage : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tailors Filter Panel (Rating + Location) ──────────────────────

  Widget _buildTailorsFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 480),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Tailors',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reset All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rating Filter
            const Text(
              'Minimum Rating',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _tailorsMinRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    activeColor: Colors.amber,
                    inactiveColor: Colors.grey.shade300,
                    label: '${_tailorsMinRating.toStringAsFixed(1)} ★',
                    onChanged: (value) {
                      setState(() {
                        _tailorsMinRating = value;
                      });
                    },
                  ),
                ),
                Container(
                  width: 45,
                  alignment: Alignment.center,
                  child: Text(
                    '${_tailorsMinRating.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Sort by Rating (small toggle buttons)
            const Text(
              'Sort by Rating',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTailorsSortChip(
                  label: 'High to Low',
                  icon: Icons.arrow_downward,
                  value: 'ratingHighToLow',
                ),
                const SizedBox(width: 8),
                _buildTailorsSortChip(
                  label: 'Low to High',
                  icon: Icons.arrow_upward,
                  value: 'ratingLowToHigh',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location Filter
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _locations.map((location) {
                final isSelected = _tailorsSelectedLocation == location;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _tailorsSelectedLocation = location;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? kSage : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kSage : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Retailers Filter Panel (Rating + Location) ────────────────────

  Widget _buildRetailersFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 480),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Retailers',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reset All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rating Filter
            const Text(
              'Minimum Rating',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _retailersMinRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    activeColor: Colors.amber,
                    inactiveColor: Colors.grey.shade300,
                    label: '${_retailersMinRating.toStringAsFixed(1)} ★',
                    onChanged: (value) {
                      setState(() {
                        _retailersMinRating = value;
                      });
                    },
                  ),
                ),
                Container(
                  width: 45,
                  alignment: Alignment.center,
                  child: Text(
                    '${_retailersMinRating.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Sort by Rating (small toggle buttons)
            const Text(
              'Sort by Rating',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildRetailersSortChip(
                  label: 'High to Low',
                  icon: Icons.arrow_downward,
                  value: 'ratingHighToLow',
                ),
                const SizedBox(width: 8),
                _buildRetailersSortChip(
                  label: 'Low to High',
                  icon: Icons.arrow_upward,
                  value: 'ratingLowToHigh',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location Filter
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _locations.map((location) {
                final isSelected = _retailersSelectedLocation == location;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _retailersSelectedLocation = location;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? kSage : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kSage : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _resolveColor(String name) {
    switch (name.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'black':
        return Colors.black;
      case 'red':
        return Colors.red;
      case 'pink':
        return Colors.pink[200]!;
      case 'blue':
        return Colors.blue[300]!;
      case 'green':
        return Colors.green[300]!;
      case 'beige':
        return const Color(0xFFE8DCC8);
      case 'brown':
        return Colors.brown[300]!;
      case 'gold':
        return const Color(0xFFD4AF37);
      case 'silver':
        return Colors.grey[400]!;
      case 'purple':
        return Colors.purple[300]!;
      default:
        return Colors.grey[300]!;
    }
  }

  // ─── Navigation Row ──────────────────────────────────────────────────────

  Widget _buildNavigationRow() {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_tabLabels.length, (index) {
            final t = (1 - (_page - index).abs()).clamp(0.0, 1.0);
            final fontSize = lerpDouble(14, 17, t)!;
            final color = Color.lerp(
              kSage.withValues(alpha: 0.5),
              kSage,
              t,
            );
            final weight = t > 0.5 ? FontWeight.bold : FontWeight.w600;

            return Padding(
              padding: const EdgeInsets.only(right: 18),
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      height: 3,
                      width: lerpDouble(0, 24, t),
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