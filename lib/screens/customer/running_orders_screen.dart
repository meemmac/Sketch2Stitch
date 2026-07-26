import 'package:flutter/material.dart';
import '../../models/measurement.dart';
import 'order_session.dart';
import 'tailoring_setup_screen.dart';
import 'tailoring_callbacks.dart';

/// ─── Running Orders Screen ──────────────────────────────────────────────
///
/// Lists every order still needing a customer decision — i.e.
/// `OrderRecord.isActive == true` (awaiting_confirmation,
/// awaiting_tailor_search, tailor_pending). Orders that were skipped,
/// expired-to-direct-delivery, or fully paid are TERMINAL and intentionally
/// do NOT appear here — see OrderRecord.isActive for why.
///
/// This screen never blocks or is blocked by CartScreen — it's a pure
/// navigation shortcut into an existing TailoringSetupScreen instance.
class RunningOrdersScreen extends StatelessWidget {
  const RunningOrdersScreen({super.key});

  // TODO: replace with the real saved measurement fetch (same source used
  // by CartScreen/CheckoutScreen) once the backend is connected.
  static final Measurement _measurement = Measurement(
    id: "MEAS001",
    customerId: "CUST001",
    upperBustCircumference: 34,
    roundShoulderCircumference: 40,
    hipsCircumference: 38,
    underBustCircumference: 30,
    bustCircumference: 36,
    waist: 28,
    shoulderToKnee: 38,
    shoulderToUnderBust: 15,
    shoulderToBust: 10,
    thigh: 22,
    knee: 15,
    ankle: 9,
    waistToAnkle: 40,
    shoulderToAnkle: 58,
  );

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

  void _continueOrder(BuildContext context, OrderRecord order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TailoringSetupScreen(
          orderId: order.orderId,
          orderDate: order.orderDate,
          savedMeasurements: [_measurement],
          subOrders: order.subOrders,
          callbacks: buildTailoringCallbacks(order.orderId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = OrderStore.instance.activeOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("Running Orders", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: orders.isEmpty ? _buildEmptyState() : _buildList(context, orders),
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

  Widget _buildList(BuildContext context, List<OrderRecord> orders) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildOrderCard(context, orders[index]),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderRecord order) {
    final subOrderCount = order.subOrders.length;
    final total = order.subOrders.fold<double>(
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
                    Text("Order #${order.orderId}",
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
              color: _statusColor(order.orderStatus).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(order.orderStatus),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _statusColor(order.orderStatus),
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