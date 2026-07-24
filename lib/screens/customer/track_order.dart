import 'package:flutter/material.dart';
import '../../widgets/dashboard_drawer.dart';
import 'home_screen.dart';

// TODO(backend): Replace static `events` list with data fetched from Firestore.
// Each TrackEventType below maps 1:1 to a backend status value, so building
// the timeline is a direct lookup rather than inferred logic:
//
//   1. Fetch `Orders/{orderId}`
//      - orderDate                         → orderPlaced
//      - status == 'awaiting_tailor_search' → awaitingTailorSelection
//      - status == 'completed'             → orderCompleted
//      - status == 'cancelled'             → orderCancelled
//
//   2. Fetch all `Sub-orders` where orderId == this order. For each:
//      - status == 'preparing'             → subOrderPreparing
//      - status == 'packed'                → subOrderPacked
//      - status == 'delivered' AND deliveryDestination == 'tailor'   → shippingToTailor
//        (raw fabric/materials arriving at the tailor — NOT shown as
//        delivered-to-customer; the customer never receives raw fabric
//        when a tailor is involved)
//      - status == 'delivered' AND deliveryDestination == 'customer' → subOrderDelivered
//        (only reachable when no tailor was ever confirmed — raw items
//        ship straight to the customer as-is)
//
//   3. Fetch the single `Tailor-jobs` row where orderId == this order (0 or 1):
//      - status == 'pending'    → tailorRequested
//      - status == 'rejected'   → tailorRejected      (rejectionReason available)
//      - status == 'quoted'     → tailorQuoted         (quoteAmount, quoteNote, quoteResponseDeadline)
//      - status == 'confirmed'  → tailorConfirmed      (confirmedAt, estimatedDeliveryDate — tailor is now sewing)
//      - completedAt != null    → tailorCompleted       (NEW field — garment finished, ready to ship;
//                                  status stays 'confirmed', this timestamp is the ship-trigger)
//      - status == 'expired'    → tailorExpired         (customer missed quoteResponseDeadline)
//      - status == 'cancelled'  → orderCancelled
//
//   4. The finished-garment delivery to the customer (shippingToCustomer /
//      orderCompleted) only fires AFTER tailorCompleted — never off a
//      sub-order's delivered status when a tailor is involved. The item
//      being delivered at that point is the finished dress, not any of the
//      raw materials from step 2.
//
//   5. Merge all events into a single List<TrackEvent>, sort by `date` ascending.
//   6. Pass the sorted list into OrderTrackScreen(events: ...)
//
// Only include events where the corresponding timestamp field is non-null.
// NOTE: Tailor-jobs is 0-or-1 per order (per schema), so at most ONE of
// tailorRequested/tailorRejected/tailorQuoted/tailorConfirmed/tailorCompleted/
// tailorExpired should ever appear per order — do not model multiple
// competing tailors here.
//
// NOTE(backend, item-addition window): a customer may add items from a
// *different* retailer to the same order after the first sub-order is
// placed, but only until the deadline set by the EARLIEST sub-order's
// autoReleaseAt. Once that deadline passes, no further sub-orders may be
// attached to this order — a new item after that point must start a new
// Orders record. Recommend deriving this as:
//   itemAdditionDeadline = MIN(Sub-orders.autoReleaseAt WHERE orderId == X)
// and either computing it live or denormalizing it onto Orders once the
// first sub-order is confirmed, so the client can show a countdown without
// an extra query across all sub-orders on every read.

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
  orderConfirmedTailor, orderCancelled,
}

class TrackEvent {
  final TrackEventType type;
  final String material;
  final String partyName;
  final DateTime date;
  // Optional short caption shown under the date — used for deadline/context
  // callouts (e.g. "Added within Cotton Palace's 5-day order window").
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
  final String status;
  final String estimatedDelivery;
  final String lastUpdated;
  final String deliveryAddress;
  // Nullable so the constructor default can be `null` (DateTime is not const).
  // Falls back to [_demoEvents] at runtime when null.
  final List<TrackEvent>? events;

