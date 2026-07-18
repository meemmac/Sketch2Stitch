import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/customer/virtual_trial_screen.dart';
import '../screens/retailer/inventory_screen.dart';
import '../screens/retailer/orders_screen.dart';
import '../screens/customer/measurement_screen.dart';
import '../models/measurement.dart';
import '../screens/shared/welcome_screen.dart';
import '../screens/shared/about_us_screen.dart';


/// Enum representing the three user roles.
enum AppUserRole {
  customer,
  tailor,
  retailer,
}

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

  const DrawerProfileData({
    required this.name,
    this.shopName = '',
    required this.email,
    required this.phone,
    required this.address,
    this.rating = 0.0,
    this.profilePicture,
    this.about = '',
  });

  DrawerProfileData copyWith({
    String? name,
    String? shopName,
    String? email,
    String? phone,
    String? address,
    double? rating,
    String? profilePicture,
    String? about,
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
    );
  }
}

/// The main reusable Dashboard Drawer widget.
class DashboardDrawer extends StatefulWidget {
  final AppUserRole initialRole;
  final ValueChanged<AppUserRole>? onRoleChanged;

  const DashboardDrawer({
    super.key,
    this.initialRole = AppUserRole.customer,
    this.onRoleChanged,
  });

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
      about: "Bespoke traditional and modern wear expert with over 15 years of experience in custom tailoring.",
    );

    _retailerProfile = const DrawerProfileData(
      name: "Alim Rahman",
      shopName: "Elegant Fabrics Ltd.",
      email: "contact@elegantfabrics.com",
      phone: "+880 1234567890",
      address: "Shop 12, Banani Super Market, Dhaka",
      rating: 4.6,
      about: "Premium local and imported fabric supplier specializing in silk, cotton, and wedding collections.",
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
    const themeColor = Color(0xFF6C9985); // Sage theme color matching AI Test Screen

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
            // Optional role toggle for testability
            _buildRoleToggle(),
            const Divider(height: 1),

            // Profile Section
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: DrawerProfileSection(
                      role: _currentRole,
                      profile: _activeProfile,
                      themeColor: themeColor,
                      onEditPressed: () => _showEditDialog(context),
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
                              await Future.delayed(const Duration(milliseconds: 500));
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
                              const SnackBar(content: Text("Logged out successfully!")),
                            );
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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

  Widget _buildRoleToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Demo Role:",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          DropdownButton<AppUserRole>(
            value: _currentRole,
            underline: const SizedBox(),
            style: const TextStyle(
              fontSize: 13,
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
                if (widget.onRoleChanged != null) {
                  widget.onRoleChanged!(role);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return ProfileEditDialog(
          role: _currentRole,
          initialProfile: _activeProfile,
          onSave: (updatedProfile) {
            _updateProfile(updatedProfile);
          },
        );
      },
    );
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
                backgroundImage: profile.profilePicture != null && profile.profilePicture!.isNotEmpty
                    ? FileImage(File(profile.profilePicture!))
                    : null,
                child: profile.profilePicture != null && profile.profilePicture!.isNotEmpty
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
                      role == AppUserRole.retailer ? profile.shopName : profile.name,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          if (!isCustomer && profile.about != null && profile.about!.isNotEmpty) ...[
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
                  MaterialPageRoute(
                    builder: (_) => const VirtualTrialScreen(),
                  ),
                );
              } else if (role == AppUserRole.retailer &&
                  item['title'] == 'Orders') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RetailerOrdersScreen(),
                  ),
                );
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
              } else if (item['title'] == 'Inventory') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InventoryScreen(),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
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
              const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 18),
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

  const DrawerLogoutButton({
    super.key,
    required this.onLogoutPressed,
  });

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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog widget for editing profile info.
class ProfileEditDialog extends StatefulWidget {
  final AppUserRole role;
  final DrawerProfileData initialProfile;
  final ValueChanged<DrawerProfileData> onSave;

  const ProfileEditDialog({
    super.key,
    required this.role,
    required this.initialProfile,
    required this.onSave,
  });

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _shopNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _aboutController;

  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _shopNameController = TextEditingController(text: widget.initialProfile.shopName);
    _emailController = TextEditingController(text: widget.initialProfile.email);
    _phoneController = TextEditingController(text: widget.initialProfile.phone);
    _addressController = TextEditingController(text: widget.initialProfile.address);
    _aboutController = TextEditingController(text: widget.initialProfile.about ?? '');
    _profilePicturePath = widget.initialProfile.profilePicture;
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

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        isRetailer ? "Edit Shop Profile" : "Edit Profile",
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E392A),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCustomer) ...[
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _profilePicturePath != null && _profilePicturePath!.isNotEmpty
                          ? FileImage(File(_profilePicturePath!))
                          : null,
                      child: _profilePicturePath == null || _profilePicturePath!.isEmpty
                          ? Icon(
                              isRetailer ? Icons.storefront_rounded : Icons.design_services_rounded,
                              size: 40,
                              color: Colors.grey.shade600,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF6C9985),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isRetailer) ...[
              TextField(
                controller: _shopNameController,
                decoration: const InputDecoration(
                  labelText: "Shop Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Phone",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: "Address",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
            if (!isCustomer) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _aboutController,
                decoration: const InputDecoration(
                  labelText: "About / Biography",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C9985),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final updated = widget.initialProfile.copyWith(
              name: _nameController.text,
              shopName: isRetailer ? _shopNameController.text : null,
              email: _emailController.text,
              phone: _phoneController.text,
              address: _addressController.text,
              about: _aboutController.text,
              profilePicture: _profilePicturePath,
            );
            widget.onSave(updated);
            Navigator.pop(context);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
