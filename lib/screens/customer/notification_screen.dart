import 'package:flutter/material.dart';
import 'package:sketch2stitch/widgets/dashboard_drawer.dart';

// ============= CUSTOMER NOTIFICATION =============
enum NotificationType { confirmed, delivered, cancelled, paymentDue }

class AppNotification {
  final NotificationType type;
  final String avatarImage;
  final String itemName;
  final String partyLabel;
  final String partyName;
  final String orderId;
  final String timeAgo;
  final bool isNew;
  final String? cancelReason;

  const AppNotification({
    required this.type,
    required this.avatarImage,
    required this.itemName,
    required this.partyLabel,
    required this.partyName,
    required this.orderId,
    required this.timeAgo,
    this.isNew = false,
    this.cancelReason,
  });
}

final List<AppNotification> kCustomerDummyNotifications = [
  const AppNotification(
    type: NotificationType.confirmed,
    avatarImage: 'assets/images/fab.jpg',
    itemName: 'Salwar Kameez',
    partyLabel: 'confirmed by',
    partyName: 'Rahman Tailors',
    orderId: 'OR01',
    timeAgo: '2 hours ago',
    isNew: true,
  ),
  const AppNotification(
    type: NotificationType.paymentDue,
    avatarImage: 'assets/images/fab2.jpg',
    itemName: 'Bridal Lehenga',
    partyLabel: 'is due for',
    partyName: 'Noor Fashion House',
    orderId: 'OR02',
    timeAgo: '5 hours ago',
    isNew: true,
  ),
  const AppNotification(
    type: NotificationType.delivered,
    avatarImage: 'assets/images/textile.jpg',
    itemName: 'Premium Cotton Fabric',
    partyLabel: 'from',
    partyName: 'Style Fabric House',
    orderId: 'OR03',
    timeAgo: 'Today',
    isNew: true,
  ),
  const AppNotification(
    type: NotificationType.cancelled,
    avatarImage: 'assets/images/lace.jpg',
    itemName: 'Wedding Sherwani',
    partyLabel: 'from',
    partyName: 'Elegant Shop',
    orderId: 'OR04',
    timeAgo: 'Yesterday',
    cancelReason: 'The fabric you selected went out of stock before your order could be processed.',
  ),
  const AppNotification(
    type: NotificationType.delivered,
    avatarImage: 'assets/images/silk.jpg',
    itemName: 'Casual Shirt',
    partyLabel: 'from',
    partyName: 'Modern Tailor House',
    orderId: 'OR06',
    timeAgo: '5 days ago',
  ),
];

// ============= RETAILER NOTIFICATION =============
enum RetailerNotificationType { orderPlaced, stockOut, newReview }

class RetailerNotification {
  final RetailerNotificationType type;
  final String avatarImage;
  final String customerName;
  final String itemName;
  final String orderId;
  final String timeAgo;
  final bool isNew;
  final String? colorName;
  final String? reviewText;
  final double? rating;
  final String? customerImage;

  const RetailerNotification({
    required this.type,
    required this.avatarImage,
    required this.customerName,
    required this.itemName,
    required this.orderId,
    required this.timeAgo,
    this.isNew = false,
    this.colorName,
    this.reviewText,
    this.rating,
    this.customerImage,
  });
}

final List<RetailerNotification> kRetailerDummyNotifications = [
  const RetailerNotification(
    type: RetailerNotificationType.orderPlaced,
    avatarImage: 'assets/images/fab.jpg',
    customerName: 'Sarah Ahmed',
    itemName: 'Salwar Kameez',
    orderId: 'OR001',
    timeAgo: '2 hours ago',
    isNew: true,
  ),
  const RetailerNotification(
    type: RetailerNotificationType.orderPlaced,
    avatarImage: 'assets/images/fab2.jpg',
    customerName: 'Fatima Khan',
    itemName: 'Bridal Lehenga',
    orderId: 'OR002',
    timeAgo: '3 hours ago',
    isNew: true,
  ),
  const RetailerNotification(
    type: RetailerNotificationType.stockOut,
    avatarImage: 'assets/images/textile.jpg',
    customerName: 'Premium Cotton Fabric',
    itemName: 'Premium Cotton Fabric',
    orderId: 'PROD003',
    timeAgo: '5 hours ago',
    isNew: true,
    colorName: 'White',
  ),
  const RetailerNotification(
    type: RetailerNotificationType.newReview,
    avatarImage: 'assets/images/lace.jpg',
    customerName: 'Aisha Rahman',
    itemName: 'Wedding Sherwani',
    orderId: 'OR005',
    timeAgo: '2 days ago',
    rating: 4.5,
    reviewText: 'Excellent quality and timely delivery!',
    customerImage: 'assets/images/fab.jpg',
  ),
];

