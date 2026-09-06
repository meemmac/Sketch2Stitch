import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_screen.dart';
import 'tailoring_setup_screen.dart';
import '../../models/measurement.dart';
import 'tailoring_callbacks.dart';
import '../../models/sub_order.dart';
import '../../services/bkash_service.dart';
import 'bkash_payment_screen.dart';
import '../../services/auth_service.dart';
import '../../services/checkout_service.dart';
import '../../services/user_session.dart';
import '../../models/user_role.dart';
import '../../utils/validation_utils.dart';
import '../../widgets/dashboard_drawer.dart';
import '../../widgets/top_feedback_banner.dart';

/// ─── Checkout Screen ────────────────────────────────────────────────────
///
/// Pays each retailer for the CURRENT cart snapshot, then starts exactly
/// one brand-new OrderRecord and hands off to TailoringSetupScreen for
/// THAT order. Never touches any other existing order.
class CheckoutScreen extends StatefulWidget {
  final List<CartLine> cartLines;
  final Map<String, RetailerInfo> retailers;
  final double grandTotal;
  /// Nullable on purpose: fabric can be bought without any tailoring, so
  /// the cart no longer forces a complete measurement profile before
  /// checkout. TailoringSetupScreen prompts for measurements itself if the
  /// customer goes on to pick a tailor.
  final Measurement? measurement;
  final List<SubOrder> subOrders;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.cartLines,
    required this.retailers,
    required this.grandTotal,
    this.measurement,
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

  String get _customerId => UserSession.instance.uid ?? '';

  /// Payments already taken survive leaving this screen. Without this the
  /// whole paid state lived in `_paidRetailers`, so a customer who paid but
  /// backed out before pressing Continue was asked to pay a second time when
  /// they re-opened checkout — with the first payment already charged.
  static const String _paidStateKey = 'checkout_paid_v1';

  /// How long a completed-but-unused payment stays resumable. Long enough to
  /// cover coming back to finish the order, short enough that deliberately
  /// re-buying an identical cart later isn't mistaken for the old payment.
  static const Duration _paidStateTtl = Duration(hours: 2);

  @override
  void initState() {
    super.initState();
    _restorePaidState();
  }

  /// Identifies one retailer's exact payable: same customer, same retailer,
  /// same lines, same amount. Any cart change invalidates the saved payment,
  /// because the amount owed is no longer the amount that was paid.
  String _signatureFor(String retailerId) {
    final lines = widget.cartLines
        .where((l) => l.retailerId == retailerId)
        .map((l) => '${l.productId}:${l.optionId}:${l.quantity}')
        .toList()
      ..sort();
    final subtotal = widget.cartLines
        .where((l) => l.retailerId == retailerId)
        .fold<double>(0, (sum, l) => sum + l.lineTotal);
    final amount = subtotal + _deliveryChargeFor(retailerId);
    return '$_customerId|$retailerId|${lines.join(',')}|'
        '${amount.toStringAsFixed(2)}';
  }

