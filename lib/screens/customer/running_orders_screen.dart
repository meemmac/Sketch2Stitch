import 'package:flutter/material.dart';
import '../../models/measurement.dart';
import '../../models/order.dart';
import '../../services/measurement_service.dart';
import '../../services/order_service.dart';
import '../../services/user_session.dart';
import 'tailoring_setup_screen.dart';
import 'tailoring_callbacks.dart';

/// ─── Running Orders Screen ──────────────────────────────────────────────
///
/// Lists every order still needing a customer decision — i.e.
/// an `Orders.status` in `OrderService.activeOrderStatuses`
/// (awaiting_confirmation, awaiting_tailor_search, tailor_pending). Orders
/// that were skipped or expired-to-direct-delivery ('processing') and fully
/// paid ones ('completed') are TERMINAL and intentionally do NOT appear
/// here — there is nothing left for the customer to decide.
///
/// This screen never blocks or is blocked by CartScreen — it's a pure
/// navigation shortcut into an existing TailoringSetupScreen instance.
///
/// Both the order list and the customer's saved measurement come from
/// Firestore (`Orders` + `Sub-orders` via OrderService, `Measurement` via
/// MeasurementService). The list is a live stream, so a tailor's quote or
/// an order going terminal on another device updates this screen without
/// a manual refresh.
class RunningOrdersScreen extends StatefulWidget {
  const RunningOrdersScreen({super.key});

  @override
  State<RunningOrdersScreen> createState() => _RunningOrdersScreenState();
}

class _RunningOrdersScreenState extends State<RunningOrdersScreen> {
  final OrderService _orderService = OrderService();
  final MeasurementService _measurementService = MeasurementService();

  late final String? _customerId = UserSession.instance.uid;
  late final Stream<List<Order>> _ordersStream = _customerId == null
      ? Stream.value(const <Order>[])
      : _orderService.streamActiveCustomerOrders(_customerId);

  // Fetched once per visit rather than per card — the same measurement is
  // handed to whichever order the customer continues into, and it can't
  // change while this screen is on top. Null until it loads, and stays
  // null for a customer who hasn't saved measurements yet; the Continue
  // button waits on the load and TailoringSetupScreen already handles the
  // empty case (it prompts the customer to enter measurements).
  Measurement? _measurement;
  late final Future<void> _measurementLoad = _loadMeasurement();

  Future<void> _loadMeasurement() async {
    if (_customerId == null) return;
    try {
      _measurement = await _measurementService.getMeasurement(_customerId);
    } catch (e) {
      debugPrint('[RunningOrders] measurement fetch failed: $e');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'awaiting_confirmation':
        return "Choose tailor or skip";
      case 'awaiting_tailor_search':
        return "Select a tailor";
      case 'tailor_pending':
        return "Waiting on tailor / payment";
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'awaiting_confirmation':
        return Colors.amber.shade800;
      case 'awaiting_tailor_search':
        return Colors.blue.shade700;
      case 'tailor_pending':
        return Colors.green.shade800;
      default:
        return Colors.black54;
    }
  }

  Future<void> _continueOrder(BuildContext context, Order order) async {
    // The measurement load starts in initState, so this normally resolves
    // immediately; awaiting it guards the rare case where the customer taps
    // Continue before the first read comes back.
    await _measurementLoad;
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TailoringSetupScreen(
          orderId: order.id,
          orderDate: order.orderDate,
          savedMeasurements: _measurement == null ? const [] : [_measurement!],
          subOrders: order.subOrders ?? const [],
          callbacks: buildTailoringCallbacks(order.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("Running Orders", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<List<Order>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }
          // Only the very first frame shows a spinner — later snapshots
          // keep the current list on screen while the new one arrives.
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!;
          return orders.isEmpty
              ? _buildEmptyState()
              : _buildList(context, orders);
        },
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    debugPrint('[RunningOrders] order stream failed: $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              "Couldn't load your running orders",
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              "Check your connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rtl_rounded, size: 56, color: Colors.green.shade200),
          const SizedBox(height: 12),
          const Text(
            "No orders need attention right now",
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            "Orders you've skipped tailoring for, or fully paid, won't show up here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Order> orders) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildOrderCard(context, orders[index]),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final subOrders = order.subOrders ?? const [];
    final subOrderCount = subOrders.length;
    final total = subOrders.fold<double>(
      0,
      (sum, s) => sum + s.itemsSubtotal + s.deliveryCharge,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded, size: 18, color: Colors.green.shade800),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order #${order.id}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      "$subOrderCount ${subOrderCount == 1 ? 'retailer' : 'retailers'} · Tk ${total.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(order.status.toValue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(order.status.toValue),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _statusColor(order.status.toValue),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            // "Continue" — visually distinct (outlined, not filled) from
            // CartScreen's filled green "Checkout" button, so the two
            // never read as the same action.
            child: OutlinedButton(
              onPressed: () => _continueOrder(context, order),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade800,
                side: BorderSide(color: Colors.green.shade300),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}