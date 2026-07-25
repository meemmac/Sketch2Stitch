import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/customer/virtual_trial_screen.dart';
import '../screens/retailer/inventory_screen.dart';
import '../screens/retailer/orders_screen.dart';
import '../screens/customer/measurement_screen.dart';
import '../models/measurement.dart';
import '../screens/shared/welcome_screen.dart';
import '../screens/shared/about_us_screen.dart';
import '../screens/shared/location_picker_screen.dart';
import '../screens/tailor/portfolio_screen.dart';
import '../screens/tailor/orders_screen.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/orders/order_detail_screen.dart';

/// Enum representing the three user roles.
enum AppUserRole { customer, tailor, retailer }

/// Model class representing the profile information for the drawer.
class DrawerProfileData {
  final String name;
  final String shopName; // Only for Retailer
  final String email;
  final String phone;
  final String address;
  final double rating; // For Tailor and Retailer
  final String? profilePicture;
  final String? about;
  final GeoPoint?
  location; // Pinned lat/lng — doubles as delivery location for customers

  const DrawerProfileData({
    required this.name,
    this.shopName = '',
    required this.email,
    required this.phone,
    required this.address,
    this.rating = 0.0,
    this.profilePicture,
    this.about = '',
    this.location,
  });

  double? get locationLat => location?.latitude;
  double? get locationLng => location?.longitude;

  DrawerProfileData copyWith({
    String? name,
    String? shopName,
    String? email,
    String? phone,
    String? address,
    double? rating,
    String? profilePicture,
    String? about,
    GeoPoint? location,
  }) {
    return DrawerProfileData(
      name: name ?? this.name,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      profilePicture: profilePicture ?? this.profilePicture,
      about: about ?? this.about,
      location: location ?? this.location,
    );
  }
}

/// The main reusable Dashboard Drawer widget.
///
/// The role shown here is decided once, upstream — by whatever tells
/// `UnifiedHomeScreen` who's logged in (real auth once that's wired up).
/// This widget just renders that role; it no longer owns a role switcher.
class DashboardDrawer extends StatefulWidget {
  final AppUserRole initialRole;

  const DashboardDrawer({super.key, this.initialRole = AppUserRole.customer});

  @override
  State<DashboardDrawer> createState() => _DashboardDrawerState();
}

class _DashboardDrawerState extends State<DashboardDrawer> {
  late AppUserRole _currentRole;

  // Placeholder profile details
  late DrawerProfileData _customerProfile;
  late DrawerProfileData _tailorProfile;
  late DrawerProfileData _retailerProfile;
  late Measurement _customerMeasurement;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;

    _customerMeasurement = Measurement(
      id: "meas_1",
      customerId: "maria_doe",
      upperBustCircumference: 34.0,
      roundShoulderCircumference: 38.0,
      hipsCircumference: 36.0,
      underBustCircumference: 32.0,
      bustCircumference: 35.0,
      waist: 28.0,
      shoulderToKnee: 38.0,
      shoulderToUnderBust: 12.5,
      shoulderToBust: 10.0,
      thigh: 21.0,
      knee: 14.0,
      ankle: 9.0,
      waistToAnkle: 40.0,
      shoulderToAnkle: 57.0,
    );

    // Initialize mock data
    _customerProfile = const DrawerProfileData(
      name: "Maria Doe",
      email: "maria.doe@example.com",
      phone: "+880 1234567890",
      address: "123 Creative Lane, New Market Road, Dhaka",
    );

    _tailorProfile = const DrawerProfileData(
      name: "Master Karim",
      email: "karim.tailors@example.com",
      phone: "+880 1234567890",
      address: "Suite 4B, Concord Tower, Dhaka",
      rating: 4.8,
      about:
          "Bespoke traditional and modern wear expert with over 15 years of experience in custom tailoring.",
    );

