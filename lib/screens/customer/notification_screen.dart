import 'package:flutter/material.dart';

enum NotificationType { confirmed, delivered, cancelled, paymentDue }

class AppNotification {
  final NotificationType type;
  final String avatarImage;
  final String itemName;
  final String partyLabel; // e.g. "confirmed by", "from"
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

// TODO: replace with real notifications fetched for the signed-in user
// (e.g. Firestore `users/{uid}/notifications` ordered by timestamp).
final List<AppNotification> kDummyNotifications = [
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
    cancelReason: 'The fabric you selected went out of stock before your order '
        'could be processed. A full refund has been issued to your original '
        'payment method.',
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

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late List<AppNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = List.of(kDummyNotifications);
  }

  void _clearAll() {
    setState(() => _notifications.clear());
    // Let the home screen know there are no unread notifications left,
    // so it can hide the red badge on the bell icon
  }

  void _goBack() {
    // No clearing happened — tell the home screen nothing changed.
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6FAF6),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _buildCard(_notifications[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Header ----------------
  Widget _buildHeader() {
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
                    Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black87,  // Changed to match home page
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Notification',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                    ),
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
              onPressed: _notifications.isEmpty ? null : _clearAll,
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

  // ---------------- Notification card ----------------
  Widget _buildCard(AppNotification n) {
    final style = _styleFor(n.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage(n.avatarImage),
                onBackgroundImageError: (_, __) {},
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 18, color: style.iconColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            style.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
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
          // Add review message for delivered items
          if (n.type == NotificationType.delivered)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Please review from orders',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

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

  Widget _buildFooterRow(AppNotification n) {
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

  Widget _buildCancelRow(AppNotification n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Order ID: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => _showCancelReason(n),
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

  void _showCancelReason(AppNotification n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cancellation Reason', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              n.cancelReason ?? 'No reason was provided for this cancellation.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black.withOpacity(0.7)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NotificationStyle _styleFor(NotificationType type) {
    switch (type) {
      case NotificationType.confirmed:
        return _NotificationStyle(
          background: const Color(0xFFCDEFD3),
          icon: Icons.check_circle_rounded,
          iconColor: Colors.green.shade800,
          title: 'Order Confirmed',
          messagePrefix: 'Your order for',
          messageSuffix: ' has been confirmed.',
        );
      case NotificationType.delivered:
        return _NotificationStyle(
          background: const Color(0xFFD3E9F7),
          icon: Icons.local_shipping_rounded,
          iconColor: Colors.blue.shade700,
          title: 'Order Delivered',
          messagePrefix: 'Your order for',
          messageSuffix: ' has been delivered.',
        );
      case NotificationType.cancelled:
        return _NotificationStyle(
          background: const Color(0xFFF7D6D6),
          icon: Icons.cancel_rounded,
          iconColor: Colors.red.shade700,
          title: 'Order Cancelled',
          messagePrefix: 'Your order for',
          messageSuffix: ' was cancelled.',
        );
      case NotificationType.paymentDue:
        return _NotificationStyle(
          background: const Color(0xFFFBE7C0),
          icon: Icons.payments_rounded,
          iconColor: Colors.orange.shade800,
          title: 'Payment Deadline Approaching',
          messagePrefix: 'Payment for',
          messageSuffix: '.',
        );
    }
  }
}

class _NotificationStyle {
  final Color background;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String messagePrefix;
  final String messageSuffix;

  const _NotificationStyle({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.messagePrefix,
    required this.messageSuffix,
  });
}