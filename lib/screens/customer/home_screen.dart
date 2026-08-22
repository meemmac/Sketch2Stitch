import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_fabrics_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_tailors_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_retailers_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/widgets/cart_icon_button.dart';
import 'package:sketch2stitch/services/browse_service.dart';
import 'package:sketch2stitch/services/favorite_service.dart';
import 'package:sketch2stitch/services/customer_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/dashboard_drawer.dart';
import 'virtual_trial_screen.dart';
import 'notification_screen.dart';
import 'package:sketch2stitch/screens/retailer/inventory_screen.dart';
import 'package:sketch2stitch/screens/tailor/orders_screen.dart';
import 'order_list_screen.dart';

import 'package:sketch2stitch/services/auth_service.dart';
import 'package:sketch2stitch/services/notification_service.dart';

class UnifiedHomeScreen extends StatefulWidget {
  final UserRole initialRole;

  const UnifiedHomeScreen({super.key, this.initialRole = UserRole.customer});

  @override
  State<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen> {
  late UserRole _currentRole;
  final ScrollController _scrollController = ScrollController();

  // Customer specific keys
  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _lastViewedKey = GlobalKey();
  final GlobalKey _favoritesKey = GlobalKey();

  // Common keys
  final GlobalKey _exploreTailorsKey = GlobalKey();
  final GlobalKey _exploreFabricsKey = GlobalKey();
  final GlobalKey _exploreElementsKey = GlobalKey();
  final GlobalKey _exploreRetailersKey = GlobalKey();

  String _favoritesFilter = 'Fabric and elements';

  // ─── Services ──────────────────────────────────────────────────────────
  final BrowseService _browseService = BrowseService();
  final FavoriteService _favoriteService = FavoriteService();
  final CustomerService _customerService = CustomerService();
  String? _currentUserId;

  // ─── Data State ──────────────────────────────────────────────────────
  List<Product> _allProducts = [];
  List<Tailor> _allTailors = [];
  List<Retailer> _allRetailers = [];
  Map<String, String> _retailerNames = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  final List<String> _elementCategories = [
    'Fasteners',
    'Buttons',
    'Threads',
    'Embellishments',
    'Trims',
    'Ribbons',
  ];

  bool _isElement(Product product) =>
      _elementCategories.contains(product.category);

  // ─── Getters ──────────────────────────────────────────────────────────
  List<Product> get _allFabricProducts => _allProducts.where((p) => !_isElement(p)).toList();
  List<Product> get _allElementProducts => _allProducts.where((p) => _isElement(p)).toList();

  List<Product> get _fabricSectionProducts {
    final fabrics = _allFabricProducts;
    return fabrics.take(6).toList();
  }

  List<Product> get _elementSectionProducts {
    final elements = _allElementProducts;
    return elements.take(6).toList();
  }

  String _getRetailerName(String retailerId) {
    return _retailerNames[retailerId] ?? 'Unknown Retailer';
  }

  GeoPoint? _getRetailerLocation(String retailerId) {
    for (final retailer in _allRetailers) {
      if (retailer.id == retailerId) return retailer.location;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
    _getCurrentUser();
    _loadData();
  }

  void _getCurrentUser() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserId = user.uid;
      }
    } catch (e) {
      // no-op: _currentUserId stays null if lookup fails
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      // Load products
      List<Product> products = [];
      try {
        products = await _browseService.getProductsByFilter().first;
      } catch (e) {
        products = [];
      }

      // Load tailors. Fully-booked tailors (maxOrder == 0) are excluded on
      // the home screen entirely, not just sorted last.
      List<Tailor> tailors = [];
      try {
        final loadedTailors = await _browseService.getTailorsByFilter().first;
        tailors = loadedTailors.where((t) => t.maxOrder != 0).toList();
      } catch (e) {
        tailors = [];
      }

      // Load retailers
      List<Retailer> retailers = [];
      try {
        retailers = await _browseService.getRetailersByFilter().first;
      } catch (e) {
        retailers = [];
      }

      // Load retailer names
      Map<String, String> names = {};
      try {
        final retailerSnapshot = await FirebaseFirestore.instance
            .collection('Retailer')
            .get();

        for (final doc in retailerSnapshot.docs) {
          final data = doc.data();
          names[doc.id] = data['shopName'] as String? ?? 'Unknown Retailer';
        }
      } catch (e) {
        // retailer names stay empty; _getRetailerName() falls back per-id
      }

      // Check if we got any data
      if (products.isEmpty && tailors.isEmpty && retailers.isEmpty) {
        setState(() {
          _allProducts = [];
          _allTailors = [];
          _allRetailers = [];
          _retailerNames = names;
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'No data found. Please add products, tailors, and retailers.';
        });
        return;
      }

      setState(() {
        _allProducts = products;
        _allTailors = tailors;
        _allRetailers = retailers;
        _retailerNames = names;
        _isLoading = false;
        _hasError = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  void _openNotifications() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedNotificationScreen(role: _currentRole),
      ),
    );
  }

