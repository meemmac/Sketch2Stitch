import 'package:flutter/material.dart';

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

  const DrawerProfileData({
    required this.name,
    this.shopName = '',
    required this.email,
    required this.phone,
    required this.address,
    this.rating = 0.0,
  });

  DrawerProfileData copyWith({
    String? name,
    String? shopName,
    String? email,
    String? phone,
    String? address,
    double? rating,
  }) {
    return DrawerProfileData(
      name: name ?? this.name,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      rating: rating ?? this.rating,
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

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;

    // Initialize mock data
    _customerProfile = const DrawerProfileData(
      name: "Jane Doe",
      email: "jane.doe@example.com",
      phone: "+1 (555) 019-2834",
      address: "123 Creative Lane, New York, NY",
    );

    _tailorProfile = const DrawerProfileData(
      name: "Master Karim",
      email: "karim.tailors@example.com",
      phone: "+880 1712-345678",
      address: "Suite 4B, Concord Tower, Dhaka",
      rating: 4.8,
    );

    _retailerProfile = const DrawerProfileData(
      name: "Alim Rahman",
      shopName: "Elegant Fabrics Ltd.",
      email: "contact@elegantfabrics.com",
      phone: "+880 1911-876543",
      address: "Shop 12, Banani Super Market, Dhaka",
      rating: 4.6,
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
                            Navigator.pop(context);
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
                backgroundColor: themeColor.withOpacity(0.15),
                child: Icon(
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
                    if (role == AppUserRole.retailer)
                      Text(
                        "Owner: ${profile.name}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
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

          // Rating Row if Tailor or Retailer
          if (!isCustomer) ...[
            Row(
              children: [
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
          ],

          // Detailed Fields
          _buildInfoRow(Icons.email_outlined, profile.email),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone_outlined, profile.phone),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on_outlined, profile.address),
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

  const DrawerNavigationSection({
    super.key,
    required this.role,
    required this.themeColor,
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
              debugPrint("Navigation clicked: ${item['title']}");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Navigation trigger: ${item['title']}"),
                  duration: const Duration(seconds: 1),
                ),
              );
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
          {'title': 'Messages', 'icon': Icons.chat_bubble_outline_rounded},
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _shopNameController = TextEditingController(text: widget.initialProfile.shopName);
    _emailController = TextEditingController(text: widget.initialProfile.email);
    _phoneController = TextEditingController(text: widget.initialProfile.phone);
    _addressController = TextEditingController(text: widget.initialProfile.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRetailer = widget.role == AppUserRole.retailer;

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
            ],
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: isRetailer ? "Owner Name" : "Name",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 12),
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
