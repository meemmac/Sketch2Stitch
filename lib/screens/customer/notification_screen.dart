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
  late List<CustomerNotificationCardData> _customerNotifications;
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
        case UserRole.customer:
          _customerNotifications.clear();
          break;
        case UserRole.tailor:
          _tailorNotifications.clear();
          break;
        case UserRole.retailer:
          _retailerNotifications.clear();
          break;
      }
    });
  }

  int get _notificationCount {
    switch (widget.role) {
      case UserRole.customer:
        return _customerNotifications.length;
      case UserRole.tailor:
        return _tailorNotifications.length;
      case UserRole.retailer:
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
      case UserRole.customer:
        title = 'Notifications';
        break;
      case UserRole.tailor:
        title = 'Notifications';
        break;
      case UserRole.retailer:
        title = 'Notifications';
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
              // ✅ Back button with arrow icon (like track order page)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 26),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // ✅ Clear all button
              TextButton(
                onPressed: _notificationCount == 0 ? null : _clearAll,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF16332A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                child: const Text('Clear all', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
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
      case UserRole.customer:
        return _buildCustomerCard(_customerNotifications[index]);
      case UserRole.tailor:
        return _buildTailorCard(_tailorNotifications[index]);
      case UserRole.retailer:
        return _buildRetailerCard(_retailerNotifications[index]);
    }
  }

  // ============= CUSTOMER CARD =============
  Widget _buildCustomerCard(CustomerNotificationCardData n) {
    final style = _customerStyleFor(n.type);

    // ✅ Check if notification is from a retailer
    bool isFromRetailer = n.partyName.contains('Fabric') ||
        n.partyName.contains('House') ||
        n.partyName.contains('Shop') ||
        n.partyName.contains('Store') ||
        n.partyLabel == 'from';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onNotificationTap?.call(n.orderId, n.subOrderId),
        child: Container(
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
                              if (isFromRetailer) ...[
                                // ✅ Retailer: Show only retailer name
                                TextSpan(
                                  text: n.partyName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ] else ...[
                                // ✅ Tailor: Show product name + tailor name
                                TextSpan(
                                  text: n.itemName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                TextSpan(text: ' ${n.partyLabel} '),
                                TextSpan(
                                  text: n.partyName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ],
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
                  child: Text('Please review on orders', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCancelRow(CustomerNotificationCardData n) {
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

  Widget _buildCustomerFooterRow(CustomerNotificationCardData n) {
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

  void _showCustomerCancelReason(CustomerNotificationCardData n) {
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

    bool isStockOut = n.type == RetailerNotificationType.stockOut;
    bool isTailorAssigned = n.type == RetailerNotificationType.tailorAssigned;

    String firstLetter = isStockOut ? '📦' : (n.customerName.isNotEmpty ? n.customerName[0].toUpperCase() : '?');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onNotificationTap?.call(n.orderId, n.subOrderId),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar - shows product emoji for stockOut, first letter for customer
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isStockOut
                        ? Colors.red.shade200
                        : (isTailorAssigned ? Colors.blue.shade200 : style.iconColor.withOpacity(0.2)),
                    child: isStockOut
                        ? const Icon(Icons.inventory_2_outlined, color: Colors.red, size: 22)
                        : isTailorAssigned
                        ? Icon(Icons.design_services_rounded, color: Colors.blue.shade700, size: 22)
                        : Text(
                      firstLetter,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: style.iconColor,
                      ),
                    ),
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
                            Expanded(child: Text(style.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            if (n.isNew) _buildNewBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.75), height: 1.4),
                            children: [
                              if (isStockOut) ...[
                                TextSpan(text: '${n.customerName} '),
                                TextSpan(text: style.messageMiddle),
                                if (n.colorName != null) ...[
                                  TextSpan(text: ' (Color: '),
                                  TextSpan(text: n.colorName!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                  TextSpan(text: ')'),
                                ],
                                TextSpan(text: style.messageSuffix),
                              ] else if (isTailorAssigned) ...[
                                TextSpan(text: 'Order #${n.orderId} '),
                                TextSpan(text: style.messageMiddle),
                                TextSpan(
                                  text: n.tailorName ?? 'a tailor',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                if (n.deliveryDeadline != null) ...[
                                  TextSpan(text: ' with deadline: '),
                                  TextSpan(
                                    text: n.deliveryDeadline!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                  TextSpan(text: '. Please start delivery as soon as possible. '),
                                ],
                              ] else ...[
                                TextSpan(text: style.messagePrefix),
                                TextSpan(text: n.customerName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                TextSpan(text: style.messageMiddle),
                                TextSpan(text: n.itemName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                TextSpan(text: style.messageSuffix),
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
        ),
      ),
    );
  }

  Widget _buildRetailerFooter(RetailerNotification n) {
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

  _RetailerNotificationStyle _retailerStyleFor(RetailerNotificationType type) {
    switch (type) {
      case RetailerNotificationType.orderPlaced:
        return _RetailerNotificationStyle(
          background: const Color(0xFFCDEFD3),
          icon: Icons.shopping_cart_rounded,
          iconColor: Colors.green.shade800,
          title: 'New Order Placed',
          messagePrefix: '',
          messageMiddle: ' placed an order for ',
          messageSuffix: '. ',
        );
      case RetailerNotificationType.stockOut:
        return _RetailerNotificationStyle(
          background: const Color(0xFFF7D6D6),
          icon: Icons.warning_rounded,
          iconColor: Colors.red.shade700,
          title: 'Stock Alert',
          messagePrefix: '',
          messageMiddle: ' is out of stock',
          messageSuffix: '.',
        );
      case RetailerNotificationType.tailorAssigned:
        return _RetailerNotificationStyle(
          background: const Color(0xFFD3E9F7), // Blue background
          icon: Icons.design_services_rounded,
          iconColor: Colors.blue.shade700,
          title: 'Tailor Assigned',
          messagePrefix: '',
          messageMiddle: ' assigned to ',
          messageSuffix: ' for order ',
        );
    }
  }

  // ============= TAILOR CARD =============
  // ============= TAILOR CARD =============
  Widget _buildTailorCard(TailorNotification n) {
    final style = _tailorStyleFor(n.type);

    // Get first letter of customer name for avatar
    String firstLetter = n.customerName.isNotEmpty ? n.customerName[0].toUpperCase() : '?';
    bool isCancelled = n.type == TailorNotificationType.orderCancelledByCustomer;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onNotificationTap?.call(n.orderId, n.subOrderId),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Avatar with first letter of customer name (for cancellation too)
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isCancelled
                        ? Colors.red.shade100
                        : style.iconColor.withOpacity(0.2),
                    child: Text(
                      firstLetter,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCancelled ? Colors.red.shade700 : style.iconColor,
                      ),
                    ),
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
      TextSpan(
        text: n.customerName,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
      ),
      if (style.messageSuffix.isNotEmpty) TextSpan(text: style.messageSuffix),
      if (n.type == TailorNotificationType.deliveryDeadline && n.deadlineDate != null) ...[
        TextSpan(
          text: ' Deadline: ${n.deadlineDate}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
      ],
      if (n.type == TailorNotificationType.newOrder) ...[
        TextSpan(text: ' View Order from orders'),
      ],
      if (n.type == TailorNotificationType.orderConfirmationReminder) ...[
        TextSpan(text: ' Confirm Now in orders'),
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
        ),
      ),
    );
  }

  Widget _buildTailorFooter(TailorNotification n) {
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
  final String messageSuffix;

  const _TailorNotificationStyle({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.messagePrefix,
    required this.messageSuffix,
  });
}