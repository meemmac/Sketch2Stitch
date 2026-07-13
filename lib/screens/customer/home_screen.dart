import 'package:flutter/material.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F1),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeroSection(),
                    const SizedBox(height: 20),
                    _buildVirtualTrialBanner(),
                    const SizedBox(height: 30),
                    _buildTrustedBanner(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Drawer (account) ----------------
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF4F9F1),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Image.asset(
                'assets/images/transparent_logo.png',
                height: 45,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.checkroom_rounded, size: 40, color: Color(0xFF2E7D32)),
              ),
            ),
            const Divider(),
            _drawerItem(Icons.person_outline_rounded, 'My Profile', () => Navigator.pop(context)),
            _drawerItem(Icons.shopping_cart_outlined, 'My Cart', () => Navigator.pop(context)),
            _drawerItem(Icons.local_shipping_outlined, 'Track Order', () => Navigator.pop(context)),
            _drawerItem(Icons.logout_rounded, 'Log Out', () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green.shade800),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
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
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Image.asset(
            'assets/images/transparent_logo.png',
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.checkroom_rounded, size: 28, color: Color(0xFF2E7D32)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87),
            onPressed: () {
              // TODO: navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
            onPressed: () {
              // TODO: navigate to cart
            },
          ),
        ],
      ),
    );
  }

  // ---------------- Hero section ----------------
  Widget _buildHeroSection() {
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
                  'Tailoring made easy for you, all in one place.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.green.shade900, height: 1.25),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    // TODO: navigate to browse screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Explore Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/Mask group.png',
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

  // ---------------- Virtual trial banner ----------------
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
              // TODO: navigate to virtual trial screen
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

  // ---------------- Trusted banner ----------------
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
}