  Future<Map<String, dynamic>> _readPaidState(SharedPreferences prefs) async {
    final raw = prefs.getString(_paidStateKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      // Drop anything past the resume window so stale entries can never mark
      // a fresh cart as already paid.
      final cutoff =
          DateTime.now().subtract(_paidStateTtl).millisecondsSinceEpoch;
      return Map<String, dynamic>.fromEntries(
        decoded.entries
            .where((e) => e.value is Map && (e.value['ts'] as int? ?? 0) > cutoff)
            .map((e) => MapEntry(e.key as String, e.value)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _restorePaidState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = await _readPaidState(prefs);
      if (state.isEmpty || !mounted) return;

      final restored = <String, String>{};
      for (final retailerId in _groupedByRetailer.keys) {
        final entry = state[_signatureFor(retailerId)];
        if (entry is Map) {
          restored[retailerId] = (entry['trxId'] as String?) ?? '';
        }
      }
      if (restored.isEmpty || !mounted) return;

      setState(() {
        _paidRetailers.addAll(restored.keys);
        _trxIds.addAll(restored);
      });
    } catch (e) {
      debugPrint('[Checkout] Could not restore paid state: $e');
    }
  }

  Future<void> _rememberPayment(String retailerId, String trxId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = await _readPaidState(prefs);
      state[_signatureFor(retailerId)] = {
        'trxId': trxId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_paidStateKey, jsonEncode(state));
    } catch (e) {
      debugPrint('[Checkout] Could not persist paid state: $e');
    }
  }

  /// Called once the order exists in Firestore — these payments now belong to
  /// a real order and must not be reused for a future cart.
  Future<void> _forgetPayments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = await _readPaidState(prefs);
      for (final retailerId in _groupedByRetailer.keys) {
        state.remove(_signatureFor(retailerId));
      }
      await prefs.setString(_paidStateKey, jsonEncode(state));
    } catch (e) {
      debugPrint('[Checkout] Could not clear paid state: $e');
    }
  }

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
      final lines =
          widget.cartLines.where((l) => l.retailerId == retailerId).toList();

      // Stock can move between opening the cart and paying, so re-check this
      // retailer's lines before taking any money. placeOrder() re-validates
      // atomically at the end too — this is purely so the customer finds out
      // before they pay rather than after.
      final problems = await _checkoutService.validateStock(
        lines
            .map((l) => OrderItemInput(
                  productId: l.productId,
                  optionId: l.optionId,
                  quantity: l.quantity,
                ))
            .toList(),
      );

      if (!mounted) return;
      if (problems.isNotEmpty) {
        setState(() => _payingRetailerId = null);
        _showPaymentError(problems.first);
        return;
      }

      final subtotal = lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
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

      // Persist BEFORE touching the UI, so the record of the charge exists
      // even if the customer leaves the moment it succeeds.
      await _rememberPayment(retailerId, executed.trxID);

      if (!mounted) return;
      setState(() {
        _paidRetailers.add(retailerId);
        // Kept so the Payments record written at order creation carries the
        // real bKash transaction id rather than an empty field.
        _trxIds[retailerId] = executed.trxID;
        _payingRetailerId = null;
      });
      AppFeedback.show(context, 'Payment confirmed successfully');
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
    AppFeedback.show(
      context,
      message,
      isError: true,
      duration: const Duration(seconds: 5),
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
      // Step 1: write the whole order in ONE transaction — Orders, one
      // Sub-order per retailer with its Order-Items, one Payments record per
      // retailer, and the matching stock decrements. Stock is re-validated
      // inside that transaction, so the last unit can't be sold twice and a
      // failure part-way can't leave a paid-for order half-written.
      final placed = await _checkoutService.placeOrder(
        customerId: _customerId,
        subOrders: [
          for (final subOrder in widget.subOrders)
            SubOrderInput(
              retailerId: subOrder.retailerId,
              itemsSubtotal: subOrder.itemsSubtotal,
              deliveryCharge: subOrder.deliveryCharge,
              deliveryDistanceKm: subOrder.deliveryDistanceKm,
              deliveryPoint: subOrder.deliveryPoint,
              transactionId: _trxIds[subOrder.retailerId],
              items: widget.cartLines
                  .where((l) => l.retailerId == subOrder.retailerId)
                  .map((l) => OrderItemInput(
                        productId: l.productId,
                        optionId: l.optionId,
                        quantity: l.quantity,
                      ))
                  .toList(),
            ),
        ],
      );

      // Step 2: the cart has become an order — clear it. Delegated to the
      // cart screen's own handler so there's one place that owns clearing.
      // The saved payments go with it: they're recorded on the order now.
      await _forgetPayments();
      widget.onOrderPlaced();

      // Step 3: hand straight off to the tailoring stage against the real
      // Firestore documents placeOrder() just wrote — no local mirror, so
      // the state survives a restart and the tailor can actually see the
      // job the customer is about to create.
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TailoringSetupScreen(
            orderId: placed.order.id,
            orderDate: placed.order.orderDate,
            savedMeasurements:
                widget.measurement == null ? const [] : [widget.measurement!],
            subOrders: placed.subOrders,
            callbacks: buildTailoringCallbacks(placed.order.id),
          ),
        ),
      );
    } on CheckoutServiceException catch (e) {
      if (!mounted) return;
      // Nothing was written — the transaction rolled back in full — so the
      // customer can fix their cart and retry without a duplicate order.
      _showPaymentError(e.message);
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
            // One extra leading item: the delivery-contact card plus the
            // note explaining that these payments are for fabric only.
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: retailerIds.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) return _buildDeliveryDetailsCard();
                final retailerId = retailerIds[index - 1];
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

  /// Where this order will be delivered and who to call about it — read
  /// straight off the signed-in profile, editable in place so the customer
  /// doesn't have to leave checkout to correct a wrong number or address.
  Widget _buildDeliveryDetailsCard() {
    return ValueListenableBuilder<DrawerProfileData?>(
      valueListenable: UserSession.instance.currentProfile,
      builder: (context, profile, _) {
        final phone = (profile?.phone ?? '').trim();
        final address = (profile?.address ?? '').trim();

        return Column(
          children: [
            Container(
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
                        child: Icon(Icons.person_pin_circle_outlined,
                            size: 18, color: Colors.green.shade800),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Delivery details",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editDeliveryDetails(profile),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text("Edit",
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade800,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _contactRow(
                    Icons.phone_outlined,
                    phone.isEmpty ? "No phone number added" : phone,
                    isMissing: phone.isEmpty,
                  ),
                  const SizedBox(height: 8),
                  _contactRow(
                    Icons.location_on_outlined,
                    address.isEmpty ? "No delivery address added" : address,
                    isMissing: address.isEmpty,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You are paying the retailers only",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "These payments cover the fabrics and elements "
                          "from the retailers below, plus their delivery. "
                          "Tailoring charges are not included — you pay your "
                          "tailor separately after choosing them in the next "
                          "step.",
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.brown.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _contactRow(IconData icon, String text, {bool isMissing = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: isMissing ? Colors.red.shade400 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  /// Edits phone/address on the customer's own profile document — the same
  /// fields the drawer's profile editor writes, so the two stay in sync.
  Future<void> _editDeliveryDetails(DrawerProfileData? profile) async {
    if (profile == null) return;
    final phoneController = TextEditingController(text: profile.phone);
    final addressController = TextEditingController(text: profile.address);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Text("Delivery details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone number",
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Delivery address",
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    // The TextFields are still mounted while the dialog's close animation
    // plays, so disposing the controllers the moment showDialog() returns
    // makes Flutter throw "A TextEditingController was used after being
    // disposed". Let the transition finish first.
    Future.delayed(const Duration(milliseconds: 500), () {
      phoneController.dispose();
      addressController.dispose();
    });

    if (saved != true || !mounted) return;

    if (!ValidationUtils.isValidPhone(phone)) {
      _showPaymentError('Please enter a valid phone number.');
      return;
    }
    if (address.isEmpty) {
      _showPaymentError('Please enter a delivery address.');
      return;
    }
    if (_customerId.isEmpty) {
      _showPaymentError('Please sign in again to update your details.');
      return;
    }

    try {
      await AuthService().updateProfile(_customerId, UserRole.customer, {
        'phone': phone,
        'address': address,
      });
      UserSession.instance.currentProfile.value =
          profile.copyWith(phone: phone, address: address);
      if (!mounted) return;
      AppFeedback.show(context, 'Delivery details updated');
    } catch (e) {
      debugPrint('[Checkout] Could not update delivery details: $e');
      if (!mounted) return;
      _showPaymentError("Couldn't save your details. Please try again.");
    }
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