  void _openOrderList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderListScreen(userRole: _currentRole),
      ),
    );
  }

  void _openBrowseTab(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowseShell(
          initialIndex: index,
          userRole: _currentRole,
        ),
      ),
    );
  }

  void _showProductOverlay(Product product) {
    final bool isFabric = !_isElement(product);
    List<String>? materialBlends;
    
    if (isFabric && product.materialType.isNotEmpty) {
      materialBlends = product.materialType.map((m) {
        if (m.blend > 0) {
          return '${m.blend.toInt()}% ${m.type}';
        }
        return m.type;
      }).toList();
    }

    if (_currentUserId != null) {
      _customerService.addToLastViewed(_currentUserId!, product.id);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(
        product: product,
        isFabric: isFabric,
        retailerName: _getRetailerName(product.retailerId),
        retailerLocation: _getRetailerLocation(product.retailerId),
        materialBlends: materialBlends,
        userRole: _currentRole,
        customerId: _currentUserId,
        favoriteService: _favoriteService,
      ),
    );
  }

  void _openTailorDetail(Tailor tailor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TailorDetailScreen(
          tailor: tailor,
          userRole: _currentRole,
        ),
      ),
    );
  }

  void _openRetailerDetail(Retailer retailer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RetailerDetailScreen(
          retailer: retailer,
          userRole: _currentRole,
        ),
      ),
    );
  }

  void _openSeeAllProducts(String title, List<Product> products) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SeeAllGridScreen<Product>(
          title: title,
          items: products,
          cardBuilder: (context, p) => _buildFabricCard(p),
          userRole: _currentRole,
        ),
      ),
    );
  }

  void _openSeeAllTailors(String title, List<Tailor> tailors) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SeeAllGridScreen<Tailor>(
          title: title,
          items: tailors,
          cardBuilder: (context, t) => _buildTailorCard(t),
          userRole: _currentRole,
        ),
      ),
    );
  }

  void _openSeeAllRetailers(String title, List<Retailer> retailers) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SeeAllGridScreen<Retailer>(
          title: title,
          items: retailers,
          cardBuilder: (context, r) => _buildRetailerCard(r),
          userRole: _currentRole,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    Future.delayed(const Duration(milliseconds: 100), () {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ValueKey(_currentRole),
      backgroundColor: const Color(0xFFF4F9F1),
      drawer: DashboardDrawer(initialRole: _currentRole),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildSectionNavBar(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF6B8F71),
            ),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8F71),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(key: _heroKey, child: _buildHeroSection()),
          const SizedBox(height: 20),
          _buildRoleSpecificSections(),
        ],
      ),
    );
  }

  // ---------------- Top bar ----------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black87),
              iconSize: 28,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Flexible(
            child: Image.asset(
              'assets/images/transparent_logo.png',
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.checkroom_rounded,
                size: 28,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          const Spacer(),
          StreamBuilder<int>(
            stream: NotificationService().getUnreadNotificationCount(
              AuthService().currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black87,
                    ),
                    iconSize: 28,
                    onPressed: _openNotifications,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF4F9F1),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (_currentRole == UserRole.customer)
            IconButton(
              icon: const Icon(
                Icons.local_shipping_outlined,
                color: Colors.black87,
              ),
              iconSize: 28,
              onPressed: _openOrderList,
              tooltip: 'Track Orders',
            ),
          if (_currentRole == UserRole.customer) const CartIconButton(),
        ],
      ),
    );
  }

  // ---------------- Section nav bar ----------------
  Widget _buildSectionNavBar() {
    List<Widget> pills = [];

    if (_currentRole == UserRole.customer) {
      pills.addAll([
        _navPill(
          'Last Viewed',
          Icons.history_rounded,
          () => _scrollToSection(_lastViewedKey),
        ),
        const SizedBox(width: 10),
        _navPill(
          'Wishlist',
          Icons.favorite_border_rounded,
          () => _scrollToSection(_favoritesKey),
        ),
        const SizedBox(width: 10),
      ]);
    }

    pills.addAll([
      _navPill(
        'Fabrics',
        Icons.texture_rounded,
        () => _scrollToSection(_exploreFabricsKey),
      ),
      const SizedBox(width: 10),
      _navPill(
        'Elements',
        Icons.category_outlined,
        () => _scrollToSection(_exploreElementsKey),
      ),
      const SizedBox(width: 10),
      _navPill(
        'Retailers',
        Icons.storefront_outlined,
        () => _scrollToSection(_exploreRetailersKey),
      ),
      const SizedBox(width: 10),
      _navPill(
        'Tailors',
        Icons.storefront_rounded,
        () => _scrollToSection(_exploreTailorsKey),
      ),
    ]);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F1),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: pills),
      ),
    );
  }

  Widget _navPill(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.green.shade800),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Hero section ----------------
  Widget _buildHeroSection() {
    String title;
    String imagePath;
    bool showButton;

    switch (_currentRole) {
      case UserRole.customer:
        title = 'Tailoring made easy for you, all in one place.';
        imagePath = 'assets/images/Mask group.png';
        showButton = true;
        break;
      case UserRole.tailor:
        title = 'Tailoring workspace, digitally organized.';
        imagePath = 'assets/images/tailer_Mask group.png';
        showButton = false;
        break;
      case UserRole.retailer:
        title = 'Manage inventory, track orders and communicate';
        imagePath = 'assets/images/pexels-dima-valkov-6402847 2.png';
        showButton = false;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFD7EFD8),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade900,
                    height: 1.25,
                  ),
                ),
                if (showButton) ...[
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () {
                      _scrollToSection(_exploreFabricsKey);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Explore Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                height: 150,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.white,
                  child: const Icon(
                    Icons.checkroom_rounded,
                    size: 60,
                    color: Color(0xFF4A9A55),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Role specific sections ----------------
  Widget _buildRoleSpecificSections() {
    switch (_currentRole) {
      case UserRole.customer:
        return Column(
          children: [
            _buildVirtualTrialBanner(),
            const SizedBox(height: 30),
            Container(key: _lastViewedKey, child: _buildLastViewedSection()),
            const SizedBox(height: 30),
            Container(key: _favoritesKey, child: _buildFavoritesSection()),
            const SizedBox(height: 30),
            _buildTrustedBanner(),
            const SizedBox(height: 30),
            _buildCommonSections(),
          ],
        );
      case UserRole.tailor:
        return Column(
          children: [
            const SizedBox(height: 10),
            _buildTailorSpecificBanner(),
            const SizedBox(height: 30),
            _buildCommonSections(),
          ],
        );
      case UserRole.retailer:
        return Column(
          children: [
            const SizedBox(height: 10),
            _buildRetailerSpecificBanner(),
            const SizedBox(height: 30),
            _buildCommonSections(),
          ],
        );
    }
  }

  // ---------------- Common sections ----------------
  Widget _buildCommonSections() {
    return Column(
      children: [
        Container(
          key: _exploreFabricsKey,
          child: _buildExploreFabricsSection(),
        ),
        const SizedBox(height: 30),
        Container(
          key: _exploreElementsKey,
          child: _buildExploreElementsSection(),
        ),
        const SizedBox(height: 30),
        Container(
          key: _exploreRetailersKey,
          child: _buildExploreRetailersSection(),
        ),
        const SizedBox(height: 30),
        Container(
          key: _exploreTailorsKey,
          child: _buildExploreTailorsSection(),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------- Customer specific widgets ----------------
  Widget _buildVirtualTrialBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF245244),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/Screenshot 2026-01-30 at 11.24.48 PM 1.png',
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 90,
                height: 90,
                color: Colors.white10,
                child: const Icon(
                  Icons.checkroom_rounded,
                  color: Colors.white54,
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  const TextSpan(
                    text: 'Want to see how you look in that dress? ',
                  ),
                  TextSpan(
                    text: 'Try our virtual trial!',
                    style: TextStyle(
                      color: Colors.green.shade200,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VirtualTrialScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text(
              'Try Now',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFD7EFD8),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              'From trusted fabric retailers to skilled tailors.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.green.shade900,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/Screenshot 2026-01-28 at 4.36.27 AM 1.png',
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  color: Colors.white,
                  child: const Icon(
                    Icons.content_cut_rounded,
                    size: 40,
                    color: Color(0xFF4A9A55),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastViewedSection() {
    final customerId = _currentUserId;
    if (customerId == null) return const SizedBox.shrink();

    return StreamBuilder<List<Product>>(
      stream: _customerService.streamLastViewed(customerId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Your last viewed'),
            const SizedBox(height: 12),
            _buildFabricRow(items),
            _buildSeeAllButton(
              () => _openSeeAllProducts('Your Last Viewed', items),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFavoritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Wishlist'),
        const SizedBox(height: 12),
        _buildFavoritesTabBar(),
        const SizedBox(height: 14),
        _buildFavoritesContent(),
      ],
    );
  }

  Widget _buildFavoritesContent() {
    final customerId = _currentUserId;
    if (customerId == null) return const SizedBox.shrink();

    switch (_favoritesFilter) {
      case 'Retailers':
        return StreamBuilder<List<Retailer>>(
          stream: _favoriteService.getFavoriteRetailers(customerId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _buildRetailerRow(items),
                _buildSeeAllButton(
                  () => _openSeeAllRetailers('Wish-listed Retailers', items),
                ),
              ],
            );
          },
        );
      case 'Tailors':
        return StreamBuilder<List<Tailor>>(
          stream: _favoriteService.getFavoriteTailors(customerId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _buildTailorRow(items),
                _buildSeeAllButton(
                  () => _openSeeAllTailors('Wish-listed Tailors', items),
                ),
              ],
            );
          },
        );
      default:
        return StreamBuilder<List<Product>>(
          stream: _favoriteService.getFavoriteProducts(customerId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _buildFabricRow(items),
                _buildSeeAllButton(
                  () => _openSeeAllProducts('Wish-listed Fabrics & Elements', items),
                ),
              ],
            );
          },
        );
    }
  }

  Widget _buildFavoritesTabBar() {
    final tabs = ['Fabric and elements', 'Retailers', 'Tailors'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: tabs.map((t) {
              final bool active = _favoritesFilter == t;
              return Padding(
                padding: const EdgeInsets.only(right: 22),
                child: GestureDetector(
                  onTap: () => setState(() => _favoritesFilter = t),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: active
                              ? Colors.green.shade600
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.green.shade800 : Colors.black45,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Container(height: 1, color: Colors.black12),
        ],
      ),
    );
  }

  // ---------------- Tailor specific banner ----------------
  Widget _buildTailorSpecificBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal.shade100, Colors.teal.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Orders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your tailoring orders efficiently',
                  style: TextStyle(fontSize: 13, color: Colors.teal.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TailorOrdersScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'View Orders',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Retailer specific banner ----------------
  Widget _buildRetailerSpecificBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal.shade100, Colors.teal.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your stock and manage products',
                  style: TextStyle(fontSize: 13, color: Colors.teal.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Manage Stock',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Shared headers & buttons ----------------
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredHeading(String title) {
    return Center(
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade900,
        ),
      ),
    );
  }

  Widget _buildSeeAllButton(VoidCallback onTap) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.black.withOpacity(0.2)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See all',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 14, color: Colors.black87),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Fabric product row & card ----------------
  Widget _buildFabricRow(List<Product> products) {
    if (products.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: products.length,
        itemBuilder: (context, index) =>
            SizedBox(width: 150, child: _buildFabricCard(products[index])),
      ),
    );
  }

  Widget _buildFabricCard(Product product) {
    final coverImage = product.colorOptions.isNotEmpty && product.colorOptions.first.image.isNotEmpty
        ? product.colorOptions.first.image.first
        : null;
    final bool outOfStock = product.colorOptions.every((c) => c.stock <= 0);
    
    // Check if user is Tailor or Retailer
    final bool isTailorOrRetailer = _currentRole == UserRole.tailor || 
                                     _currentRole == UserRole.retailer;

    return GestureDetector(
      onTap: () => _showProductOverlay(product),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: coverImage != null && coverImage.isNotEmpty
                        ? (coverImage.startsWith('http')
                            ? Image.network(
                                coverImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: const Color(0xFF6B8F71).withOpacity(0.12),
                                      child: Icon(
                                        Icons.texture,
                                        size: 34,
                                        color: const Color(0xFF4A7C59),
                                      ),
                                    ),
                              )
                            : Image.asset(
                                coverImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: const Color(0xFF6B8F71).withOpacity(0.12),
                                      child: Icon(
                                        Icons.texture,
                                        size: 34,
                                        color: const Color(0xFF4A7C59),
                                      ),
                                    ),
                              ))
                        : Container(
                            color: const Color(0xFF6B8F71).withOpacity(0.12),
                            child: Icon(
                              Icons.texture,
                              size: 34,
                              color: const Color(0xFF4A7C59),
                            ),
                          ),
                  ),
                ),
                if (!_isElement(product) && product.materialType.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _materialBadgeText(product),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (outOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Out of Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.priceRange,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4A7C59),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!outOfStock) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: product.colorOptions
                              .take(4)
                              .map(
                                (o) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: _colorDot(o),
                                ),
                              )
                              .toList(),
                        ),
                        // Only show delivery info for customers
                        if (!isTailorOrRetailer)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_bike,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Tk 50',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    // Only show delivery info for customers
                    if (!isTailorOrRetailer)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_bike,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Tk 50',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(ColorOption option) {
    final bool outOfStock = option.stock <= 0;
    return Opacity(
      opacity: outOfStock ? 0.35 : 1.0,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: _resolveColor(option.color),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5),
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
      default:
        return Colors.grey[300]!;
    }
  }

  String _materialBadgeText(Product product) {
    // Build from MaterialBlend list
    if (product.materialType.isEmpty) {
      return "N/A";
    }
    
    final parts = product.materialType.map((m) {
      if (m.blend > 0) {
        return '${m.blend.toInt()}% ${m.type}';
      }
      return m.type;
    }).toList();
    
    final material = parts.join(', ');
    
    if (material.isEmpty || material == "N/A") {
      return "N/A";
    }
    if (material.contains('%')) {
      return material;
    }
    if (material.contains(',')) {
      final splitParts = material.split(',').map((s) => s.trim()).toList();
      final hasPercentages = splitParts.any((p) => p.contains('%'));
      if (hasPercentages) return material;
      return "100% $material";
    }
    return "100% $material";
  }

  // ---------------- Tailor row & card ----------------
  Widget _buildTailorRow(List<Tailor> tailors) {
    if (tailors.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tailors.length,
        itemBuilder: (context, index) =>
            SizedBox(width: 150, child: _buildTailorCard(tailors[index])),
      ),
    );
  }

  Widget _buildTailorCard(Tailor tailor) {
    final bool isTopRated = tailor.rating >= 4.8;
    final String imageUrl = tailor.profilePicture ?? 'assets/images/fab.jpg';
    
    // Check if user is Tailor or Retailer
    final bool isTailorOrRetailer = _currentRole == UserRole.tailor || 
                                     _currentRole == UserRole.retailer;

    return GestureDetector(
      onTap: () => _openTailorDetail(tailor),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: imageUrl.startsWith('http')
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: const Color(0xFF6B8F71).withOpacity(0.12),
                                  child: Icon(Icons.person, size: 34, color: const Color(0xFF4A7C59)),
                                ),
                          )
                        : Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: const Color(0xFF6B8F71).withOpacity(0.12),
                                  child: Icon(Icons.person, size: 34, color: const Color(0xFF4A7C59)),
                                ),
                          ),
                  ),
                ),
                if (isTopRated)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B8F71),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '⭐ Top Rated',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          tailor.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tailor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          tailor.generalArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      // Only show distance for customers
                      if (!isTailorOrRetailer) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '1.8 km',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Only show delivery info for customers
                  if (!isTailorOrRetailer)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_bike,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Tk 50',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Retailer row & card ----------------
  Widget _buildRetailerRow(List<Retailer> retailers) {
    if (retailers.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: retailers.length,
        itemBuilder: (context, index) =>
            SizedBox(width: 150, child: _buildRetailerCard(retailers[index])),
      ),
    );
  }

  Widget _buildRetailerCard(Retailer retailer) {
    final bool isTopRated = retailer.rating >= 4.8;
    final String imageUrl = retailer.profilePicture ?? 'assets/images/fab.jpg';
    
    // Check if user is Tailor or Retailer
    final bool isTailorOrRetailer = _currentRole == UserRole.tailor || 
                                     _currentRole == UserRole.retailer;

    return GestureDetector(
      onTap: () => _openRetailerDetail(retailer),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: imageUrl.startsWith('http')
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: const Color(0xFF6B8F71).withOpacity(0.12),
                                  child: Icon(Icons.store, size: 34, color: const Color(0xFF4A7C59)),
                                ),
                          )
                        : Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: const Color(0xFF6B8F71).withOpacity(0.12),
                                  child: Icon(Icons.store, size: 34, color: const Color(0xFF4A7C59)),
                                ),
                          ),
                  ),
                ),
                if (isTopRated)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B8F71),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '⭐ Top Rated',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          retailer.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    retailer.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          retailer.generalArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      // Only show distance for customers
                      if (!isTailorOrRetailer) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '2.5 km',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Only show delivery info for customers
                  if (!isTailorOrRetailer)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_bike,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Tk 50',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Explore Sections ----------------
  Widget _buildExploreFabricsSection() {
    final items = _fabricSectionProducts;
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCenteredHeading('Explore Fabrics'),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Get in on the trend with our curated selection of fabrics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildFabricRow(items),
        _buildSeeAllButton(() => _openBrowseTab(0)),
      ],
    );
  }

  Widget _buildExploreElementsSection() {
    final items = _elementSectionProducts;
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCenteredHeading('Explore Elements'),
        const SizedBox(height: 14),
        _buildFabricRow(items),
        _buildSeeAllButton(() => _openBrowseTab(1)),
      ],
    );
  }

  Widget _buildExploreRetailersSection() {
    final items = _allRetailers;
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCenteredHeading('Explore Retailers'),
        const SizedBox(height: 14),
        _buildRetailerRow(items.take(6).toList()),
        _buildSeeAllButton(() => _openBrowseTab(3)),
      ],
    );
  }

  Widget _buildExploreTailorsSection() {
    final items = _allTailors;
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCenteredHeading('Explore Tailors'),
        const SizedBox(height: 14),
        _buildTailorRow(items.take(6).toList()),
        _buildSeeAllButton(() => _openBrowseTab(2)),
      ],
    );
  }
}

// ---------------- Generic "See all" grid screen ----------------
class _SeeAllGridScreen<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext, T) cardBuilder;
  final UserRole userRole;

  const _SeeAllGridScreen({
    required this.title,
    required this.items,
    required this.cardBuilder,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: items.isEmpty
          ? const Center(child: Text('Nothing here yet.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  cardBuilder(context, items[index]),
            ),
    );
  }
}