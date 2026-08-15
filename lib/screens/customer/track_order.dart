import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/order_service.dart';
import 'package:sketch2stitch/models/order.dart';
import 'package:sketch2stitch/models/sub_order.dart';
import 'package:sketch2stitch/models/tailor_job.dart';
import 'package:sketch2stitch/models/customer.dart';

enum TrackEventType {
  orderPlaced,
  subOrderPreparing,
  subOrderPacked,
  subOrderDelivered,
  awaitingTailorSelection,
  tailorRequested,
  tailorRejected,
  tailorQuoted,
  tailorConfirmed,
  tailorCompleted,
  tailorExpired,
  shippingToTailor,
  shippingToCustomer,
  orderCompleted,
  orderConfirmedRetailer,
  orderConfirmedTailor,
  orderCancelled,
}

class TrackEvent {
  final TrackEventType type;
  final String material;
  final String partyName;
  final DateTime date;
  final String? note;

  const TrackEvent({
    required this.type,
    required this.material,
    required this.partyName,
    required this.date,
    this.note,
  });
}

class OrderTrackScreen extends StatelessWidget {
  final String orderId;
  final UserRole userRole;

  const OrderTrackScreen({
    super.key,
    this.orderId = 'OR05',
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: OrderService().streamOrderTimeline(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.hasError ? 'Error loading tracking data' : 'Order details not found',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final Order order = data['order'];
        final List<SubOrder> subOrders = data['subOrders'];
        final TailorJob? tailorJob = data['tailorJob'];
        final Map<String, String> partyNames = data['partyNames'];
        final Map<String, String> productNames = data['productNames'] ?? {};
        final Customer? customer = data['customer'];

        final events = _buildTrackEvents(
          order: order,
          subOrders: subOrders,
          tailorJob: tailorJob,
          partyNames: partyNames,
          productNames: productNames,
          customer: customer,
        );

        final status = order.statusText;
        final estimatedDelivery = tailorJob?.estimatedDeliveryDate != null
            ? DateFormat('dd MMM yyyy').format(tailorJob!.estimatedDeliveryDate!)
            : (order.tailorSelectionDeadline != null
                ? DateFormat('dd MMM yyyy').format(order.tailorSelectionDeadline!)
                : 'Pending');
        final lastUpdated = events.isNotEmpty
            ? DateFormat('dd MMM yyyy').format(events.first.date)
            : DateFormat('dd MMM yyyy').format(order.orderDate);
        final deliveryAddress = customer?.address ?? 'No address provided';

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tracking Order for Order ID: ${order.id}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusCard(status, estimatedDelivery, lastUpdated),
                        const SizedBox(height: 16),
                        _buildDeliveryAddressCard(deliveryAddress),
                        const SizedBox(height: 28),
                        _buildTimeline(events),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<TrackEvent> _buildTrackEvents({
    required Order order,
    required List<SubOrder> subOrders,
    required TailorJob? tailorJob,
    required Map<String, String> partyNames,
    required Map<String, String> productNames,
    required Customer? customer,
  }) {
    final List<TrackEvent> events = [];

    // 1. Order Placed
    events.add(TrackEvent(
      type: TrackEventType.orderPlaced,
      material: '',
      partyName: 'Sketch2Stitch',
      date: order.orderDate,
    ));

    // 2. Awaiting Tailor Selection
    if (order.status == OrderStatus.awaitingTailorSearch) {
      events.add(TrackEvent(
        type: TrackEventType.awaitingTailorSelection,
        material: '',
        partyName: 'You',
        date: order.orderDate,
        note: order.tailorSelectionDeadline != null
            ? 'Item-addition window open until ${DateFormat('MMM dd').format(order.tailorSelectionDeadline!)}'
            : null,
      ));
    }

    // 3. Sub-orders logic
    for (var so in subOrders) {
      final retailerName = partyNames[so.retailerId] ?? 'Retailer';
      final materialList = so.items?.map((i) => productNames[i.productId] ?? 'Material').join(', ') ?? 'Materials';

      if (so.status == SubOrderStatus.preparing) {
        events.add(TrackEvent(
          type: TrackEventType.subOrderPreparing,
          material: materialList,
          partyName: retailerName,
          date: order.orderDate,
        ));
      } else if (so.status == SubOrderStatus.packed) {
        events.add(TrackEvent(
          type: TrackEventType.subOrderPreparing,
          material: materialList,
          partyName: retailerName,
          date: order.orderDate,
        ));
        events.add(TrackEvent(
          type: TrackEventType.subOrderPacked,
          material: materialList,
          partyName: retailerName,
          date: so.deliveryDate ?? order.orderDate,
        ));
      } else if (so.status == SubOrderStatus.delivered) {
        events.add(TrackEvent(
          type: TrackEventType.subOrderPreparing,
          material: materialList,
          partyName: retailerName,
          date: order.orderDate,
        ));
        events.add(TrackEvent(
          type: TrackEventType.subOrderPacked,
          material: materialList,
          partyName: retailerName,
          date: so.deliveryDate ?? order.orderDate,
        ));

        final isToTailor = so.deliveryDestination == SubOrderDeliveryDestination.tailor;
        events.add(TrackEvent(
          type: isToTailor ? TrackEventType.shippingToTailor : TrackEventType.subOrderDelivered,
          material: materialList,
          partyName: isToTailor ? (partyNames[tailorJob?.tailorId] ?? 'Tailor') : (customer?.name ?? 'Customer'),
          date: so.deliveryDate ?? DateTime.now(),
        ));
      }
    }

    // 4. Tailor Job logic
    if (tailorJob != null) {
      final tailorName = partyNames[tailorJob.tailorId] ?? 'Tailor';
      final baseDate = tailorJob.requestedAt ?? tailorJob.createdAt ?? order.orderDate;

      if (tailorJob.status == TailorJobStatus.pending) {
        events.add(TrackEvent(type: TrackEventType.tailorRequested, material: '', partyName: tailorName, date: baseDate));
      } else if (tailorJob.status == TailorJobStatus.rejected || tailorJob.status == TailorJobStatus.tailorDeclined) {
        events.add(TrackEvent(type: TrackEventType.tailorRequested, material: '', partyName: tailorName, date: baseDate));
        events.add(TrackEvent(
          type: TrackEventType.tailorRejected,
          material: '',
          partyName: tailorName,
          date: DateTime.now(),
          note: tailorJob.rejectionReason,
        ));
      } else if (tailorJob.status == TailorJobStatus.quoted) {
        events.add(TrackEvent(type: TrackEventType.tailorRequested, material: '', partyName: tailorName, date: baseDate));
        events.add(TrackEvent(
          type: TrackEventType.tailorQuoted,
          material: '',
          partyName: tailorName,
          date: tailorJob.createdAt ?? baseDate,
          note: tailorJob.quoteAmount != null ? 'Quote Received: ৳${tailorJob.quoteAmount}' : null,
        ));
      } else if (tailorJob.status == TailorJobStatus.confirmed || tailorJob.confirmedAt != null) {
        events.add(TrackEvent(type: TrackEventType.tailorRequested, material: '', partyName: tailorName, date: baseDate));
        events.add(TrackEvent(
          type: TrackEventType.tailorQuoted,
          material: '',
          partyName: tailorName,
          date: tailorJob.createdAt ?? baseDate,
        ));
        events.add(TrackEvent(
          type: TrackEventType.tailorConfirmed,
          material: '',
          partyName: tailorName,
          date: tailorJob.confirmedAt ?? DateTime.now(),
        ));
      }
    }

    // Order level final statuses
    if (order.status == OrderStatus.completed) {
      events.add(TrackEvent(
        type: TrackEventType.orderCompleted,
        material: '',
        partyName: 'Customer',
        date: DateTime.now(),
      ));
    } else if (order.status == OrderStatus.cancelled) {
      events.add(TrackEvent(
        type: TrackEventType.orderCancelled,
        material: '',
        partyName: 'Sketch2Stitch',
        date: DateTime.now(),
      ));
    }

    // Sort descending (latest first at the top)
    events.sort((a, b) => b.date.compareTo(a.date));

    return events;
  }

  // ---------------- Top bar ----------------
  Widget _buildTopBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade200, Colors.green.shade50],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Image.asset(
            'assets/images/transparent_logo.png',
            height: 30,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.checkroom_rounded, size: 26, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 8),
          const Text('Sketch2Stitch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          const Spacer(),
        ],
      ),
    );
  }

  // ---------------- Status summary card ----------------
  Widget _buildStatusCard(String status, String estimatedDelivery, String lastUpdated) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Expanded(child: _statusColumn(Icons.shopping_cart_outlined, status, 'Status')),
          _verticalDivider(),
          Expanded(child: _statusColumn(Icons.hourglass_empty_rounded, estimatedDelivery, 'Estimated Delivery')),
          _verticalDivider(),
          Expanded(child: _statusColumn(Icons.update_rounded, lastUpdated, 'Last Updated')),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 44, color: Colors.black12);
  }

  Widget _statusColumn(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Colors.black87),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.black.withValues(alpha: 0.5))),
      ],
    );
  }

  // ---------------- Delivery address card ----------------
  Widget _buildDeliveryAddressCard(String deliveryAddress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFD7EFD8), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Address', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          Text(
            deliveryAddress,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }

  // ---------------- Timeline ----------------
  Widget _buildTimeline(List<TrackEvent> events) {
    if (events.isEmpty) {
      return const Center(child: Text('No tracking events found.', style: TextStyle(fontSize: 12, color: Colors.black45)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(events.length, (index) {
        final bool isLast = index == events.length - 1;
        return _buildTimelineItem(events[index], isLast);
      }),
    );
  }

  Widget _buildTimelineItem(TrackEvent event, bool isLast) {
    final style = _styleFor(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                child: Icon(style.icon, size: 12, color: Colors.white),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                      children: [
                        TextSpan(text: '${style.verb} '),
                        if (event.material.isNotEmpty) ...[
                          const TextSpan(text: 'for ', style: TextStyle(fontWeight: FontWeight.normal)),
                          TextSpan(text: event.material, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: ' from '),
                          TextSpan(text: event.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ] else ...[
                          TextSpan(text: event.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd/MM/yyyy').format(event.date),
                    style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
                  ),
                  if (event.note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.note!,
                      style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.black.withValues(alpha: 0.4)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TrackEventStyle _styleFor(TrackEventType type) {
    switch (type) {
      case TrackEventType.orderPlaced:
        return _TrackEventStyle(
          color: Colors.grey.shade600,
          icon: Icons.receipt_long_rounded,
          verb: 'Order Placed',
        );
      case TrackEventType.subOrderPreparing:
        return _TrackEventStyle(
          color: Colors.orange.shade600,
          icon: Icons.pending_rounded,
          verb: 'Preparing Order',
        );
      case TrackEventType.subOrderPacked:
        return _TrackEventStyle(
          color: Colors.blue.shade600,
          icon: Icons.inventory_2_rounded,
          verb: 'Packed',
        );
      case TrackEventType.subOrderDelivered:
        return _TrackEventStyle(
          color: Colors.green.shade700,
          icon: Icons.check_circle_rounded,
          verb: 'Delivered',
        );
      case TrackEventType.awaitingTailorSelection:
        return _TrackEventStyle(
          color: Colors.amber.shade700,
          icon: Icons.search_rounded,
          verb: 'Awaiting Tailor Selection',
        );
      case TrackEventType.tailorRequested:
        return _TrackEventStyle(
          color: Colors.blue.shade600,
          icon: Icons.north_east_rounded,
          verb: 'Requested',
        );
      case TrackEventType.tailorRejected:
        return _TrackEventStyle(
          color: Colors.red.shade500,
          icon: Icons.close_rounded,
          verb: 'Rejected',
        );
      case TrackEventType.tailorQuoted:
        return _TrackEventStyle(
          color: Colors.purple.shade400,
          icon: Icons.request_quote_rounded,
          verb: 'Quote Received',
        );
      case TrackEventType.tailorConfirmed:
        return _TrackEventStyle(
          color: Colors.purple.shade600,
          icon: Icons.design_services_rounded,
          verb: 'Tailor Confirmed — Stitching Started',
        );
      case TrackEventType.tailorCompleted:
        return _TrackEventStyle(
          color: Colors.purple.shade800,
          icon: Icons.checkroom_rounded,
          verb: 'Garment Completed',
        );
      case TrackEventType.tailorExpired:
        return _TrackEventStyle(
          color: Colors.red.shade400,
          icon: Icons.timer_off_rounded,
          verb: 'Quote Expired',
        );
      case TrackEventType.shippingToTailor:
        return _TrackEventStyle(
          color: Colors.teal.shade600,
          icon: Icons.local_shipping_rounded,
          verb: 'Shipping to Tailor',
        );
      case TrackEventType.shippingToCustomer:
        return _TrackEventStyle(
          color: Colors.indigo.shade600,
          icon: Icons.delivery_dining_rounded,
          verb: 'Shipping to Customer',
        );
      case TrackEventType.orderCompleted:
        return _TrackEventStyle(
          color: Colors.green.shade700,
          icon: Icons.check_circle_rounded,
          verb: 'Order Completed',
        );
      case TrackEventType.orderCancelled:
        return _TrackEventStyle(
          color: Colors.red.shade700,
          icon: Icons.cancel_rounded,
          verb: 'Order Cancelled',
        );
      case TrackEventType.orderConfirmedRetailer:
        return _TrackEventStyle(
            color: Colors.blue.shade600,
            icon: Icons.storefront_rounded,
            verb: 'Order Confirmed from Retailer');
      case TrackEventType.orderConfirmedTailor:
        return _TrackEventStyle(
            color: Colors.purple.shade600,
            icon: Icons.design_services_rounded,
            verb: 'Order Confirmed from Tailor');
    }
  }
}

class _TrackEventStyle {
  final Color color;
  final IconData icon;
  final String verb;

  const _TrackEventStyle({required this.color, required this.icon, required this.verb});
}