    _retailerProfile = const DrawerProfileData(
      name: "Alim Rahman",
      shopName: "Elegant Fabrics Ltd.",
      email: "contact@elegantfabrics.com",
      phone: "+880 1234567890",
      address: "Shop 12, Banani Super Market, Dhaka",
      rating: 4.6,
      about:
          "Premium local and imported fabric supplier specializing in silk, cotton, and wedding collections.",
    );
  }

  DrawerProfileData get _activeProfile {
    switch (_currentRole) {
      case AppUserRole.customer:
        return _customerProfile;
      case AppUserRole.tailor:
        return _tailorProfile;
      case AppUserRole.retailer:
        return _retailerProfile;
    }
  }

  void _updateProfile(DrawerProfileData updated) {
    setState(() {
      switch (_currentRole) {
        case AppUserRole.customer:
          _customerProfile = updated;
          break;
        case AppUserRole.tailor:
          _tailorProfile = updated;
          break;
        case AppUserRole.retailer:
          _retailerProfile = updated;
          break;
      }
    });
    debugPrint("Profile updated: ${updated.name} (${_currentRole.name})");
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(
      0xFF6C9985,
    ); // Sage theme color matching AI Test Screen

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Profile Section
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: DrawerProfileSection(
                      role: _currentRole,
                      profile: _activeProfile,
                      themeColor: themeColor,
                      onEditPressed: () => _openEditScreen(context),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(),
                    ),
                  ),

                  // Navigation Section
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DrawerNavigationSection(
                            role: _currentRole,
                            themeColor: themeColor,
                            measurement: _customerMeasurement,
                            onSave: (updated) async {
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );
                              if (!mounted) return;
                              setState(() {
                                _customerMeasurement = updated;
                              });
                            },
                          ),
                        ),
                        const Divider(height: 1),

                        // Logout Section
                        DrawerLogoutButton(
                          onLogoutPressed: () {
                            debugPrint("Logout pressed");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Logged out successfully!"),
                              ),
                            );
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
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

  Future<void> _openEditScreen(BuildContext context) async {
    // Close the drawer first so we're not pushing a full-screen route
    // on top of an open Drawer overlay.
    Navigator.pop(context);

    final updatedProfile = await Navigator.push<DrawerProfileData>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          role: _currentRole,
          initialProfile: _activeProfile,
        ),
      ),
    );

    if (updatedProfile != null) {
      _updateProfile(updatedProfile);
    }
  }
}

/// Profile display widget inside the drawer.
class DrawerProfileSection extends StatelessWidget {
  final AppUserRole role;
  final DrawerProfileData profile;
  final Color themeColor;
  final VoidCallback onEditPressed;