// ============= TAILOR NOTIFICATION =============
enum TailorNotificationType { newOrder, orderConfirmationReminder, deliveryDeadline, newReview }

class TailorNotification {
  final TailorNotificationType type;
  final String avatarImage;
  final String customerName;
  final String itemName;
  final String orderId;
  final String timeAgo;
  final bool isNew;
  final String? reviewText;
  final double? rating;
  final String? customerImage;
  final String? deadlineDate;

  const TailorNotification({
    required this.type,
    required this.avatarImage,
    required this.customerName,
    required this.itemName,
    required this.orderId,
    required this.timeAgo,
    this.isNew = false,
    this.reviewText,
    this.rating,
    this.customerImage,
    this.deadlineDate,
  });
}

final List<TailorNotification> kTailorDummyNotifications = [
  const TailorNotification(
    type: TailorNotificationType.newOrder,
    avatarImage: 'assets/images/fab.jpg',
    customerName: 'Sarah Ahmed',
    itemName: 'Salwar Kameez',
    orderId: 'OR001',
    timeAgo: '2 hours ago',
    isNew: true,
  ),
  const TailorNotification(
    type: TailorNotificationType.orderConfirmationReminder,
    avatarImage: 'assets/images/lace.jpg',
    customerName: 'Aisha Rahman',
    itemName: 'Wedding Sherwani',
    orderId: 'OR003',
    timeAgo: '1 day ago',
  ),
  const TailorNotification(
    type: TailorNotificationType.deliveryDeadline,
    avatarImage: 'assets/images/textile.jpg',
    customerName: 'Zara Malik',
    itemName: 'Premium Suit',
    orderId: 'OR005',
    timeAgo: '5 hours ago',
    isNew: true,
    deadlineDate: '2026-07-20',
  ),
  const TailorNotification(
    type: TailorNotificationType.newReview,
    avatarImage: 'assets/images/fab.jpg',
    customerName: 'Hassan Raza',
    itemName: 'Traditional Kurta',
    orderId: 'OR007',
    timeAgo: '3 days ago',
    rating: 4.5,
    reviewText: 'Excellent stitching and timely delivery!',
    customerImage: 'assets/images/fab.jpg',
  ),
];

// ============= UNIFIED NOTIFICATION SCREEN =============
class UnifiedNotificationScreen extends StatefulWidget {
  final AppUserRole role;

  const UnifiedNotificationScreen({
    super.key,
    required this.role,
  });

  @override
  State<UnifiedNotificationScreen> createState() => _UnifiedNotificationScreenState();
}

class _UnifiedNotificationScreenState extends State<UnifiedNotificationScreen> {
  late List<AppNotification> _customerNotifications;
  late List<RetailerNotification> _retailerNotifications;
  late List<TailorNotification> _tailorNotifications;

  @override
  void initState() {
    super.initState();
    _customerNotifications = List.of(kCustomerDummyNotifications);
    _retailerNotifications = List.of(kRetailerDummyNotifications);
    _tailorNotifications = List.of(kTailorDummyNotifications);
  }

  void _clearAll() {
    setState(() {
      switch (widget.role) {
        case AppUserRole.customer:
          _customerNotifications.clear();
          break;
        case AppUserRole.tailor:
          _tailorNotifications.clear();
          break;
        case AppUserRole.retailer:
          _retailerNotifications.clear();
          break;
      }
    });
  }

