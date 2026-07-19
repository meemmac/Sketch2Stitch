import 'package:flutter/material.dart';
import 'cart_screen.dart';
import 'tailoring_setup_screen.dart';
import '../../models/measurement.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartLine> cartLines;
  final Map<String, RetailerInfo> retailers;
  final double grandTotal;
  final Measurement measurement;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.cartLines,
    required this.retailers,
    required this.grandTotal,
    required this.measurement,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Set<String> _paidRetailers = {};
  String? _payingRetailerId;

  Map<String, List<CartLine>> get _groupedByRetailer {
    final Map<String, List<CartLine>> grouped = {};
    for (final line in widget.cartLines) {
      grouped.putIfAbsent(line.retailerId, () => []).add(line);
    }
    return grouped;
  }

  bool get _allPaid {
    final ids = _groupedByRetailer.keys;
    if (ids.isEmpty) return false;
    return ids.every((id) => _paidRetailers.contains(id));
  }

  Future<void> _payRetailer(String retailerId) async {
    setState(() => _payingRetailerId = retailerId);

    // TODO: real Payments write, targetType = 'retailer', targetId = retailerId
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _paidRetailers.add(retailerId);
      _payingRetailerId = null;
    });
  }

  void _continueToTailoring() {
    widget.onOrderPlaced(); // clears the cart now that the order is sent

    final orderId = 'ORDER_PLACEHOLDER'; // TODO: real Orders doc id
    final orderDate = DateTime.now();    // TODO: real Orders.orderDate

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TailoringSetupScreen(
          orderId: orderId,
          orderDate: orderDate,
          savedMeasurements: [widget.measurement], // one customer, one profile
          callbacks: TailoringSetupCallbacks(
            onSkipTailoring: () async {
              // TODO: Orders.status = 'processing';
              // every Sub-orders.deliveryDestination = 'customer'
            },
            onContinueToTailor: (deadline) async {
              // TODO: Orders.status = 'awaiting_tailor_search';
              // tailorSelectionDeadline = deadline
            },
            onCreateTailorJob: ({
              required measurementId,
              required designIds,
              required tailorId,
            }) async {
              // TODO: create Tailor-jobs doc, set Orders.status =
              // 'tailor_pending', Sub-orders.deliveryDestination = 'tailor'
              return 'job_id_placeholder';
            },
            onPayTailor: (tailorJobId) async {
              // TODO: Payments.targetType = 'tailor' write
            },
            onTailorSearchExpired: () async {
              // TODO: every Sub-orders.deliveryDestination = 'customer'
            },
            onFetchResumeState: () async {
              // TODO: read-only — look up Orders.tailorSelectionDeadline
              // and the most recent Tailor-jobs doc where orderId ==
              // this order, map onto OrderResumeState. Return null until
              // there's a real order id to query (orderId is still a
              // placeholder above).
              return null;
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedByRetailer;
    final retailerIds = grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: retailerIds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final retailerId = retailerIds[index];
                final lines = grouped[retailerId]!;
                return _buildRetailerPayCard(retailerId, lines);
              },
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildRetailerPayCard(String retailerId, List<CartLine> lines) {
    final retailer = widget.retailers[retailerId];
    final shopName = retailer?.shopName ?? "Unknown Retailer";
    final itemCount = lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final subtotal = lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
    final isPaid = _paidRetailers.contains(retailerId);
    final isPaying = _payingRetailerId == retailerId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaid ? Colors.green.shade800 : Colors.grey.shade200,
          width: isPaid ? 1.5 : 1,
        ),
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
                child: Icon(Icons.storefront_rounded, size: 18, color: Colors.green.shade800),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      "$itemCount ${itemCount == 1 ? 'item' : 'items'}",
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              if (isPaid) Icon(Icons.check_circle, color: Colors.green.shade800, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tk ${subtotal.toStringAsFixed(0)}",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.green.shade900),
              ),
              SizedBox(
                width: 130,
                child: ElevatedButton(
                  onPressed: isPaid || isPaying ? null : () => _payRetailer(retailerId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        isPaid ? Colors.green.shade100 : Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isPaying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isPaid ? "Paid" : "Pay",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total", style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600)),
                  Text(
                    "Tk ${widget.grandTotal.toStringAsFixed(0)}",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _allPaid ? _continueToTailoring : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}