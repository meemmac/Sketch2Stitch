import 'package:flutter/material.dart';
import '../../models/measurement.dart';
import 'package:sketch2stitch/screens/customer/checkout_screen.dart';

/// ─── Local Cart Models ──────────────────────────────────────────────────
///
/// These mirror the DB shape (`Order-Items`: productId, quantity, optionId)
/// but are flattened/denormalized here for display, since the cart screen
/// needs product + retailer + color-option details joined together.
/// Once wired to the backend, `CartLine` would be built by joining
/// `Order-Items` -> `Products` (for name/colorOptions/retailerId) ->
/// `Retailer` (for shopName), instead of using the mock data below.

class CartLine {
  final String productId;
  final int optionId;
  int quantity;

  final String retailerId;
  final String productName;
  final String colorName;
  final String image;
  final bool isAsset;
  final double price;

  CartLine({
    required this.productId,
    required this.optionId,
    required this.quantity,
    required this.retailerId,
    required this.productName,
    required this.colorName,
    required this.image,
    required this.price,
    this.isAsset = false,
  });

  double get lineTotal => price * quantity;
}

class RetailerInfo {
  final String id;
  final String shopName;

  const RetailerInfo({required this.id, required this.shopName});
}

/// ─── Cart Screen ────────────────────────────────────────────────────────

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Mock `Retailer` collection lookup. Replace with a real fetch keyed by
  // Products.retailerId once the backend is connected.
  final Map<String, RetailerInfo> _retailers = {
    "RET001": const RetailerInfo(id: "RET001", shopName: "Elegant Fabrics Ltd."),
    "RET002": const RetailerInfo(id: "RET002", shopName: "Dhaka Silk House"),
  };

  // Mock single measurement profile. Replace with a real fetch by
  // customerId once the backend is connected — one customer, one profile.
  final Measurement _measurement = Measurement(
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

  void _clearCart() {
    setState(() => _cartLines.clear());
  }

  // Mock cart lines, standing in for joined Order-Items + Products data.
  final List<CartLine> _cartLines = [
    CartLine(
      productId: "PROD001",
      optionId: 1,
      quantity: 2,
      retailerId: "RET001",
      productName: "Premium Egyptian Cotton",
      colorName: "White",
      image: 'assets/images/fab.jpg',
      isAsset: true,
      price: 650,
    ),
    CartLine(
      productId: "PROD001",
      optionId: 2,
      quantity: 1,
      retailerId: "RET001",
      productName: "Premium Egyptian Cotton",
      colorName: "Beige",
      image: 'assets/images/fab2.jpg',
      isAsset: true,
      price: 680,
    ),
    CartLine(
      productId: "PROD002",
      optionId: 1,
      quantity: 1,
      retailerId: "RET002",
      productName: "Golden Silk Blend",
      colorName: "Gold",
      image: 'assets/images/silk.jpg',
      isAsset: true,
      price: 1800,
    ),
    CartLine(
      productId: "PROD003",
      optionId: 1,
      quantity: 3,
      retailerId: "RET002",
      productName: "Printed Scarf",
      colorName: "Multi",
      image: 'assets/images/saree.jpg',
      isAsset: true,
      price: 380,
    ),
  ];

  Map<String, List<CartLine>> get _groupedByRetailer {
    final Map<String, List<CartLine>> grouped = {};
    for (final line in _cartLines) {
      grouped.putIfAbsent(line.retailerId, () => []).add(line);
    }
    return grouped;
  }

  int get _totalItems =>
      _cartLines.fold(0, (sum, line) => sum + line.quantity);

  double get _grandTotal =>
      _cartLines.fold(0.0, (sum, line) => sum + line.lineTotal);

  void _incrementQuantity(CartLine line) {
    setState(() => line.quantity++);
  }

  void _decrementQuantity(CartLine line) {
    setState(() {
      if (line.quantity > 1) {
        line.quantity--;
      } else {
        _cartLines.remove(line);
      }
    });
  }

  void _removeLine(CartLine line) {
    setState(() => _cartLines.remove(line));
  }

  void _checkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartLines: _cartLines,
          retailers: _retailers,
          grandTotal: _grandTotal,
          measurement: _measurement,
          onOrderPlaced: _clearCart,
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
        title: const Text(
          "My Cart",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _cartLines.isEmpty
          ? _buildEmptyState()
          : Column(
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
          // Retailer header
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

          // Product lines
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

          // Retailer subtotal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade900,
                  ),
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
                        // NOTE: swap to Image.network(line.image) once the
                        // backend serves real product image URLs.
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
            onTap: () => _removeLine(line),
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
            onTap: () => _decrementQuantity(line),
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
            onTap: () => _incrementQuantity(line),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 14, color: Colors.green.shade800),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
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
                  Text(
                    "$_totalItems ${_totalItems == 1 ? 'item' : 'items'}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Tk ${_grandTotal.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _cartLines.isEmpty ? null : _checkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Checkout",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}