  const DrawerProfileSection({
    super.key,
    required this.role,
    required this.profile,
    required this.themeColor,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCustomer = role == AppUserRole.customer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row containing Avatar & Title Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: themeColor.withValues(alpha: 0.15),
                backgroundImage:
                    profile.profilePicture != null &&
                        profile.profilePicture!.isNotEmpty
                    ? FileImage(File(profile.profilePicture!))
                    : null,
                child:
                    profile.profilePicture != null &&
                        profile.profilePicture!.isNotEmpty
                    ? null
                    : Icon(
                        isCustomer
                            ? Icons.person_rounded
                            : (role == AppUserRole.tailor
                                  ? Icons.design_services_rounded
                                  : Icons.storefront_rounded),
                        color: themeColor,
                        size: 32,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role == AppUserRole.retailer
                          ? profile.shopName
                          : profile.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E392A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        role.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: themeColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rating & Edit Row
          Row(
            children: [
              if (!isCustomer) ...[
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  profile.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E392A),
                  ),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                onPressed: onEditPressed,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text(
                  "Edit",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detailed Fields
          _buildInfoRow(Icons.email_outlined, profile.email),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone_outlined, profile.phone),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on_outlined, profile.address),
          if (profile.location != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.pin_drop_outlined,
              '${profile.location!.latitude.toStringAsFixed(5)}, '
              '${profile.location!.longitude.toStringAsFixed(5)}'
              '${isCustomer ? '  (delivery location)' : ''}',
            ),
          ],
          if (!isCustomer &&
              profile.about != null &&
              profile.about!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              "About",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E392A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.about!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Navigation section widget filtering routes based on user role.
class DrawerNavigationSection extends StatelessWidget {
  final AppUserRole role;
  final Color themeColor;
  final Measurement? measurement;
  final Future<void> Function(Measurement)? onSave;

  const DrawerNavigationSection({
    super.key,
    required this.role,
    required this.themeColor,
    this.measurement,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = _getNavigationItems();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        children: items.map((item) {
          return NavigationDrawerDestination(
            icon: item['icon'] as IconData,
            label: item['title'] as String,
            themeColor: themeColor,
            onTap: () {
              Navigator.pop(context); // close drawer first
              if (item['title'] == 'Virtual Trial') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VirtualTrialScreen()),
                );
              } else if (item['title'] == 'Orders') {
                if (role == AppUserRole.retailer) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RetailerOrdersScreen(),
                    ),
                  );
                } else if (role == AppUserRole.customer) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderDetailScreen(),
                    ),
                  );
                } else if (role == AppUserRole.tailor) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TailorOrdersScreen(),
                    ),
                  );
                }
              } else if (item['title'] == 'Measurements') {
                if (measurement != null && onSave != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MeasurementScreen(
                        measurement: measurement!,
                        onSave: onSave!,
                      ),
                    ),
                  );
                }
              } else if (item['title'] == 'Cart') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              } else if (item['title'] == 'Inventory') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                );
              } else if (item['title'] == 'Portfolio') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TailorPortfolioScreen(),
                  ),
                );
              } else {
                debugPrint("Navigation clicked: ${item['title']}");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Navigation trigger: ${item['title']}"),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _getNavigationItems() {
    switch (role) {
      case AppUserRole.customer:
        return [
          {'title': 'Virtual Trial', 'icon': Icons.auto_awesome_rounded},
          {'title': 'Measurements', 'icon': Icons.straighten_rounded},
          {'title': 'Cart', 'icon': Icons.shopping_bag_outlined},
          {'title': 'Messages', 'icon': Icons.chat_bubble_outline_rounded},
          {'title': 'Orders', 'icon': Icons.receipt_long_rounded},
        ];
      case AppUserRole.tailor:
        return [
          {'title': 'Orders', 'icon': Icons.receipt_long_rounded},
          {'title': 'Portfolio', 'icon': Icons.design_services_outlined},
          {'title': 'Messages', 'icon': Icons.chat_bubble_outline_rounded},
        ];
      case AppUserRole.retailer:
        return [
          {'title': 'Orders', 'icon': Icons.receipt_long_rounded},
          {'title': 'Inventory', 'icon': Icons.inventory_2_outlined},
        ];
    }
  }
}