  // TODO: replace with the real order's event history from the backend
  //
  // Underlying Sub-orders this demo represents (for reference — not rendered
  // directly, only the resulting events below are):
  //   Sub-order 1: retailer 'Cotton Palace', delivered to TAILOR Dec 21,
  //                autoReleaseAt = Dec 26 (5-day item-addition window)
  //   Sub-order 2: retailer 'Mukta Kapors', PLACED Dec 23 — added to the
  //                same order two days after sub-order 1 delivered, but
  //                still before sub-order 1's autoReleaseAt (Dec 26), so
  //                it's a valid addition to this order. Also delivered to
  //                the TAILOR, since a tailor is confirmed on this order —
  //                raw materials never reach the customer in this scenario.
  //   Tailor-jobs: confirmed Dec 25, completedAt Dec 28 — only once
  //                completedAt is set does the finished dress ship out.
  static final List<TrackEvent> _demoEvents = [
    TrackEvent(type: TrackEventType.orderPlaced, material: '', partyName: 'Sketch2Stitch', date: DateTime(2026, 12, 20)),
    TrackEvent(type: TrackEventType.subOrderPreparing, material: 'Fine Cotton', partyName: 'Cotton Palace', date: DateTime(2026, 12, 20)),
    TrackEvent(type: TrackEventType.subOrderPacked, material: 'Fine Cotton', partyName: 'Cotton Palace', date: DateTime(2026, 12, 21)),
    TrackEvent(
      type: TrackEventType.awaitingTailorSelection,
      material: '',
      partyName: 'You',
      date: DateTime(2026, 12, 21),
      note: 'Item-addition window open until Dec 26',
    ),
    TrackEvent(
      type: TrackEventType.subOrderPreparing,
      material: 'Embroidery Thread',
      partyName: 'Mukta Kapors',
      date: DateTime(2026, 12, 23),
      note: 'Added within Cotton Palace\'s order window',
    ),
    TrackEvent(type: TrackEventType.subOrderPacked, material: 'Embroidery Thread', partyName: 'Mukta Kapors', date: DateTime(2026, 12, 24)),
    TrackEvent(type: TrackEventType.tailorRequested, material: '', partyName: 'Master Tailor', date: DateTime(2026, 12, 24)),
    TrackEvent(type: TrackEventType.tailorQuoted, material: '', partyName: 'Master Tailor', date: DateTime(2026, 12, 24)),
    TrackEvent(type: TrackEventType.tailorConfirmed, material: '', partyName: 'Master Tailor', date: DateTime(2026, 12, 25)),
    TrackEvent(
      type: TrackEventType.shippingToTailor,
      material: 'Fine Cotton',
      partyName: 'Master Tailor',
      date: DateTime(2026, 12, 25),
    ),
    TrackEvent(
      type: TrackEventType.shippingToTailor,
      material: 'Embroidery Thread',
      partyName: 'Master Tailor',
      date: DateTime(2026, 12, 25),
    ),
    TrackEvent(type: TrackEventType.tailorCompleted, material: 'Custom Dress', partyName: 'Master Tailor', date: DateTime(2026, 12, 28)),
    TrackEvent(
      type: TrackEventType.shippingToCustomer,
      material: 'Custom Dress',
      partyName: 'DHL Express',
      date: DateTime(2026, 12, 29),
    ),
    TrackEvent(type: TrackEventType.orderCompleted, material: '', partyName: 'Customer', date: DateTime(2026, 12, 30)),
  ];

  List<TrackEvent> get resolvedEvents => events ?? _demoEvents;

  const OrderTrackScreen({
    super.key,
    this.orderId = 'OR05',
    this.status = 'Awaiting Tailor Selection',
    this.estimatedDelivery = '25 Dec 2026',
    this.lastUpdated = '22 Dec 2026',
    this.deliveryAddress = 'The Shakespeare Centre, Henley Street, CV37 6QW Stratford-upon-Avon, UK.',
    this.events,
    required AppUserRole userRole,
  });

  @override
  Widget build(BuildContext context) {
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
                      'Tracking Order for Order ID: $orderId',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildDeliveryAddressCard(),
                    const SizedBox(height: 28),
                    _buildTimeline(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          // ✅ Back button with arrow icon (like track order page)
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
          // You can add any right-side icons here if needed
        ],
      ),
    );
  }

  // ---------------- Status summary card ----------------
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
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
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.black.withOpacity(0.5))),
      ],
    );
  }

  // ---------------- Delivery address card ----------------
  Widget _buildDeliveryAddressCard() {
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
            style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black.withOpacity(0.65)),
          ),
        ],
      ),
    );
  }

  // ---------------- Timeline ----------------
  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(resolvedEvents.length, (index) {
        final bool isLast = index == resolvedEvents.length - 1;
        return _buildTimelineItem(resolvedEvents[index], isLast);
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
                TextSpan(text: 'for ', style: const TextStyle(fontWeight: FontWeight.normal)),
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
          '${event.date.day}/${event.date.month}/${event.date.year}',
          style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.45)),
        ),
        if (event.note != null) ...[
          const SizedBox(height: 3),
          Text(
            event.note!,
            style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.black.withOpacity(0.4)),
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