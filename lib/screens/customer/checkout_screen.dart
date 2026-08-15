import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'cart_screen.dart';
import 'tailoring_setup_screen.dart';
import '../../models/measurement.dart';
import 'order_session.dart';
import 'tailoring_callbacks.dart';
import '../../models/sub_order.dart';
import '../../services/bkash_service.dart';
import 'bkash_payment_screen.dart';
import '../../services/checkout_service.dart';
import '../../services/user_session.dart';
import '../../services/cart_service.dart';
import '../../models/order.dart' show PaymentStatus;

/// ─── Checkout Screen ────────────────────────────────────────────────────
///
/// Pays each retailer for the CURRENT cart snapshot, then starts exactly
/// one brand-new OrderRecord and hands off to TailoringSetupScreen for
/// THAT order. Never touches any other existing order.
class CheckoutScreen extends StatefulWidget {
  final List<CartLine> cartLines;
  final Map<String, RetailerInfo> retailers;
  final double grandTotal;
  final Measurement measurement;
  final List<SubOrder> subOrders;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.cartLines,
    required this.retailers,
    required this.grandTotal,
    required this.measurement,
    required this.subOrders,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Set<String> _paidRetailers = {};

  /// bKash transaction id per retailer, captured on a successful execute so
  /// it can be written onto that retailer's `Payments` record.
  final Map<String, String> _trxIds = {};

  String? _payingRetailerId;
  bool _isPlacingOrder = false;

  final CheckoutService _checkoutService = CheckoutService();
  final CartService _cartService = CartService();

  String get _customerId => UserSession.instance.uid ?? '';

  Map<String, List<CartLine>> get _groupedByRetailer {
    final Map<String, List<CartLine>> grouped = {};
    for (final line in widget.cartLines) {
      grouped.putIfAbsent(line.retailerId, () => []).add(line);
    }
    return grouped;
  }

  double _deliveryChargeFor(String retailerId) =>
      widget.retailers[retailerId]?.deliveryCharge ?? 0;

  bool get _allPaid {
    final ids = _groupedByRetailer.keys;
    if (ids.isEmpty) return false;
    return ids.every((id) => _paidRetailers.contains(id));
  }

  Future<void> _payRetailer(String retailerId) async {
    setState(() => _payingRetailerId = retailerId);
    try {
      final subtotal = widget.cartLines
          .where((l) => l.retailerId == retailerId)
          .fold<double>(0, (sum, l) => sum + l.lineTotal);
      final amount = subtotal + _deliveryChargeFor(retailerId);

      // Step 1 + 2: grant token, create payment — get bkashURL.
      final pending = await BkashService.instance.initiatePayment(
        amount: amount,
        invoicePrefix: 'RET_${retailerId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}',
      );

      if (!mounted) return;

      // Step 3: open bKash in an in-app WebView (auto-closes on redirect).
      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => BkashPaymentScreen(bkashURL: pending.bkashURL),
        ),
      );

      if (!mounted) return;
      if (completed != true) {
        // User closed the WebView without completing payment.
        setState(() => _payingRetailerId = null);
        return;
      }

      // Step 4: execute payment — confirms the transaction.
      final executed = await BkashService.instance.executePayment(
        paymentID: pending.paymentID,
        idToken: pending.idToken,
      );

