import 'package:flutter/material.dart';
import '../../models/cart_item.dart';
import '../../models/measurement.dart';
import 'package:sketch2stitch/screens/customer/checkout_screen.dart';
import '../../services/cart_service.dart';
import '../../services/measurement_service.dart';
import '../../services/order_service.dart';
import '../../services/user_session.dart';
import 'browsing/browse_shell.dart';
import 'running_orders_screen.dart';
import '../../models/sub_order.dart';
import 'virtual_trial_screen.dart';

// `CartLine` and `RetailerInfo` now live in models/cart_item.dart and are
// built by CartService from `Cart-Items` -> `Products` -> `Retailer`.
// Re-exported here so existing importers (e.g. CheckoutScreen) keep working.
export '../../models/cart_item.dart' show CartLine, RetailerInfo;

/// ─── Cart Screen ────────────────────────────────────────────────────────
///
/// IMPORTANT: this screen NEVER blocks on existing orders. A customer can
/// have any number of orders in progress (visible via the Running Orders
/// entry point below) and still freely browse, add to cart, and check out
/// a brand-new order at any time. Checkout always creates a NEW `Orders`
/// document — it never redirects into an existing order's tailoring flow.

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final MeasurementService _measurementService = MeasurementService();
  final OrderService _orderService = OrderService();

  String get _customerId => UserSession.instance.uid ?? '';

  /// Live cart from Firestore, hydrated with product + retailer details.
  Stream<CartSnapshot>? _cartStream;

  /// Live count of orders still needing a customer decision, for the
  /// Running Orders badge in the app bar.
  Stream<int>? _activeOrderCountStream;

  /// Latest snapshot, kept so checkout and the summary bar can read it
  /// without waiting on the stream again.
  CartSnapshot _snapshot = CartSnapshot.empty;

  /// The customer's single measurement profile, loaded once and handed to
  /// CheckoutScreen. Null until loaded (or when none exists yet).
  Measurement? _measurement;

  /// Ids of lines with an in-flight write, so their row can be disabled
  /// instead of firing duplicate updates.
  final Set<String> _busyLineIds = {};

  @override
  void initState() {
    super.initState();
    _cartStream = _customerId.isEmpty
        ? const Stream<CartSnapshot>.empty()
        : _cartService.streamCart(_customerId);
    _activeOrderCountStream = _customerId.isEmpty
        ? const Stream<int>.empty()
        : _orderService.streamActiveOrderCount(_customerId);
    _loadMeasurement();
  }

  Future<void> _loadMeasurement() async {
    if (_customerId.isEmpty) return;
    try {
      final measurement = await _measurementService.getMeasurement(_customerId);
      if (mounted) setState(() => _measurement = measurement);
    } catch (_) {
      // Checkout surfaces the "no measurements yet" case itself; a failed
      // prefetch shouldn't block the cart from rendering.
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error is CartServiceException
            ? error.message
            : 'Something went wrong. Please try again.'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  /// Runs a cart write, guarding against double taps on the same line and
  /// surfacing service errors as a snackbar.
  Future<void> _runLineAction(String lineId, Future<void> Function() action) async {
    if (_busyLineIds.contains(lineId)) return;
    setState(() => _busyLineIds.add(lineId));
    try {
      await action();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyLineIds.remove(lineId));
    }
  }

  Future<void> _clearCart() async {
    try {
      await _cartService.clearCart(_customerId);
    } catch (e) {
      _showError(e);
    }
  }

  List<CartLine> get _cartLines => _snapshot.lines;
  Map<String, RetailerInfo> get _retailers => _snapshot.retailers;

  Map<String, List<CartLine>> get _groupedByRetailer {
    final Map<String, List<CartLine>> grouped = {};
    for (final line in _cartLines) {
      grouped.putIfAbsent(line.retailerId, () => []).add(line);
    }
    return grouped;
  }

  /// Sub-orders built from the CURRENT cart snapshot. `orderId` is left
  /// blank here on purpose — it doesn't exist yet.
  /// CheckoutService.placeOrder() stamps the real orderId onto the
  /// `Sub-orders` documents it writes once checkout creates the order.
  List<SubOrder> get _subOrders {
    return _groupedByRetailer.entries.map((entry) {
      final retailerId = entry.key;
      final lines = entry.value;
      final subtotal = lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
      final retailer = _retailers[retailerId];

      return SubOrder(
        // Deliberately blank: no `Sub-orders` document exists yet, so there is
        // no id to carry. CheckoutService.placeOrder mints the real ids and
        // returns sub-orders that do carry them — nothing downstream may key
        // off the id until then (grouping here is by retailerId).
        id: '',
        orderId: '',
        retailerId: retailerId,
        status: SubOrderStatus.preparing,
        // Snapshot of the coordinates the delivery charge below was computed
        // from, persisted at checkout so the charge stays auditable.
        deliveryPoint: _snapshot.customerLocation,
        itemsSubtotal: subtotal,
        deliveryCharge: retailer?.deliveryCharge ?? 0,
        deliveryDistanceKm: retailer?.distanceKm,
      );
    }).toList();
  }

  int get _totalItems =>
      _cartLines.fold(0, (sum, line) => sum + line.quantity);

  double get _itemsTotal =>
      _cartLines.fold(0.0, (sum, line) => sum + line.lineTotal);

  // Sum of each represented retailer's flat delivery charge (one charge
  // per Sub-order/retailer, not per line item).
  double get _deliveryTotal => _groupedByRetailer.keys.fold(
        0.0,
        (sum, id) => sum + (_retailers[id]?.deliveryCharge ?? 0),
      );

  double get _grandTotal => _itemsTotal + _deliveryTotal;

  /// Increment is capped at the chosen option's remaining stock — the
  /// service rejects anything above it, so the button is disabled instead.
  void _incrementQuantity(CartLine line) {
    _runLineAction(
      line.id,
      () => _cartService.updateQuantity(line.id, line.quantity + 1),
    );
  }

  /// Decrementing past 1 deletes the line, matching the existing UX.
  void _decrementQuantity(CartLine line) {
    _runLineAction(
      line.id,
      () => _cartService.updateQuantity(line.id, line.quantity - 1),
    );
  }

  void _addMore() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BrowseShell()),
    );
  }

  void _removeLine(CartLine line) {
    _runLineAction(line.id, () => _cartService.removeItem(line.id));
  }

  /// Always goes to CheckoutScreen for the CURRENT cart. Never redirects
  /// into an existing order — that's what Running Orders is for.
  void _checkout() {
    if (_measurement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add your measurements in your profile before checking out.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartLines: _cartLines,
          retailers: _retailers,
          grandTotal: _grandTotal,
          measurement: _measurement!,
          subOrders: _subOrders,
          onOrderPlaced: _clearCart,
        ),
      ),
    );
  }

  void _openRunningOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RunningOrdersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text(
          "My Cart",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          // Entry point to Running Orders. Badge streams the live count of
          // orders still needing a customer decision (Orders.status in
          // OrderService.activeOrderStatuses), so it updates the moment an
          // order is placed or resolved. This never gates the cart — it's
          // purely a navigation shortcut.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: StreamBuilder<int>(
              stream: _activeOrderCountStream,
              builder: (context, snapshot) {
                final activeOrderCount = snapshot.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: _openRunningOrders,
                      icon: const Icon(Icons.local_shipping_outlined),
                      tooltip: "Running Orders",
                    ),
                    if (activeOrderCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$activeOrderCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // Cart body is ALWAYS the cart — never swapped for an "active order"
      // blocking state. Existing orders are reachable only via the icon
      // above, never by hijacking this screen.
      body: StreamBuilder<CartSnapshot>(
        stream: _cartStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Cache the latest snapshot so the summary bar, checkout handler
          // and totals all read the same data the list is rendering.
          _snapshot = snapshot.data ?? CartSnapshot.empty;

          if (_cartLines.isEmpty) return _buildEmptyState();

          final grouped = _groupedByRetailer;
          final retailerIds = grouped.keys.toList();

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: retailerIds.length,
                  itemBuilder: (context, index) {
                    final retailerId = retailerIds[index];
                    final lines = grouped[retailerId]!;
                    return _buildAnimatedRetailerSection(
                      retailerId,
                      lines,
                      index,
                    );
                  },
                ),
              ),
              _buildSummaryBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red.shade200),
            const SizedBox(height: 12),
            Text(
              error is CartServiceException
                  ? error.message
                  : "We couldn't load your cart.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _cartStream = _cartService.streamCart(_customerId);
              }),
              child: const Text("Try again"),
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
          Icon(
            Icons.shopping_cart_outlined,
            size: 56,
            color: Colors.green.shade200,
          ),
          const SizedBox(height: 12),
          const Text(
            "Your cart is empty",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Have an order in progress? Check Running Orders above.",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedRetailerSection(
    String retailerId,
    List<CartLine> lines,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(retailerId),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _buildRetailerSection(retailerId, lines),
    );
  }

  Widget _buildRetailerSection(String retailerId, List<CartLine> lines) {
    final retailer = _retailers[retailerId];
    final shopName = retailer?.shopName ?? "Unknown Retailer";
    final deliveryCharge = retailer?.deliveryCharge ?? 0;
    final distanceKm = retailer?.distanceKm;
    final itemCount = lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final subtotal = lines.fold<double>(0, (sum, l) => sum + l.lineTotal);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  "$itemCount ${itemCount == 1 ? 'item' : 'items'}",
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...lines.map(
            (line) => Column(
              children: [
                _buildProductRow(line),
                if (line != lines.last)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Subtotal",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      "Tk ${subtotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 5),
                        const Text(
                          "Delivery charge",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        // Distance the fee was derived from, so the amount
                        // doesn't look arbitrary.
                        if (distanceKm != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            "(${distanceKm.toStringAsFixed(1)} km)",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      deliveryCharge == 0
                          ? "Free"
                          : "Tk ${deliveryCharge.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Retailer total",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Tk ${(subtotal + deliveryCharge).toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(CartLine line) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: line.image.isEmpty
                  ? Container(
                      color: Colors.green.shade50,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.green.shade200,
                        size: 20,
                      ),
                    )
                  : (line.isAsset
                      ? Image.asset(line.image, fit: BoxFit.cover)
                      : Image.network(line.image, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    line.colorName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Tk ${line.price.toInt()}",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Colors.green.shade900,
                      ),
                    ),
                    _buildQuantitySelector(line),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _busyLineIds.contains(line.id)
                ? null
                : () => _removeLine(line),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(CartLine line) {
    final busy = _busyLineIds.contains(line.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyButton(
            icon: Icons.remove,
            onTap: busy ? null : () => _decrementQuantity(line),
          ),
          SizedBox(
            width: 24,
            child: Text(
              "${line.quantity}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          _qtyButton(
            icon: Icons.add,
            // Never let the customer request more than the retailer has:
            // the service would reject the write anyway.
            onTap: busy || line.atStockLimit
                ? null
                : () => _incrementQuantity(line),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 14,
          color: onTap == null ? Colors.grey.shade400 : Colors.green.shade800,
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Items subtotal",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        "Tk ${_itemsTotal.toStringAsFixed(0)}",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Delivery (${_groupedByRetailer.length} ${_groupedByRetailer.length == 1 ? 'retailer' : 'retailers'})",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        "Tk ${_deliveryTotal.toStringAsFixed(0)}",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Virtual Trial CTA — per whole order (all cart lines) ─────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cartLines.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VirtualTrialScreen(
                                // Full-size images of the exact colour options
                                // the customer chose — not the 64pt cart
                                // thumbnails, which would upscale badly in the
                                // trial's grid and full-screen viewer.
                                prefillAssetImages: _cartLines
                                    .map((l) => l.fullImage)
                                    .where((p) => p.isNotEmpty)
                                    .toList(),
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.green),
                  label: const Text(
                    "See how you'll look with this!",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$_totalItems ${_totalItems == 1 ? 'item' : 'items'}",
                            style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          _addMoreChip(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Tk ${_grandTotal.toStringAsFixed(0)}",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green.shade900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // "Checkout" — always starts a NEW order from the current
                // cart. Distinct in meaning (and can be styled distinctly)
                // from RunningOrdersScreen's "Continue" button, which
                // resumes an EXISTING order instead.
                ElevatedButton(
                  onPressed: _cartLines.isEmpty ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addMoreChip() {
    return GestureDetector(
      onTap: _addMore,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade800.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 12, color: Colors.white),
            SizedBox(width: 3),
            Text(
              "Add More",
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}