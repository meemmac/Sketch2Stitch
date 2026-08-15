import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/user_role.dart';
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
  // Cache for profile data (URLs or Resolved Name/ID Maps)
  final Map<String, dynamic> _profileCache = {};


  Stream<List<AppNotification>> _getNotificationsStream() {
    // Use UserSession email to find the UID securely
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      debugPrint('[NotificationScreen] Waiting for valid Firebase UID...');
      return Stream.value([]);
    }

    debugPrint('[NotificationScreen] Connecting to live backend for UID: "$uid"');
    return NotificationService().streamNotifications(uid);
  }


  void _clearAll() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      NotificationService().deleteAllNotifications(uid);
    }
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _getNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final count = notifications.length;


        return PopScope(
          canPop: true,
          child: Scaffold(
            backgroundColor: const Color(0xFFF6FAF6),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(count),
                  Expanded(
                    child: _buildBody(snapshot),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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


    if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF16332A)),
            SizedBox(height: 16),
            Text('Syncing with database...', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }


    final notifications = snapshot.data ?? [];
    debugPrint('[NotificationScreen] Loaded ${notifications.length} notifications');
    if (notifications.isEmpty) {
      return _buildEmptyState();
    }


    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final n = notifications[index];
        return Dismissible(
          key: Key(n.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
          ),
          onDismissed: (_) => NotificationService().deleteNotification(n.id),
          child: _buildNotificationItem(n),
        );
      },
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

  Widget _buildAvatar(AppNotification n, _NotificationStyle style) {
    // 1. Handle System Notifications (e.g. Stock Alerts for Retailers)
    final isStockAlert = widget.role == UserRole.retailer && 
                         n.type == NotificationDbType.deliveryReminder;
    
    if (isStockAlert) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.red.shade50,
        child: Icon(Icons.inventory_2_outlined, color: Colors.red.shade700, size: 20),
      );
    }

    // 2. Profile picture lookup for Customers (to see Tailor/Retailer photos)
    if (widget.role == UserRole.customer) {
      final cacheKey = n.subOrderId ?? n.tailorJobId ?? n.orderId;
      
      // If we already know the URL, show it immediately
      if (_profileCache.containsKey(cacheKey) && _profileCache[cacheKey] is String) {
        return CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white,
          backgroundImage: NetworkImage(_profileCache[cacheKey] as String),
        );
      }

      // Otherwise, fetch it once and store it in cache
      return FutureBuilder<String?>(
        future: NotificationService().getSenderProfilePicture(n),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            _profileCache[cacheKey] = snapshot.data;
            return CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage(snapshot.data!),
            );
          }
          
          // While loading or if no picture found, show initials
          return _buildInitialsAvatar(n, style);
        },
      );
    }

    // For Tailors/Retailers receiving from Customers, always use initials
    return _buildInitialsAvatar(n, style);
  }

  Widget _buildInitialsAvatar(AppNotification n, _NotificationStyle style) {
    // 1. Use the name fetched from the Customer Table (senderName) if available
    String? name = n.senderName;


    // 2. Backup: Smart Name Parser (only if database name is missing)
    if (name == null || name.trim().isEmpty) {
      final msg = n.message.toLowerCase();
      if (msg.contains('from ')) {
        final parts = n.message.split(RegExp(r'from ', caseSensitive: false));
        if (parts.length > 1) name = parts[1].trim().split(' ')[0];
      } else if (msg.contains('by ')) {
        final parts = n.message.split(RegExp(r'by ', caseSensitive: false));
        if (parts.length > 1) name = parts[1].trim().split(' ')[0];
      }
    }


    final initial = (name != null && name.trim().isNotEmpty)
        ? name.trim()[0].toUpperCase()
        : null;


    return CircleAvatar(
      radius: 22,
      backgroundColor: style.iconColor.withValues(alpha: 0.12),
      child: initial != null
          ? Text(
              initial,
              style: TextStyle(
                color: style.iconColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : Icon(Icons.person, color: style.iconColor),
    );
  }

  Widget _buildNotificationItem(AppNotification n) {
    // The Notifications collection never stores orderId directly — every role needs the same
    // subOrderId/tailorJobId -> orderId resolution, not just Tailor/Retailer.
    final cacheKey = n.subOrderId ?? n.tailorJobId ?? n.orderId;
    
    if (_profileCache.containsKey("${cacheKey}_resolved")) {
      final data = _profileCache["${cacheKey}_resolved"] as Map<String, String?>;
      return _buildRoleCardWithResolvedData(n, data);
    }

    return FutureBuilder<Map<String, String?>?>(
      future: NotificationService().getResolvedNotificationData(n),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _profileCache["${cacheKey}_resolved"] = snapshot.data;
          return _buildRoleCardWithResolvedData(n, snapshot.data!);
        }
        
        return _buildOriginalCardByRole(n);
      },
    );
  }

  Widget _buildRoleCardWithResolvedData(AppNotification n, Map<String, String?> data) {
    // Temporarily swap data in memory for UI display
    final tempNotification = n.copyWith(
      senderName: data['customerName'],
      orderId: data['orderId'] ?? n.orderId,
      cancelReason: data['rejectionReason'],
    );
    
    return _buildOriginalCardByRole(tempNotification);
  }

  Widget _buildOriginalCardByRole(AppNotification n) {
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
                  _buildAvatar(n, style),
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
                          style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.75), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (n.type == NotificationDbType.jobRejected) _buildCustomerCancelRow(n) else _buildFooterRow(n),
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

  Widget _buildCustomerCancelRow(AppNotification n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Order ID: ${n.orderId}', style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.55))),
        Row(
          children: [
            if (n.cancelReason != null && n.cancelReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: OutlinedButton(
                  onPressed: () => _showCustomerCancelReason(n),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View Reason',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
              ),
            Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withValues(alpha: 0.45)),
            const SizedBox(width: 4),
            Text(timeago.format(n.createdAt), style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.55))),
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
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
            ],
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
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7D6D6).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF7D6D6).withValues(alpha: 0.5)),
                ),
                child: Text(n.cancelReason ?? 'No reason was provided.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black.withValues(alpha: 0.8))),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  _NotificationStyle _customerStyleFor(NotificationDbType type) {
    switch (type) {
      case NotificationDbType.orderConfirmed:
        return _NotificationStyle(
          background: const Color(0xFFCDEFD3),
          icon: Icons.check_circle_rounded,
          iconColor: Colors.green.shade800,
          title: 'Order Confirmed',
        );
      case NotificationDbType.orderCompleted:
      case NotificationDbType.suborderDelivered:
        return _NotificationStyle(
          background: const Color(0xFFD3E9F7),
          icon: Icons.local_shipping_rounded,
          iconColor: Colors.blue.shade700,
          title: 'Order Delivered',
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
          title: 'Notification',
        );
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
                  _buildAvatar(n, style),
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
                          style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.75), height: 1.4),
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
                  _buildAvatar(n, style),
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
                          style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.75), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (n.type == NotificationDbType.jobRejected) _buildCustomerCancelRow(n) else _buildFooterRow(n),
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
          icon: Icons.assignment_late_outlined,
          iconColor: Colors.red.shade700,
          title: 'Job Confirmation Required',
        );
      case NotificationDbType.jobDeliveryDeadline:
        return _NotificationStyle(
          background: const Color(0xFFFBE7C0),
          icon: Icons.timer_rounded,
          iconColor: Colors.orange.shade800,
          title: 'Delivery Deadline Approaching',
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
    String idLabel = 'Order ID';
    String idValue = n.orderId;

    if (isRetailer && n.type == NotificationDbType.deliveryReminder) {
      idLabel = 'Product ID';
    }


    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$idLabel: $idValue', style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.55))),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 13, color: Colors.black.withValues(alpha: 0.45)),
            const SizedBox(width: 4),
            Text(timeago.format(n.createdAt), style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.55))),
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