      if (!mounted) return;
      setState(() {
        _paidRetailers.add(retailerId);
        // Kept so the Payments record written at order creation carries the
        // real bKash transaction id rather than an empty field.
        _trxIds[retailerId] = executed.trxID;
        _payingRetailerId = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Payment confirmed successfully'),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    } on BkashException catch (e) {
      if (!mounted) return;
      _showPaymentError(e.message);
    } catch (e, st) {
      // Log the real error so we can diagnose device-specific failures
      // (e.g. SSL handshake, DNS lookup, socket timeout, etc.)
      debugPrint('[BkashPayment] Unexpected error: $e\n$st');
      if (!mounted) return;
      _showPaymentError(
        kDebugMode
            ? 'Payment error: $e'
            : 'Payment could not be initiated. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _payingRetailerId = null);
    }
  }

  void _showPaymentError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  /// Creates the order in Firestore, clears the cart, starts a local
  /// OrderRecord, and navigates into that order's tailoring setup.
  Future<void> _continueToTailoring() async {
    if (_customerId.isEmpty) {
      _showPaymentError('Please sign in again before placing your order.');
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      // Step 1: the parent Orders document. createOrder() stamps
      // customerId, orderDate and status (awaiting_confirmation) itself.
      // tailorSelectionDeadline is deliberately NOT set here — the customer
      // hasn't decided whether they even want a tailor yet; that deadline is
      // written later by onContinueToTailoring in TailoringSetupScreen.
      final fireOrder = await _checkoutService.createOrder(_customerId, {});

      // Step 2: one Sub-order per retailer, plus its Order-Items.
      final fireSubOrders = <SubOrder>[];
      for (final subOrder in widget.subOrders) {
        final fireSubOrder = await _checkoutService.createSubOrder(
          fireOrder.id,
          subOrder.retailerId,
          {
            'itemsSubtotal': subOrder.itemsSubtotal,
            'deliveryCharge': subOrder.deliveryCharge,
            'deliveryDistanceKm': subOrder.deliveryDistanceKm,
            // 'pending' until tailoring setup decides whether the fabric
            // ships to the customer or straight to the tailor.
            'deliveryDestination': SubOrderDeliveryDestination.pending.name,
          },
        );

        final items = widget.cartLines
            .where((l) => l.retailerId == subOrder.retailerId)
            .map((l) => OrderItemInput(
                  productId: l.productId,
                  optionId: l.optionId,
                  quantity: l.quantity,
                ))
            .toList();

        if (items.isNotEmpty) {
          await _checkoutService.createOrderItems(fireSubOrder.id, items);
        }

        fireSubOrders.add(fireSubOrder);
      }

      // Step 3: one Payments record per retailer — this screen charges each
      // retailer separately through bKash, and Payments.targetType only
      // admits 'retailer' or 'tailor'.
      for (final subOrder in widget.subOrders) {
        await _checkoutService.recordPayment(fireOrder.id, {
          'method': PaymentMethod.mobileBanking.toValue,
          'amount': subOrder.itemsSubtotal + subOrder.deliveryCharge,
          'itemsAmount': subOrder.itemsSubtotal,
          'deliveryAmount': subOrder.deliveryCharge,
          'targetType': PaymentTargetType.retailer.toValue,
          'targetId': subOrder.retailerId,
          'transactionId': _trxIds[subOrder.retailerId],
          'status': PaymentStatus.completed.toValue,
        });
      }

      // Step 4: the cart has become an order — clear it. Delegated to the
      // cart screen's own handler so there's one place that owns clearing.
      widget.onOrderPlaced();

      // Step 5: mirror into the local session store, reusing the Firestore
      // order id so the tailoring flow stays attached to the real document.
      final order = OrderStore.instance.startOrder(
        fireSubOrders,
        orderId: fireOrder.id,
        orderDate: fireOrder.orderDate,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TailoringSetupScreen(
            orderId: order.orderId,
            orderDate: order.orderDate,
            savedMeasurements: [widget.measurement],
            subOrders: order.subOrders,
            callbacks: buildTailoringCallbacks(order.orderId),
          ),
        ),
      );
    } on CheckoutServiceException catch (e) {
      if (!mounted) return;
      _showPaymentError('Order creation failed: ${e.message}');
    } catch (e) {
      debugPrint('[Checkout] Order creation error: $e');
      if (!mounted) return;
      _showPaymentError('Could not place your order. Please try again.');
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
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
    final deliveryCharge = _deliveryChargeFor(retailerId);
    final payable = subtotal + deliveryCharge;
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _breakdownRow("Items subtotal", "Tk ${subtotal.toStringAsFixed(0)}"),
                const SizedBox(height: 4),
                _breakdownRow(
                  "Delivery charge",
                  deliveryCharge == 0 ? "Free" : "Tk ${deliveryCharge.toStringAsFixed(0)}",
                  icon: Icons.local_shipping_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Payable",
                    style: TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "Tk ${payable.toStringAsFixed(0)}",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.green.shade900),
                  ),
                ],
              ),
              SizedBox(
                width: 130,
                child: ElevatedButton(
                  onPressed: isPaid || isPaying ? null : () => _payRetailer(retailerId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isPaid ? Colors.green.shade100 : Colors.grey.shade300,
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

  Widget _breakdownRow(String label, String value, {IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ],
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
                  const Text("Total (incl. delivery)", style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600)),
                  Text(
                    "Tk ${widget.grandTotal.toStringAsFixed(0)}",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: (_allPaid && !_isPlacingOrder) ? _continueToTailoring : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: _isPlacingOrder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}