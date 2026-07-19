import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_fabrics_screen.dart' show kHardcodedProducts;
import 'package:sketch2stitch/screens/customer/browsing/browse_tailors_screen.dart' show kHardcodedTailors;
import 'package:sketch2stitch/screens/customer/browsing/browse_retailers_screen.dart' show kHardcodedRetailers;
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/screens/customer/browsing/tailor_detail_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/retailer_detail_screen.dart';
import 'package:sketch2stitch/screens/customer/cart_screen.dart';
import '../../widgets/dashboard_drawer.dart';
import 'virtual_trial_screen.dart';
import 'notification_screen.dart' ;
import 'package:sketch2stitch/screens/retailer/inventory_screen.dart';
import 'track_order.dart';

class UnifiedHomeScreen extends StatefulWidget {
  final AppUserRole initialRole;

  const UnifiedHomeScreen({
    super.key,
    this.initialRole = AppUserRole.customer,
  });

  @override
  State<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen> {
  late AppUserRole _currentRole;
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
  bool _hasUnreadNotifications = true;

  // TODO: replace with the signed-in user's real "last viewed" history
  List<Product> get _lastViewedProducts => kHardcodedProducts.take(3).toList();

  // TODO: replace with the signed-in user's real saved favorites
  List<Product> get _favoriteFabricProducts => kHardcodedProducts.skip(2).take(3).toList();
  List<Tailor> get _favoriteTailors => kHardcodedTailors.take(3).toList();
  List<Retailer> get _favoriteRetailers => kHardcodedRetailers.take(3).toList();

  List<Product> get _fabricSectionProducts => kHardcodedProducts
      .where((p) => ['Cotton', 'Silk', 'Wool', 'Linen'].contains(p.category))
      .take(6)
      .toList();

  List<Product> get _elementSectionProducts => kHardcodedProducts
      .where((p) => ['Lace', 'Embroidery'].contains(p.category))
      .take(6)
      .toList();

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
  }

