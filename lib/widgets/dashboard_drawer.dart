import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/auth_service.dart';
import 'package:sketch2stitch/services/user_session.dart';
import 'package:sketch2stitch/services/cloudinary_service.dart';
import 'package:sketch2stitch/widgets/cloudinary_image.dart';
import '../screens/customer/virtual_trial_screen.dart';
import '../screens/retailer/inventory_screen.dart';
import '../screens/retailer/orders_screen.dart';
import '../screens/customer/measurement_page.dart';
import '../screens/shared/welcome_screen.dart';
import '../screens/shared/change_password_screen.dart';
import '../screens/shared/location_picker_screen.dart';
import '../screens/tailor/portfolio_screen.dart';
import '../screens/tailor/orders_screen.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/orders/order_detail_screen.dart';
import '../screens/customer/messaging/conversations_screen.dart';
import '../utils/validation_utils.dart';
import 'top_feedback_banner.dart';

/// Placeholder avatar showing the first letter of [name] on a tinted
/// background — used wherever no profile picture has been set yet.
Widget _initialAvatar(String name, Color themeColor, {double fontSize = 22}) {
  final trimmed = name.trim();
  final letter = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  return Container(
    color: themeColor.withValues(alpha: 0.15),
    alignment: Alignment.center,
    child: Text(
      letter,
      style: TextStyle(
        color: themeColor,
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
      ),
    ),
  );
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
    bool removeProfilePicture = false, // NEW
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
      profilePicture: removeProfilePicture
          ? null
          : (profilePicture ?? this.profilePicture),
      about: about ?? this.about,
      location: location ?? this.location,
    );
  }
}

/// The main reusable Dashboard Drawer widget.
class DashboardDrawer extends StatefulWidget {
  final UserRole initialRole;

  const DashboardDrawer({super.key, required this.initialRole});

  @override
  State<DashboardDrawer> createState() => _DashboardDrawerState();
}

class _DashboardDrawerState extends State<DashboardDrawer> {
  late UserRole _currentRole;

