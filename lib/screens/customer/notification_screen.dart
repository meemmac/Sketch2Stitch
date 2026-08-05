import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/auth_service.dart';
import 'package:sketch2stitch/services/notification_service.dart';
import 'package:sketch2stitch/models/notification.dart';
import 'package:timeago/timeago.dart' as timeago;


// ============= UNIFIED NOTIFICATION SCREEN =============
class UnifiedNotificationScreen extends StatefulWidget {
  final UserRole role;
  final void Function(String orderId, String? subOrderId)? onNotificationTap;


  const UnifiedNotificationScreen({
    super.key,
    required this.role,
    this.onNotificationTap,
  });


  @override
  State<UnifiedNotificationScreen> createState() => _UnifiedNotificationScreenState();
}


class _UnifiedNotificationScreenState extends State<UnifiedNotificationScreen> {
  late Stream<List<AppNotification>> _notificationStream;


  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUser?.uid ?? '';
    debugPrint('[NotificationScreen] Initializing with UID: "$uid"');
    _notificationStream = NotificationService().streamNotifications(uid);
  }


  void _clearAll() {
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      NotificationService().markAllNotificationsRead(uid);
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


  Widget _buildBody(AsyncSnapshot<List<AppNotification>> snapshot) {
    if (snapshot.hasError) {
      debugPrint('[NotificationScreen] Stream Error: ${snapshot.error}');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error loading notifications:\n${snapshot.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }


    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }


    final notifications = snapshot.data ?? [];
    debugPrint('[NotificationScreen] Loaded ${notifications.length} notifications');
    if (notifications.isEmpty) {
      return _buildEmptyState();
    }


    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _buildNotificationItem(notifications[index]),
    );
  }


  Widget _buildHeader(int count) {
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
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 26),
              const SizedBox(width: 10),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: count == 0 ? null : _clearAll,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF16332A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                child: const Text('Clear all',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            ],
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
          Text("You're all caught up",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
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


  Widget _buildNotificationItem(AppNotification n) {
    switch (widget.role) {
      case UserRole.customer:
        return _buildCustomerCard(n);
      case UserRole.tailor:
        return _buildTailorCard(n);
      case UserRole.retailer:
        return _buildRetailerCard(n);
    }
  }


  // ============= CUSTOMER CARD =============
  Widget _buildCustomerCard(AppNotification n) {
    final style = _customerStyleFor(n.type);


    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          NotificationService().markAsRead(n.id);
          widget.onNotificationTap?.call(n.orderId, n.subOrderId);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      backgroundImage: AssetImage('assets/images/fab.jpg')),
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
                                child: Text(style.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            if (!n.isRead) _buildNewBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n.message,
                          style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.75), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFooterRow(n),
              if (n.type == NotificationDbType.orderCompleted || n.type == NotificationDbType.suborderDelivered)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Please review on orders',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ),
      ),
    );
  }


  _NotificationStyle _customerStyleFor(NotificationDbType type) {
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
  Widget _buildRetailerCard(AppNotification n) {
    final style = _retailerStyleFor(n.type);


    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          NotificationService().markAsRead(n.id);
          widget.onNotificationTap?.call(n.orderId, n.subOrderId);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: n.type == NotificationDbType.deliveryReminder
                        ? Colors.red.shade200
                        : (n.type == NotificationDbType.jobConfirmed ? Colors.blue.shade200 : style.iconColor.withOpacity(0.2)),
                    backgroundImage: const AssetImage('assets/images/textile.jpg'),
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
                                child: Text(style.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            if (!n.isRead) _buildNewBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n.message,
                          style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.75), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFooterRow(n, isRetailer: true),
            ],
          ),
        ),
      ),
    );
  }


  _NotificationStyle _retailerStyleFor(NotificationDbType type) {
    switch (type) {
      case NotificationDbType.suborderPlaced:
        return _NotificationStyle(
          background: const Color(0xFFCDEFD3),
          icon: Icons.shopping_cart_rounded,
          iconColor: Colors.green.shade800,
          title: 'New Order Placed',
        );
      case NotificationDbType.deliveryReminder:
        return _NotificationStyle(
          background: const Color(0xFFF7D6D6),
          icon: Icons.warning_rounded,
          iconColor: Colors.red.shade700,
          title: 'Stock Alert',
        );
      case NotificationDbType.jobConfirmed:
        return _NotificationStyle(
          background: const Color(0xFFD3E9F7),
          icon: Icons.design_services_rounded,
          iconColor: Colors.blue.shade700,
          title: 'Tailor Assigned',
        );
      default:
        return _NotificationStyle(
          background: const Color(0xFFFBE7C0),
          icon: Icons.notifications_active,
          iconColor: Colors.orange.shade800,
          title: 'Retailer Notification',
        );
    }
  }


  // ============= TAILOR CARD =============
  Widget _buildTailorCard(AppNotification n) {
    final style = _tailorStyleFor(n.type);


    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          NotificationService().markAsRead(n.id);
          widget.onNotificationTap?.call(n.orderId, n.subOrderId);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: style.iconColor.withOpacity(0.2),
                    backgroundImage: const AssetImage('assets/images/silk.jpg'),
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
                                child: Text(style.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            if (!n.isRead) _buildNewBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n.message,
                          style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.75), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFooterRow(n),
            ],
          ),
        ),
      ),
    );
  }


  _NotificationStyle _tailorStyleFor(NotificationDbType type) {
    switch (type) {
      case NotificationDbType.jobRequested:
        return _NotificationStyle(
          background: const Color(0xFFCDEFD3),
          icon: Icons.shopping_cart_rounded,
          iconColor: Colors.green.shade800,
          title: 'New Order Received',
        );
      case NotificationDbType.selectionDeadlineReminder:
        return _NotificationStyle(
          background: const Color(0xFFF7D6D6),
          icon: Icons.warning_rounded,
          iconColor: Colors.red.shade700,
          title: 'Action Required',
        );
      case NotificationDbType.jobRejected:
        return _NotificationStyle(
          background: const Color(0xFFF7D6D6),
          icon: Icons.cancel_rounded,
          iconColor: Colors.red.shade700,
          title: 'Order Cancelled',
        );
      default:
        return _NotificationStyle(
          background: const Color(0xFFFBE7C0),
          icon: Icons.notifications_active,
          iconColor: Colors.orange.shade800,
          title: 'Tailor Notification',
        );
    }
  }


  Widget _buildFooterRow(AppNotification n, {bool isRetailer = false}) {
    String idLabel = (isRetailer && n.type == NotificationDbType.deliveryReminder) ? 'Product ID' : 'Order ID';


    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$idLabel: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withOpacity(0.45)),
            const SizedBox(width: 4),
            Text(timeago.format(n.createdAt), style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
          ],
        ),
      ],
    );
  }
}


// ============= STYLE CLASSES =============
class _NotificationStyle {
  final Color background;
  final IconData icon;
  final Color iconColor;
  final String title;


  const _NotificationStyle({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.title,
  });
}