  void _goBack() {
    Navigator.pop(context, false);
  }

  int get _notificationCount {
    switch (widget.role) {
      case AppUserRole.customer:
        return _customerNotifications.length;
      case AppUserRole.tailor:
        return _tailorNotifications.length;
      case AppUserRole.retailer:
        return _retailerNotifications.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6FAF6),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _notificationCount == 0
                    ? _buildEmptyState()
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: _notificationCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _buildNotificationCard(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    switch (widget.role) {
      case AppUserRole.customer:
        title = 'Notifications';
        break;
      case AppUserRole.tailor:
        title = 'Tailor Notifications';
        break;
      case AppUserRole.retailer:
        title = 'Retailer Notifications';
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade200, Colors.green.shade50],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 26),
                    const SizedBox(width: 10),
                    Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _goBack,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                child: const Text('Back', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _notificationCount == 0 ? null : _clearAll,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF16332A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: const Text('clear all', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text("You're all caught up", style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16332A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildNotificationCard(int index) {
    switch (widget.role) {
      case AppUserRole.customer:
        return _buildCustomerCard(_customerNotifications[index]);
      case AppUserRole.tailor:
        return _buildTailorCard(_tailorNotifications[index]);
      case AppUserRole.retailer:
        return _buildRetailerCard(_retailerNotifications[index]);
    }
  }

  // ============= CUSTOMER CARD =============
  Widget _buildCustomerCard(AppNotification n) {
    final style = _customerStyleFor(n.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 22, backgroundColor: Colors.white, backgroundImage: AssetImage(n.avatarImage)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 18, color: style.iconColor),
                        const SizedBox(width: 6),
                        Expanded(child: Text(style.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                        if (n.isNew) _buildNewBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.75), height: 1.4),
                        children: [
                          TextSpan(text: '${style.messagePrefix} '),
                          TextSpan(text: n.itemName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          TextSpan(text: ' ${n.partyLabel} '),
                          TextSpan(text: n.partyName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          if (style.messageSuffix.isNotEmpty) TextSpan(text: style.messageSuffix),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (n.type == NotificationType.cancelled) _buildCustomerCancelRow(n) else _buildCustomerFooterRow(n),
          if (n.type == NotificationType.delivered)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Please review from orders', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerCancelRow(AppNotification n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Order ID: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => _showCustomerCancelReason(n),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('View Reason', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87)),
            ),
            const SizedBox(width: 10),
            Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withOpacity(0.45)),
            const SizedBox(width: 4),
            Text(n.timeAgo, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerFooterRow(AppNotification n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Order ID: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withOpacity(0.45)),
            const SizedBox(width: 4),
            Text(n.timeAgo, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
          ],
        ),
      ],
    );
  }

  void _showCustomerCancelReason(AppNotification n) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cancellation Reason', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7D6D6).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF7D6D6).withOpacity(0.5)),
                ),
                child: Text(n.cancelReason ?? 'No reason was provided.', style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black.withOpacity(0.8))),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CustomerNotificationStyle _customerStyleFor(NotificationType type) {
    switch (type) {
      case NotificationType.confirmed:
        return _CustomerNotificationStyle(background: const Color(0xFFCDEFD3), icon: Icons.check_circle_rounded, iconColor: Colors.green.shade800, title: 'Order Confirmed', messagePrefix: 'Your order for', messageSuffix: ' has been confirmed.');
      case NotificationType.delivered:
        return _CustomerNotificationStyle(background: const Color(0xFFD3E9F7), icon: Icons.local_shipping_rounded, iconColor: Colors.blue.shade700, title: 'Order Delivered', messagePrefix: 'Your order for', messageSuffix: ' has been delivered.');
      case NotificationType.cancelled:
        return _CustomerNotificationStyle(background: const Color(0xFFF7D6D6), icon: Icons.cancel_rounded, iconColor: Colors.red.shade700, title: 'Order Cancelled', messagePrefix: 'Your order for', messageSuffix: ' was cancelled.');
      case NotificationType.paymentDue:
        return _CustomerNotificationStyle(background: const Color(0xFFFBE7C0), icon: Icons.payments_rounded, iconColor: Colors.orange.shade800, title: 'Payment Deadline Approaching', messagePrefix: 'Payment for', messageSuffix: '.');
    }
  }

  // ============= RETAILER CARD =============
  Widget _buildRetailerCard(RetailerNotification n) {
    final style = _retailerStyleFor(n.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 22, backgroundColor: Colors.white, backgroundImage: AssetImage(n.avatarImage)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 18, color: style.iconColor),
                        const SizedBox(width: 6),
                        Expanded(child: Text(style.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                        if (n.isNew) _buildNewBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.75), height: 1.4),
                        children: [
                          TextSpan(text: style.messagePrefix),
                          TextSpan(text: n.customerName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          TextSpan(text: style.messageMiddle),
                          if (n.colorName != null) ...[
                            TextSpan(text: ' (Color: '),
                            TextSpan(text: n.colorName!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                            TextSpan(text: ')'),
                          ],
                          if (style.messageSuffix.isNotEmpty) TextSpan(text: style.messageSuffix),
                          if (n.type == RetailerNotificationType.orderPlaced) ...[
                            TextSpan(text: ' ',),
                            TextSpan(text: 'View Order Details', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRetailerFooter(n),
        ],
      ),
    );
  }

  Widget _buildRetailerFooter(RetailerNotification n) {
    if (n.type == RetailerNotificationType.newReview) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Order ID: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _showRetailerReviewDetails(n),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('View Review', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
              ),
              const SizedBox(width: 10),
              Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withOpacity(0.45)),
              const SizedBox(width: 4),
              Text(n.timeAgo, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('${n.type == RetailerNotificationType.stockOut ? 'Product' : 'Order'} ID: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withOpacity(0.45)),
            const SizedBox(width: 4),
            Text(n.timeAgo, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
          ],
        ),
      ],
    );
  }

  void _showRetailerReviewDetails(RetailerNotification n) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Customer Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(radius: 30, backgroundImage: AssetImage(n.customerImage ?? 'assets/images/fab.jpg')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: List.generate(5, (index) {
                  int roundedRating = (n.rating ?? 0).round();
                  return Icon(index < roundedRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 28);
                }),
              ),
              const SizedBox(height: 4),
              Text('${n.rating?.toStringAsFixed(1) ?? '0'} / 5.0', style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6))),
              if (n.reviewText != null && n.reviewText!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text('Feedback:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.8))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(n.reviewText!, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.black.withOpacity(0.8))),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _RetailerNotificationStyle _retailerStyleFor(RetailerNotificationType type) {
    switch (type) {
      case RetailerNotificationType.orderPlaced:
        return _RetailerNotificationStyle(background: const Color(0xFFCDEFD3), icon: Icons.shopping_cart_rounded, iconColor: Colors.green.shade800, title: 'New Order Placed', messagePrefix: '', messageMiddle: ' placed an order for ', messageSuffix: '. ');
      case RetailerNotificationType.stockOut:
        return _RetailerNotificationStyle(background: const Color(0xFFF7D6D6), icon: Icons.warning_rounded, iconColor: Colors.red.shade700, title: 'Stock Alert', messagePrefix: '', messageMiddle: ' is out of stock for ', messageSuffix: '.');
      case RetailerNotificationType.newReview:
        return _RetailerNotificationStyle(background: const Color(0xFFD3E9F7), icon: Icons.star_rate_rounded, iconColor: Colors.blue.shade800, title: 'New Review', messagePrefix: '', messageMiddle: ' left a new review. ', messageSuffix: '');
    }
  }

  // ============= TAILOR CARD =============
  Widget _buildTailorCard(TailorNotification n) {
    final style = _tailorStyleFor(n.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 22, backgroundColor: Colors.white, backgroundImage: AssetImage(n.avatarImage)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 18, color: style.iconColor),
                        const SizedBox(width: 6),
                        Expanded(child: Text(style.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                        if (n.isNew) _buildNewBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.75), height: 1.4),
                        children: [
                          TextSpan(text: style.messagePrefix),
                          TextSpan(text: n.customerName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          TextSpan(text: style.messageMiddle),
                          if (style.messageSuffix.isNotEmpty) TextSpan(text: style.messageSuffix),
                          if (n.type == TailorNotificationType.deliveryDeadline && n.deadlineDate != null) ...[
                            TextSpan(text: ' Deadline: ${n.deadlineDate}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                          if (n.type == TailorNotificationType.newOrder) ...[
                            TextSpan(text: ' ',),
                            TextSpan(text: 'View Order', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ],
                          if (n.type == TailorNotificationType.orderConfirmationReminder) ...[
                            TextSpan(text: ' ',),
                            TextSpan(text: 'Confirm Now', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTailorFooter(n),
        ],
      ),
    );
  }

  Widget _buildTailorFooter(TailorNotification n) {
    if (n.type == TailorNotificationType.newReview) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Order ID: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _showTailorReviewDetails(n),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('View Review', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
              ),
              const SizedBox(width: 10),
              Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withOpacity(0.45)),
              const SizedBox(width: 4),
              Text(n.timeAgo, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Order ID: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withOpacity(0.45)),
            const SizedBox(width: 4),
            Text(n.timeAgo, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
          ],
        ),
      ],
    );
  }

  void _showTailorReviewDetails(TailorNotification n) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Customer Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(radius: 30, backgroundImage: AssetImage(n.customerImage ?? 'assets/images/fab.jpg')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: List.generate(5, (index) {
                  int roundedRating = (n.rating ?? 0).round();
                  return Icon(index < roundedRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 28);
                }),
              ),
              const SizedBox(height: 4),
              Text('${n.rating?.toStringAsFixed(1) ?? '0'} / 5.0', style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6))),
              if (n.reviewText != null && n.reviewText!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text('Feedback:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.8))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(n.reviewText!, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.black.withOpacity(0.8))),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TailorNotificationStyle _tailorStyleFor(TailorNotificationType type) {
    switch (type) {
      case TailorNotificationType.newOrder:
        return _TailorNotificationStyle(background: const Color(0xFFCDEFD3), icon: Icons.shopping_cart_rounded, iconColor: Colors.green.shade800, title: 'New Order Received', messagePrefix: '', messageMiddle: ' placed a new order for ', messageSuffix: '.');
      case TailorNotificationType.orderConfirmationReminder:
        return _TailorNotificationStyle(background: const Color(0xFFF7D6D6), icon: Icons.warning_rounded, iconColor: Colors.red.shade700, title: 'Confirm Order', messagePrefix: '', messageMiddle: '\'s order for ', messageSuffix: ' will be cancelled if not confirmed.');
      case TailorNotificationType.deliveryDeadline:
        return _TailorNotificationStyle(background: const Color(0xFFFBE7C0), icon: Icons.timer_rounded, iconColor: Colors.orange.shade800, title: 'Delivery Deadline Approaching', messagePrefix: 'Order from ', messageMiddle: ' for ', messageSuffix: ' is approaching deadline.');
      case TailorNotificationType.newReview:
        return _TailorNotificationStyle(background: const Color(0xFFD3E9F7), icon: Icons.star_rate_rounded, iconColor: Colors.blue.shade700, title: 'New Review', messagePrefix: '', messageMiddle: ' left a new review. ', messageSuffix: '');
    }
  }
}

// ============= STYLE CLASSES =============
class _CustomerNotificationStyle {
  final Color background;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String messagePrefix;
  final String messageSuffix;

  const _CustomerNotificationStyle({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.messagePrefix,
    required this.messageSuffix,
  });
}

class _RetailerNotificationStyle {
  final Color background;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String messagePrefix;
  final String messageMiddle;
  final String messageSuffix;

  const _RetailerNotificationStyle({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.messagePrefix,
    required this.messageMiddle,
    required this.messageSuffix,
  });
}

class _TailorNotificationStyle {
  final Color background;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String messagePrefix;
  final String messageMiddle;
  final String messageSuffix;

  const _TailorNotificationStyle({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.messagePrefix,
    required this.messageMiddle,
    required this.messageSuffix,
  });
}