  // Top feedback banner state — replaces bottom SnackBars so messages read
  // consistently with the registration flow.
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _feedbackMessage = null);
    });
  }

  // Reads from UserSession first (captured once, right when the session
  // started) — falls back to AuthService directly just in case.
  String? get _customerId =>
      UserSession.instance.uid ?? AuthService().currentUser?.uid;

  void _updateProfile(DrawerProfileData updated) {
    // Persist to Firestore first; only reflect it in the UI once the
    // write actually succeeds. Previously this just set the ValueNotifier
    // with no backend call at all, so edits were lost on app restart.
    unawaited(_saveProfile(updated));
  }

  Future<void> _saveProfile(DrawerProfileData updated) async {
    final uid = UserSession.instance.uid ?? AuthService().currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        _showFeedback('Could not save — please sign in again.', isError: true);
      }
      return;
    }

    try {
      await AuthService().updateProfile(uid, _currentRole, {
        'name': updated.name,
        if (_currentRole == UserRole.retailer) 'shopName': updated.shopName,
        // 'email' is deliberately not written — it's the login identity and
        // is read-only in the profile editor.
        'phone': updated.phone,
        'address': updated.address,
        if (_currentRole != UserRole.customer) 'about': updated.about,
        'profilePicture': updated.profilePicture ?? '',
        if (updated.location != null) 'location': updated.location,
      });

      UserSession.instance.currentProfile.value = updated;

      if (mounted) {
        _showFeedback('Profile updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showFeedback('Failed to save profile: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF6C9985);

    return ValueListenableBuilder<DrawerProfileData?>(
      valueListenable: UserSession.instance.currentProfile,
      builder: (context, profile, _) {
        if (profile == null)
          return const Drawer(
            child: Center(child: CircularProgressIndicator()),
          );

        return Stack(
          children: [
            Drawer(
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
                              profile: profile,
                              themeColor: themeColor,
                              onEditPressed: () =>
                                  _openEditScreen(context, profile),
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
                                    customerId: _customerId,
                                    onFeedback: _showFeedback,
                                  ),
                                ),
                                const Divider(height: 1),

                                // Logout Section
                                DrawerLogoutButton(
                                  onLogoutPressed: () async {
                                    await AuthService().signOut();
                                    UserSession.instance.logout();

                                    if (!mounted) return;
                                    // Overlay banner so it survives the
                                    // navigation to the welcome screen.
                                    AppFeedback.show(
                                      context,
                                      "Logged out successfully!",
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
            ),
            if (_feedbackMessage != null)
              TopFeedbackBanner(
                message: _feedbackMessage!,
                isError: _feedbackIsError,
                onClose: () => setState(() => _feedbackMessage = null),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openEditScreen(
    BuildContext context,
    DrawerProfileData currentProfile,
  ) async {
    // Close the drawer first
    Navigator.pop(context);

    final updatedProfile = await Navigator.push<DrawerProfileData>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          role: _currentRole,
          initialProfile: currentProfile,
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
  final UserRole role;
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
    final bool isCustomer = role == UserRole.customer;

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
                child: ClipOval(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _buildDrawerAvatar(themeColor),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role == UserRole.retailer
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

  /// Renders the drawer avatar: a Cloudinary-hosted image if `profilePicture`
  /// is a URL, a local file if it's a not-yet-uploaded path, or the first
  /// letter of the user's (or shop's) name if there's no picture at all.
  Widget _buildDrawerAvatar(Color themeColor) {
    final pic = profile.profilePicture;
    if (pic == null || pic.isEmpty) {
      final displayName = role == UserRole.retailer
          ? profile.shopName
          : profile.name;
      return _initialAvatar(displayName, themeColor);
    }
    if (pic.startsWith('http')) {
      return CloudinaryImage(
        imageUrl: pic,
        fit: BoxFit.cover,
        widthParam: 112,
        heightParam: 112,
      );
    }
    return Image.file(File(pic), fit: BoxFit.cover);
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
  final UserRole role;
  final Color themeColor;
  final String? customerId;
  final void Function(String message, {bool isError}) onFeedback;

  const DrawerNavigationSection({
    super.key,
    required this.role,
    required this.themeColor,
    required this.onFeedback,
    this.customerId,
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
                if (role == UserRole.retailer) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RetailerOrdersScreen(),
                    ),
                  );
                } else if (role == UserRole.customer) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderDetailScreen(),
                    ),
                  );
                } else if (role == UserRole.tailor) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TailorOrdersScreen(),
                    ),
                  );
                }
              } else if (item['title'] == 'Measurements') {
                if (customerId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MeasurementPage(customerId: customerId!),
                    ),
                  );
                } else {
                  onFeedback(
                    'Please sign in to view measurements.',
                    isError: true,
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
              } else if (item['title'] == 'Messages') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConversationsScreen(
                      customerId: 'current_customer_id',
                      currentUserRole: role,
                    ),
                  ),
                );
              } else {
                onFeedback("Navigation trigger: ${item['title']}");
              }
            },
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _getNavigationItems() {
    switch (role) {
      case UserRole.customer:
        return [
          {'title': 'Virtual Trial', 'icon': Icons.auto_awesome_rounded},
          {'title': 'Measurements', 'icon': Icons.straighten_rounded},
          {'title': 'Cart', 'icon': Icons.shopping_bag_outlined},
          {'title': 'Messages', 'icon': Icons.chat_bubble_outline_rounded},
          {'title': 'Orders', 'icon': Icons.receipt_long_rounded},
        ];
      case UserRole.tailor:
        return [
          {'title': 'Orders', 'icon': Icons.receipt_long_rounded},
          {'title': 'Portfolio', 'icon': Icons.design_services_outlined},
          {'title': 'Messages', 'icon': Icons.chat_bubble_outline_rounded},
        ];
      case UserRole.retailer:
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
  final UserRole role;
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
  bool _isUploadingPhoto = false;

  // Top feedback banner state — replaces bottom SnackBars so messages read
  // consistently with the registration flow.
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  Timer? _feedbackTimer;

  bool _pictureRemoved = false;

  void _removePicture() {
    setState(() {
      _profilePicturePath = null;
      _pictureRemoved = true;
    });
  }

  void _showFeedback(String message, {bool isError = false}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _feedbackMessage = null);
    });
  }

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
    _selectedLocation =
        widget.initialProfile.location ??
        const GeoPoint(23.8103, 90.4125); // dummy Dhaka coordinates for now
  }

  Future<void> _pickImage() async {
    final cloudinary = CloudinaryService();
    final file = await cloudinary.pickImageFromGallery();
    if (file == null) return;

    setState(() {
      _profilePicturePath = file.path; // local preview while it uploads
      _isUploadingPhoto = true;
    });

    final url = await cloudinary.uploadImage(
      file,
      folder: 'profiles/${widget.role.name}',
    );

    if (!mounted) return;
    setState(() {
      _isUploadingPhoto = false;
      if (url != null) {
        _profilePicturePath = url;
        _pictureRemoved = false;
      } else {
        _showFeedback(
          'Failed to upload photo. Please try again.',
          isError: true,
        );
      }
    });
  }

  /// Renders the current avatar selection: a Cloudinary-hosted image once
  /// uploaded, a local file preview while the upload is in flight, or the
  /// first letter of the user's (or shop's) name if nothing has been
  /// picked yet.
  Widget _buildAvatarPreview() {
    final pic = _profilePicturePath;
    if (pic == null || pic.isEmpty) {
      final displayName = widget.role == UserRole.retailer
          ? _shopNameController.text
          : _nameController.text;
      return _initialAvatar(displayName, const Color(0xFF6C9985), fontSize: 36);
    }
    if (pic.startsWith('http')) {
      return CloudinaryImage(
        imageUrl: pic,
        fit: BoxFit.cover,
        widthParam: 200,
        heightParam: 200,
      );
    }
    return Image.file(
      File(pic),
      fit: BoxFit.cover,
    ); // not-yet-uploaded local pick
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

  Future<void> _openChangePassword() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
    if (changed == true && mounted) {
      _showFeedback('Password updated successfully.');
    }
  }

  void _save() {
    final isRetailer = widget.role == UserRole.retailer;
    final displayName = isRetailer
        ? _shopNameController.text.trim()
        : _nameController.text.trim();

    if (displayName.isEmpty) {
      _showFeedback(
        isRetailer ? 'Please enter your shop name.' : 'Please enter your name.',
        isError: true,
      );
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !ValidationUtils.isValidPhone(phone)) {
      _showFeedback('Please enter a valid phone number.', isError: true);
      return;
    }

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showFeedback(
        isRetailer
            ? 'Please enter your shop address.'
            : 'Please enter your address.',
        isError: true,
      );
      return;
    }

    if (_selectedLocation == null) {
      setState(() => _locationError = true);
      _showFeedback('Please pin your location before saving.', isError: true);
      return;
    }

    final updated = widget.initialProfile.copyWith(
      name: _nameController.text.trim(),
      shopName: isRetailer ? _shopNameController.text.trim() : null,
      phone: phone,
      address: address,
      about: _aboutController.text.trim(),
      profilePicture: _profilePicturePath,
      removeProfilePicture: _pictureRemoved, // NEW
      location: _selectedLocation,
    );
    Navigator.pop(context, updated);
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
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
    final bool isRetailer = widget.role == UserRole.retailer;
    final bool isCustomer = widget.role == UserRole.customer;
    const themeColor = Color(0xFF6C9985);

    return Stack(
      children: [
        _buildScaffold(isRetailer, isCustomer, themeColor),
        if (_feedbackMessage != null)
          TopFeedbackBanner(
            message: _feedbackMessage!,
            isError: _feedbackIsError,
            onClose: () => setState(() => _feedbackMessage = null),
          ),
      ],
    );
  }

  Widget _buildScaffold(bool isRetailer, bool isCustomer, Color themeColor) {
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
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            // NEW — whole avatar tappable
                            onTap: _isUploadingPhoto ? null : _pickImage,
                            child: ClipOval(
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: _buildAvatarPreview(),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingPhoto ? null : _pickImage,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: themeColor,
                                child: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_profilePicturePath != null &&
                          _profilePicturePath!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _isUploadingPhoto ? null : _removePicture,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text(
                            'Remove photo',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (isRetailer) ...[
                TextField(
                  controller: _shopNameController,
                  style: fieldTextStyle,
                  decoration: InputDecoration(
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
                  decoration: InputDecoration(
                    labelText: "Name",
                    labelStyle: fieldLabelStyle,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // Email is the account's login identity — it is shown for
              // reference but cannot be edited here.
              TextField(
                controller: _emailController,
                style: fieldTextStyle.copyWith(color: Colors.black54),
                readOnly: true,
                enableInteractiveSelection: false,
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: fieldLabelStyle,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: Colors.black26,
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.03),
                  helperText: "Your login email can't be changed.",
                  helperStyle: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneController,
                style: fieldTextStyle,
                decoration: InputDecoration(
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
                decoration: InputDecoration(
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
                  decoration: InputDecoration(
                    labelText: "About / Biography",
                    labelStyle: fieldLabelStyle,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                "Security",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _openChangePassword,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: themeColor),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Change password',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
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