/// Individual Navigation item styling
class NavigationDrawerDestination extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color themeColor;
  final VoidCallback onTap;

  const NavigationDrawerDestination({
    super.key,
    required this.icon,
    required this.label,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, color: Colors.black54, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black26,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed logout button at the bottom of the drawer.
class DrawerLogoutButton extends StatelessWidget {
  final VoidCallback onLogoutPressed;

  const DrawerLogoutButton({super.key, required this.onLogoutPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade200),
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onLogoutPressed,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            "Logout",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

/// Full-screen profile editor, shared across all three roles.
///
/// Replaces the old `ProfileEditDialog` (AlertDialog). A full screen gives
/// the form room to breathe and makes pushing the map picker a normal
/// screen -> screen navigation instead of a route stacked on a modal.
///
/// Returns the updated `DrawerProfileData` via `Navigator.pop(context, data)`
/// when saved, or `null` if the user backs out without saving.
class EditProfileScreen extends StatefulWidget {
  final AppUserRole role;
  final DrawerProfileData initialProfile;

  const EditProfileScreen({
    super.key,
    required this.role,
    required this.initialProfile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _shopNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _aboutController;

  String? _profilePicturePath;
  GeoPoint? _selectedLocation;
  bool _locationError =
      false; // true once the user has tried to save without pinning

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _shopNameController = TextEditingController(
      text: widget.initialProfile.shopName,
    );
    _emailController = TextEditingController(text: widget.initialProfile.email);
    _phoneController = TextEditingController(text: widget.initialProfile.phone);
    _addressController = TextEditingController(
      text: widget.initialProfile.address,
    );
    _aboutController = TextEditingController(
      text: widget.initialProfile.about ?? '',
    );
    _profilePicturePath = widget.initialProfile.profilePicture;
    _selectedLocation = widget.initialProfile.location;
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _profilePicturePath = picked.path;
        });
      }
    } catch (e) {
      debugPrint("Error picking profile image: $e");
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<GeoPoint>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(initialLocation: _selectedLocation),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedLocation = result;
        _locationError = false;
      });
    }
  }

  void _save() {
    if (_selectedLocation == null) {
      setState(() => _locationError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pin your location before saving.'),
        ),
      );
      return;
    }

    final updated = widget.initialProfile.copyWith(
      name: _nameController.text,
      shopName: widget.role == AppUserRole.retailer
          ? _shopNameController.text
          : null,
      email: _emailController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      about: _aboutController.text,
      profilePicture: _profilePicturePath,
      location: _selectedLocation,
    );
    Navigator.pop(context, updated);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRetailer = widget.role == AppUserRole.retailer;
    final bool isCustomer = widget.role == AppUserRole.customer;
    const themeColor = Color(0xFF6C9985);

    const fieldTextStyle = TextStyle(fontSize: 14);
    const fieldLabelStyle = TextStyle(fontSize: 14);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      appBar: AppBar(
        title: Text(
          isRetailer ? "Edit Shop Profile" : "Edit Profile",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E392A),
          ),
        ),
        backgroundColor: const Color(0xFFF7FBF7),
        foregroundColor: const Color(0xFF1E392A),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isCustomer) ...[
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            _profilePicturePath != null &&
                                _profilePicturePath!.isNotEmpty
                            ? FileImage(File(_profilePicturePath!))
                            : null,
                        child:
                            _profilePicturePath == null ||
                                _profilePicturePath!.isEmpty
                            ? Icon(
                                isRetailer
                                    ? Icons.storefront_rounded
                                    : Icons.design_services_rounded,
                                size: 46,
                                color: Colors.grey.shade600,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: const CircleAvatar(
                            radius: 16,
                            backgroundColor: themeColor,
                            child: Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (isRetailer) ...[
                TextField(
                  controller: _shopNameController,
                  style: fieldTextStyle,
                  decoration: const InputDecoration(
                    labelText: "Shop Name",
                    labelStyle: fieldLabelStyle,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storefront_rounded),
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                TextField(
                  controller: _nameController,
                  style: fieldTextStyle,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    labelStyle: fieldLabelStyle,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _emailController,
                style: fieldTextStyle,
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: fieldLabelStyle,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneController,
                style: fieldTextStyle,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  labelStyle: fieldLabelStyle,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _addressController,
                style: fieldTextStyle,
                decoration: const InputDecoration(
                  labelText: "Address",
                  labelStyle: fieldLabelStyle,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              // Location pinpoint — shown for ALL roles, and REQUIRED.
              // For customers this doubles as their delivery location
              // (used later for rule-based delivery charge calc), so it
              // cannot be left unset.
              Row(
                children: [
                  Text(
                    isCustomer
                        ? 'Delivery location'
                        : 'Shop / workspace location',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '*',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickLocation,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _locationError ? Colors.red : Colors.black26,
                      width: _locationError ? 1.4 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _locationError
                        ? Colors.red.withOpacity(0.03)
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pin_drop_outlined,
                        color: _locationError ? Colors.red : themeColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedLocation != null
                              ? 'Pinned: ${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                                    '${_selectedLocation!.longitude.toStringAsFixed(5)}'
                              : (isCustomer
                                    ? 'Tap to pin your delivery location'
                                    : 'Tap to pin your shop/workspace location'),
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedLocation != null
                                ? Colors.black87
                                : (_locationError
                                      ? Colors.red.shade700
                                      : Colors.black45),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _locationError
                            ? Colors.red.shade200
                            : Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
              if (_locationError) ...[
                const SizedBox(height: 6),
                const Text(
                  'This field is required — please pin a location.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
              if (!isCustomer) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _aboutController,
                  style: fieldTextStyle,
                  decoration: const InputDecoration(
                    labelText: "About / Biography",
                    labelStyle: fieldLabelStyle,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  maxLines: 3,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
