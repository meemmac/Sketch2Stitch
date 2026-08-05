import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/browse_service.dart';
import 'package:sketch2stitch/services/favorite_service.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/browsing/filter_data.dart';
import 'package:sketch2stitch/screens/customer/browsing/retailer_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RetailersPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final RetailersFilterData filterData;
  final UserRole userRole;
  final void Function(String retailerId)? onRetailerSelected;

  const RetailersPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
    this.userRole = UserRole.customer,
    this.onRetailerSelected,
  });

  @override
  State<RetailersPageBody> createState() => _RetailersPageBodyState();
}

class _RetailersPageBodyState extends State<RetailersPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BrowseService _browseService = BrowseService();
  final FavoriteService _favoriteService = FavoriteService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        return StreamBuilder<List<Retailer>>(
          stream: _browseService.getRetailersByFilter(
            minRating: widget.filterData.minRating > 0
                ? widget.filterData.minRating
                : null,
            location: widget.filterData.location != 'All'
                ? widget.filterData.location
                : null,
            sortBy: widget.filterData.sortBy,
            search: searchQuery.isNotEmpty ? searchQuery : null,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
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
                      'Error loading retailers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error?.toString() ?? 'Unknown error',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6B8F71),
                ),
              );
            }

            final retailers = snapshot.data ?? [];

            if (retailers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Retailers found',
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

            return Column(
              children: [
                _buildHeroSection(),
                Expanded(
                  child: _buildRetailersGrid(retailers),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 8,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A7C59), Color(0xFF6B8F71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quality Retailers',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trusted stores for premium fabrics and materials',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
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
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10 : 12,
        vertical: isSmall ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
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
              'No Retailers found',
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
      itemCount: retailers.length,
      itemBuilder: (context, index) {
        final retailer = retailers[index];
        return _buildRetailerCard(retailer, isSmallScreen);
      },
    );
  }

  Widget _buildRetailerCard(Retailer retailer, bool isSmall) {
    final bool isTopRated = retailer.rating >= 4.8;
    String imageUrl = retailer.profilePicture ?? 'assets/images/fab.jpg';

    return GestureDetector(
      onTap: () {
        if (widget.onRetailerSelected != null) {
          widget.onRetailerSelected!(retailer.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RetailerDetailScreen(
                retailer: retailer,
                userRole: widget.userRole,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
            Flexible(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF6B8F71).withOpacity(0.12),
                                child: Icon(
                                  Icons.store,
                                  size: isSmall ? 36 : 40,
                                  color: const Color(0xFF4A7C59),
                                ),
                              ),
                            )
                          : Image.asset(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF6B8F71).withOpacity(0.12),
                                child: Icon(
                                  Icons.store,
                                  size: isSmall ? 36 : 40,
                                  color: const Color(0xFF4A7C59),
                                ),
                              ),
                            ),
                    ),
                  ),
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
                          color: const Color(0xFF6B8F71),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
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
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 6 : 8,
                        vertical: isSmall ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
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
                            retailer.generalArea,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                    ),
                    if (retailer.about != null && retailer.about!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: isSmall ? 2 : 4),
                        child: Text(
                          retailer.about!,
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF4A7C59),
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (retailer.products != null && retailer.products!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: isSmall ? 2 : 4),
                        child: Text(
                          '${retailer.products!.length} products',
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF4A7C59),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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