  void _openNotifications() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedNotificationScreen(role: _currentRole),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _hasUnreadNotifications = false;
      });
    }

  }
  void _openTrackOrder() {
    // Navigate to Order Track Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTrackScreen(
          orderId: 'OR05',
          status: 'Pending Retailer Confirmation',
          estimatedDelivery: '25 Dec 2026',
          lastUpdated: '22 Dec 2026',
          deliveryAddress: 'The Shakespeare Centre, Henley Street, CV37 6QW Stratford-upon-Avon, UK.',
          userRole: AppUserRole.customer,
        ),
      ),
    );
  }

  void _openBrowseTab(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BrowseShell(initialIndex: index)),
    );
  }

  void _showProductOverlay(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(product: product),
    );
  }

  void _openTailorDetail(Tailor tailor) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TailorDetailScreen(tailor: tailor)),
    );
  }

  void _openRetailerDetail(Retailer retailer) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RetailerDetailScreen(retailer: retailer)),
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
      backgroundColor: const Color(0xFFF4F9F1),
      // Pass the current role to the drawer
      drawer: DashboardDrawer(
        initialRole: _currentRole,
        onRoleChanged: (role) {
          setState(() {
            _currentRole = role;
          });
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildSectionNavBar(),
            Expanded(
              child: SingleChildScrollView(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Top bar ----------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
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
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.checkroom_rounded, size: 28, color: Color(0xFF2E7D32)),
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87),
                iconSize: 28,
                onPressed: _openNotifications,
              ),
              if (_hasUnreadNotifications)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF4F9F1), width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          // Track Order icon - only for customer
          if (_currentRole == AppUserRole.customer)
            IconButton(
              icon: const Icon(Icons.track_changes_rounded, color: Colors.black87),
              iconSize: 28,
              onPressed: () {
                _openTrackOrder();
              },
            ),
          // Show cart icon only for customer
          if (_currentRole == AppUserRole.customer)
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
              iconSize: 28,
              onPressed: () {
                Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
              },
            ),
          // Role dropdown for testing
          _buildRoleDropdown(),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<AppUserRole>(
        value: _currentRole,
        underline: const SizedBox(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E392A),
        ),
        items: const [
          DropdownMenuItem(
            value: AppUserRole.customer,
            child: Text("Customer"),
          ),
          DropdownMenuItem(
            value: AppUserRole.tailor,
            child: Text("Tailor"),
          ),
          DropdownMenuItem(
            value: AppUserRole.retailer,
            child: Text("Retailer"),
          ),
        ],
        onChanged: (role) {
          if (role != null) {
            setState(() {
              _currentRole = role;
            });
          }
        },
      ),
    );
  }

  // ---------------- Section nav bar ----------------
  Widget _buildSectionNavBar() {
    List<Widget> pills = [];

    // Customer specific sections
    if (_currentRole == AppUserRole.customer) {
      pills.addAll([
        _navPill('Last Viewed', Icons.history_rounded, () => _scrollToSection(_lastViewedKey)),
        const SizedBox(width: 10),
        _navPill('Favorites', Icons.favorite_border_rounded, () => _scrollToSection(_favoritesKey)),
        const SizedBox(width: 10),
      ]);
    }

    // Common sections for all roles
    pills.addAll([
      _navPill('Fabrics', Icons.texture_rounded, () => _scrollToSection(_exploreFabricsKey)),
      const SizedBox(width: 10),
      _navPill('Elements', Icons.category_outlined, () => _scrollToSection(_exploreElementsKey)),
      const SizedBox(width: 10),
      _navPill('Retailers', Icons.storefront_outlined, () => _scrollToSection(_exploreRetailersKey)),
      const SizedBox(width: 10),
      _navPill('Tailors', Icons.storefront_rounded, () => _scrollToSection(_exploreTailorsKey)),
    ]);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F1),
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
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
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.green.shade800),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.green.shade900)),
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
      case AppUserRole.customer:
        title = 'Tailoring made easy for you, all in one place.';
        imagePath = 'assets/images/Mask group.png';
        showButton = true;
        break;
      case AppUserRole.tailor:
        title = 'Tailoring workspace, digitally organized.';
        imagePath = 'assets/images/tailer_Mask group.png';
        showButton = false;
        break;
      case AppUserRole.retailer:
        title = 'Manage inventory, track orders and communicate';
        imagePath = 'assets/images/pexels-dima-valkov-6402847 2.png';
        showButton = false;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFD7EFD8), borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.green.shade900, height: 1.25),
                ),
                if (showButton) ...[
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () {
                      _scrollToSection(_exploreTailorsKey);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Explore Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
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
                  child: const Icon(Icons.checkroom_rounded, size: 60, color: Color(0xFF4A9A55)),
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
      case AppUserRole.customer:
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
      case AppUserRole.tailor:
        return Column(
          children: [
            const SizedBox(height: 10),
            _buildTailorSpecificBanner(),
            const SizedBox(height: 30),
            _buildCommonSections(),
          ],
        );
      case AppUserRole.retailer:
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

  // ---------------- Common sections (Fabrics, Elements, Retailers, Tailors) ----------------
  Widget _buildCommonSections() {
    return Column(
      children: [
        Container(key: _exploreFabricsKey, child: _buildExploreFabricsSection()),
        const SizedBox(height: 30),
        Container(key: _exploreElementsKey, child: _buildExploreElementsSection()),
        const SizedBox(height: 30),
        Container(key: _exploreRetailersKey, child: _buildExploreRetailersSection()),
        const SizedBox(height: 30),
        Container(key: _exploreTailorsKey, child: _buildExploreTailorsSection()),
        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------- Customer specific widgets ----------------
  Widget _buildVirtualTrialBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF245244), borderRadius: BorderRadius.circular(24)),
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
                child: const Icon(Icons.checkroom_rounded, color: Colors.white54, size: 36),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white, fontWeight: FontWeight.w600),
                children: [
                  const TextSpan(text: 'Want to see how you look in that dress? '),
                  TextSpan(text: 'Try our virtual trial!', style: TextStyle(color: Colors.green.shade200, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VirtualTrialScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade400,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Try Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFD7EFD8), borderRadius: BorderRadius.circular(28)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              'From trusted fabric retailers to skilled tailors.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.green.shade900, height: 1.25),
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
                  child: const Icon(Icons.content_cut_rounded, size: 40, color: Color(0xFF4A9A55)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastViewedSection() {
    final items = _lastViewedProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Your last viewed'),
        const SizedBox(height: 12),
        _buildFabricRow(items),
        _buildSeeAllButton(() => _openSeeAllProducts('Your Last Viewed', items)),
      ],
    );
  }

  Widget _buildFavoritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Favorites'),
        const SizedBox(height: 12),
        _buildFavoritesTabBar(),
        const SizedBox(height: 14),
        _buildFavoritesContent(),
      ],
    );
  }

  Widget _buildFavoritesContent() {
    switch (_favoritesFilter) {
      case 'Retailers':
        final items = _favoriteRetailers;
        return Column(
          children: [
            _buildRetailerRow(items),
            _buildSeeAllButton(() => _openSeeAllRetailers('Favorite Retailers', items)),
          ],
        );
      case 'Tailors':
        final items = _favoriteTailors;
        return Column(
          children: [
            _buildTailorRow(items),
            _buildSeeAllButton(() => _openSeeAllTailors('Favorite Tailors', items)),
          ],
        );
      default:
        final items = _favoriteFabricProducts;
        return Column(
          children: [
            _buildFabricRow(items),
            _buildSeeAllButton(() => _openSeeAllProducts('Favorite Fabrics & Elements', items)),
          ],
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
                        bottom: BorderSide(color: active ? Colors.green.shade600 : Colors.transparent, width: 2),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
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
              // TODO: Navigate to orders
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('View Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
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
                  ' Inventory Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
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
              // TODO: Navigate to inventory
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InventoryScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Manage Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
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
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCenteredHeading(String title) {
    return Center(
      child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('See all', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
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
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: products.length,
        itemBuilder: (context, index) => SizedBox(width: 150, child: _buildFabricCard(products[index])),
      ),
    );
  }

  Widget _buildFabricCard(Product product) {
    final coverImage = product.colorOptions.isNotEmpty ? product.colorOptions.first.image : null;
    final bool outOfStock = product.colorOptions.every((c) => c.stock <= 0);

    return GestureDetector(
      onTap: () => _showProductOverlay(product),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: coverImage != null
                        ? Image.asset(
                      coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: kSage.withOpacity(0.12),
                        child: Icon(Icons.texture, size: 34, color: kSageDark),
                      ),
                    )
                        : Container(color: kSage.withOpacity(0.12), child: Icon(Icons.texture, size: 34, color: kSageDark)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(10)),
                    child: Text(product.category, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (outOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.85), borderRadius: BorderRadius.circular(10)),
                      child: const Text('Out of Stock', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
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
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.priceRange,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kSageDark),
                  ),
                  if (!outOfStock) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: product.colorOptions
                          .take(4)
                          .map((o) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _colorDot(o),
                      ))
                          .toList(),
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
          border: Border.all(color: kBorder, width: 0.5),
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

  // ---------------- Tailor row & card ----------------
  Widget _buildTailorRow(List<Tailor> tailors) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tailors.length,
        itemBuilder: (context, index) => SizedBox(width: 150, child: _buildTailorCard(tailors[index])),
      ),
    );
  }

  Widget _buildTailorCard(Tailor tailor) {
    final bool isTopRated = tailor.rating >= 4.8;
    final String imageUrl = tailor.profilePicture ?? 'assets/images/fab.jpg';

    return GestureDetector(
      onTap: () => _openTailorDetail(tailor),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: kSage.withOpacity(0.12),
                        child: Icon(Icons.person, size: 34, color: kSageDark),
                      ),
                    ),
                  ),
                ),
                if (isTopRated)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kSage, borderRadius: BorderRadius.circular(10)),
                      child: const Text('⭐ Top Rated', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 10),
                        const SizedBox(width: 3),
                        Text(tailor.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
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
                  Text(tailor.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          tailor.generalArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                        ),
                      ),
                    ],
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
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: retailers.length,
        itemBuilder: (context, index) => SizedBox(width: 150, child: _buildRetailerCard(retailers[index])),
      ),
    );
  }

  Widget _buildRetailerCard(Retailer retailer) {
    final bool isTopRated = retailer.rating >= 4.8;
    final String imageUrl = retailer.profilePicture ?? 'assets/images/fab.jpg';

    return GestureDetector(
      onTap: () => _openRetailerDetail(retailer),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: kSage.withOpacity(0.12),
                        child: Icon(Icons.store, size: 34, color: kSageDark),
                      ),
                    ),
                  ),
                ),
                if (isTopRated)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kSage, borderRadius: BorderRadius.circular(10)),
                      child: const Text('⭐ Top Rated', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 10),
                        const SizedBox(width: 3),
                        Text(retailer.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
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
                  Text(retailer.shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          retailer.generalArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                        ),
                      ),
                    ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCenteredHeading('Explore Fabrics'),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Get in on the trend with our curated selection of fabrics.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.55)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCenteredHeading('Explore Elements'),
        const SizedBox(height: 14),
        _buildFabricRow(items),
        _buildSeeAllButton(() => _openBrowseTab(0)),
      ],
    );
  }

  Widget _buildExploreRetailersSection() {
    final items = kHardcodedRetailers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCenteredHeading('Explore Retailers'),
        const SizedBox(height: 14),
        _buildRetailerRow(items),
        _buildSeeAllButton(() => _openBrowseTab(2)),
      ],
    );
  }

  Widget _buildExploreTailorsSection() {
    final items = kHardcodedTailors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCenteredHeading('Explore Tailors'),
        const SizedBox(height: 14),
        _buildTailorRow(items),
        _buildSeeAllButton(() => _openBrowseTab(1)),
      ],
    );
  }
}

// ---------------- Generic "See all" grid screen ----------------
class _SeeAllGridScreen<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext, T) cardBuilder;

  const _SeeAllGridScreen({
    required this.title,
    required this.items,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
        itemBuilder: (context, index) => cardBuilder(context, items[index]),
      ),
    );
  }
}