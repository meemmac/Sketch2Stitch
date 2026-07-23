import 'package:flutter/material.dart';
import '../../../models/measurement.dart';
import '../browsing/browse_shell.dart';
import 'reviews_screen.dart';

enum OrderDeliveryDestination { retailer, tailor }

enum TailorStatus { notAssigned, pending, cancelled, confirmed }

class OrderItem {
  final String name;
  final int quantity;
  final String imagePath;
  final String color;
  final String description;
  final String? itemComment;
  final bool canWash;
  final bool canBleach;
  final bool canDryClean;
  final bool canTumbleDry;
  final String ironLevel;
  final double price;

  // New fields for Tailor reference
  final OrderDeliveryDestination destination;
  final String? measurementRefImage;
  final String? tailorInstructions;
  final TailorStatus? tailorStatus;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.imagePath,
    required this.color,
    required this.price,
    this.description = "Premium quality material with excellent durability and comfort.",
    this.itemComment,
    this.canWash = true,
    this.canBleach = false,
    this.canDryClean = true,
    this.canTumbleDry = true,
    this.ironLevel = "Medium",
    this.destination = OrderDeliveryDestination.retailer,
    this.measurementRefImage,
    this.tailorInstructions,
    this.tailorStatus,
  });
}

class CustomerOrder {
  final String id;
  final String retailerName;
  final List<OrderItem> items;
  final double amount;
  final DateTime orderDate;
  DateTime? deliveryDate;
  String status;
  bool isDelivered;
  final String? review;
  final double? rating;
  final String? tailorReview;
  final double? tailorRating;
  final String deliveryAddress;

  CustomerOrder({
    required this.id,
    required this.retailerName,
    required this.items,
    required this.amount,
    required this.orderDate,
    required this.status,
    required this.isDelivered,
    required this.deliveryAddress,
    this.deliveryDate,
    this.review,
    this.rating,
    this.tailorReview,
    this.tailorRating,
  });

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}

enum OrderFilterPreset { last3Months, last6Months, custom }

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderFilterPreset _filterPreset = OrderFilterPreset.last3Months;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _showOngoing = true;

  final Color primaryGreen = const Color(0xFF4F7942);

  final Measurement _mockMeasurement = Measurement(
    id: "meas_123",
    customerId: "cust_456",
    upperBustCircumference: 34.5,
    roundShoulderCircumference: 40.0,
    hipsCircumference: 38.0,
    underBustCircumference: 32.0,
    bustCircumference: 36.0,
    waist: 28.5,
    shoulderToKnee: 37.0,
    shoulderToUnderBust: 13.0,
    shoulderToBust: 10.5,
    thigh: 22.0,
    knee: 15.0,
    ankle: 9.5,
    waistToAnkle: 40.0,
    shoulderToAnkle: 55.0,
  );

  void _showMeasurements() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              "My Measurements",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Current body measurements used for this order.",
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _measurementTile("Upper Bust", _mockMeasurement.upperBustCircumference),
                  _measurementTile("Bust", _mockMeasurement.bustCircumference),
                  _measurementTile("Under Bust", _mockMeasurement.underBustCircumference),
                  _measurementTile("Round Shoulder", _mockMeasurement.roundShoulderCircumference),
                  _measurementTile("Waist", _mockMeasurement.waist),
                  _measurementTile("Hips", _mockMeasurement.hipsCircumference),
                  _measurementTile("Shoulder to Bust", _mockMeasurement.shoulderToBust),
                  _measurementTile("Shoulder to Under Bust", _mockMeasurement.shoulderToUnderBust),
                  _measurementTile("Shoulder to Knee", _mockMeasurement.shoulderToKnee),
                  _measurementTile("Shoulder to Ankle", _mockMeasurement.shoulderToAnkle),
                  _measurementTile("Waist to Ankle", _mockMeasurement.waistToAnkle),
                  _measurementTile("Thigh", _mockMeasurement.thigh),
                  _measurementTile("Knee", _mockMeasurement.knee),
                  _measurementTile("Ankle", _mockMeasurement.ankle),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _measurementTile(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Text(
              "$value in",
              style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getTailorStatusText(TailorStatus status) {
    switch (status) {
      case TailorStatus.notAssigned:
        return "Tailor not assigned";
      case TailorStatus.pending:
        return "Not yet confirmed by tailor";
      case TailorStatus.cancelled:
        return "Cancelled by tailor";
      case TailorStatus.confirmed:
        return "Confirmed";
    }
  }

  Color _getTailorStatusColor(TailorStatus status) {
    switch (status) {
      case TailorStatus.notAssigned:
        return Colors.grey.shade600;
      case TailorStatus.pending:
        return Colors.orange.shade800;
      case TailorStatus.cancelled:
        return Colors.red.shade800;
      case TailorStatus.confirmed:
        return primaryGreen;
    }
  }

  Widget _tailorStatusBadge(TailorStatus status) {
    final color = _getTailorStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        _getTailorStatusText(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  late final List<CustomerOrder> _orders = <CustomerOrder>[
    CustomerOrder(
      id: "ORD-9654",
      retailerName: "Zaroon Fabrics",
      amount: 4500,
      orderDate: DateTime.now().subtract(const Duration(days: 2)),
      status: "On Hold",
      isDelivered: false,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      items: [
        const OrderItem(
          name: "Embroidered Lawn",
          quantity: 2,
          price: 4500,
          imagePath: "assets/images/fabrics_rolled.jpg",
          color: "Emerald Green",
          destination: OrderDeliveryDestination.tailor,
          tailorStatus: TailorStatus.cancelled,
          measurementRefImage: "assets/images/ref4.jpg",
          tailorInstructions: "The gher of the kameez should be just like the reference picture give.",
        ),
      ],
    ),
    CustomerOrder(
      id: "ORD-9543",
      retailerName: "Silk & Cotton",
      amount: 3200,
      orderDate: DateTime.now().subtract(const Duration(days: 1)),
      status: "Processing",
      isDelivered: false,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      items: [
        const OrderItem(
          name: "Premium Cotton",
          quantity: 2,
          price: 3200,
          imagePath: "assets/images/denim.jpg",
          color: "Navy Blue",
          destination: OrderDeliveryDestination.retailer,
          tailorStatus: TailorStatus.confirmed,
        ),
      ],
    ),
    CustomerOrder(
      id: "ORD-9921",
      retailerName: "Zaroon Fabrics",
      amount: 4500,
      orderDate: DateTime.now().subtract(const Duration(days: 5)),
      status: "Preparing",
      isDelivered: false,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      items: [
        const OrderItem(
          name: "Premium Linen",
          quantity: 3,
          price: 3000,
          imagePath: "assets/images/fabrics_rolled.jpg",
          color: "Cream",
          description: "High-quality linen fabric for summer wear.",
          destination: OrderDeliveryDestination.tailor,
          tailorStatus: TailorStatus.pending,
          measurementRefImage: "assets/images/ref1.jpg",
          tailorInstructions: "Please use this linen for the pants. Ensure the length is precisely 42 inches as per my saved measurements and just like the reference picture.",
        ),
        const OrderItem(
          name: "Cotton Thread Set",
          quantity: 1,
          price: 1500,
          imagePath: "assets/images/denim.jpg",
          color: "Mixed",
        ),
      ],
    ),
    CustomerOrder(
      id: "ORD-9854",
      retailerName: "Heritage Silk",
      amount: 8200,
      orderDate: DateTime.now().subtract(const Duration(days: 20)),
      status: "Packed",
      isDelivered: false,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      items: [
        const OrderItem(
          name: "Pure Rajshahi Silk",
          quantity: 1,
          price: 8200,
          imagePath: "assets/images/silk.jpg",
          color: "Deep Red",
          description: "Traditional Rajshahi silk with gold border.",
          destination: OrderDeliveryDestination.tailor,
          tailorStatus: TailorStatus.notAssigned,
          measurementRefImage: "assets/images/ref3.jpg",
          tailorInstructions: "Use this silk for a traditional Saree blouse. Reference the attached image for the back design.",
        ),
      ],
    ),
    CustomerOrder(
      id: "ORD-9712",
      retailerName: "FabriCo",
      amount: 3200,
      orderDate: DateTime.now().subtract(const Duration(days: 45)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 38)),
      status: "Delivered",
      isDelivered: true,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      review: "Excellent quality and fast delivery. Very satisfied!",
      rating: 5.0,
      tailorReview: "The stitching is perfect and fits me exactly as I wanted. Highly recommended!",
      tailorRating: 4.8,
      items: [
        const OrderItem(
          name: "Printed Voile",
          quantity: 4,
          price: 3200,
          imagePath: "assets/images/gorgeous.jpg",
          color: "Floral Blue",
          destination: OrderDeliveryDestination.tailor,
          tailorStatus: TailorStatus.confirmed,
          measurementRefImage: "assets/images/ref2.jpg",
          tailorInstructions: "Create a summer kurti. Use the printed patterns for the sleeves as shown in the reference picture.",
        ),
      ],
    ),
    CustomerOrder(
      id: "ORD-9421",
      retailerName: "Bismillah Fabrics",
      amount: 2800,
      orderDate: DateTime.now().subtract(const Duration(days: 60)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 52)),
      status: "Delivered",
      isDelivered: true,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      review: "Good quality fabric, but shipping took a bit longer than expected.",
      rating: 4.0,
      items: [
        const OrderItem(
          name: "Soft Georgette",
          quantity: 3,
          price: 2800,
          imagePath: "assets/images/fabrics_rolled.jpg",
          color: "Peach",
          destination: OrderDeliveryDestination.retailer,
        ),
      ],
    ),
    CustomerOrder(
      id: "ORD-9310",
      retailerName: "Style Hub",
      amount: 6500,
      orderDate: DateTime.now().subtract(const Duration(days: 90)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 82)),
      status: "Delivered",
      isDelivered: true,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      review: "The silk is absolutely stunning. Worth every penny!",
      rating: 5.0,
      tailorReview: "Best tailor experience ever. The fit is top-notch.",
      tailorRating: 5.0,
      items: [
        const OrderItem(
          name: "Banarasi Silk",
          quantity: 1,
          price: 6500,
          imagePath: "assets/images/silk.jpg",
          color: "Magenta",
          destination: OrderDeliveryDestination.tailor,
          tailorStatus: TailorStatus.confirmed,
          measurementRefImage: "assets/images/ref1.jpg",
          tailorInstructions: "Please make a classic lehenga blouse with a high neck.",
        ),
      ],
    ),
  ];

  DateTime get _startDate {
    final today = DateTime.now();
    switch (_filterPreset) {
      case OrderFilterPreset.last3Months:
        return DateTime(today.year, today.month - 3, today.day);
      case OrderFilterPreset.last6Months:
        return DateTime(today.year, today.month - 6, today.day);
      case OrderFilterPreset.custom:
        return _customStartDate ?? DateTime(today.year, today.month - 3, today.day);
    }
  }

  DateTime get _endDate {
    final today = DateTime.now();
    if (_filterPreset == OrderFilterPreset.custom && _customEndDate != null) {
      return _customEndDate!;
    }
    return DateTime(today.year, today.month, today.day, 23, 59, 59);
  }

  String get _filterLabel {
    switch (_filterPreset) {
      case OrderFilterPreset.last3Months:
        return "Last 3 months";
      case OrderFilterPreset.last6Months:
        return "Last 6 months";
      case OrderFilterPreset.custom:
        if (_customStartDate == null || _customEndDate == null) return "Custom dates";
        return "${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}";
    }
  }

  List<CustomerOrder> get _filteredOrders {
    return _orders.where((order) {
      final date = order.orderDate;
      return !date.isBefore(_startDate) && !date.isAfter(_endDate);
    }).toList();
  }

  List<CustomerOrder> get _ongoingOrders => _filteredOrders.where((o) => !o.isDelivered).toList();
  List<CustomerOrder> get _deliveredOrders => _filteredOrders.where((o) => o.isDelivered).toList();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.08 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "My Orders",
                    style: TextStyle(
                      fontSize: screenWidth > 400 ? 30 : 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _filterButton(),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _sectionToggle(
                    label: "Ongoing",
                    isSelected: _showOngoing,
                    count: _ongoingOrders.length,
                    onTap: () => setState(() => _showOngoing = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sectionToggle(
                    label: "Past Orders",
                    isSelected: !_showOngoing,
                    count: _deliveredOrders.length,
                    onTap: () => setState(() => _showOngoing = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_showOngoing)
              _ordersSection(
                title: "Ongoing Orders",
                icon: Icons.local_shipping_outlined,
                orders: _ongoingOrders,
                emptyText: "You have no active orders",
              )
            else
              _ordersSection(
                title: "Delivered Orders",
                icon: Icons.check_circle_outline,
                orders: _deliveredOrders,
                emptyText: "No past orders found",
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _showFilterSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, color: primaryGreen, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _filterLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text("Filter orders", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _filterOptionTile("Last 3 months", "Show recent purchases", OrderFilterPreset.last3Months),
            _filterOptionTile("Last 6 months", "View older history", OrderFilterPreset.last6Months),
            _filterOptionTile("Custom Range", "Pick specific dates", OrderFilterPreset.custom, isCustom: true),
          ],
        ),
      ),
    );
  }

  Widget _filterOptionTile(String title, String subtitle, OrderFilterPreset preset, {bool isCustom = false}) {
    final bool selected = _filterPreset == preset;
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        if (isCustom) {
          _pickCustomDateRange();
        } else {
          setState(() => _filterPreset = preset);
        }
      },
      leading: CircleAvatar(
        backgroundColor: selected ? primaryGreen : Colors.green.shade50,
        child: Icon(selected ? Icons.check : Icons.calendar_month, color: selected ? Colors.white : primaryGreen, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: primaryGreen)),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _filterPreset = OrderFilterPreset.custom;
        _customStartDate = range.start;
        _customEndDate = range.end.add(const Duration(hours: 23, minutes: 59));
      });
    }
  }

  Widget _sectionToggle({required String label, required bool isSelected, required int count, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? primaryGreen : Colors.green.shade100, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: primaryGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))] : [],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.green.shade900, fontSize: 16, fontWeight: FontWeight.w900)),
            Text("$count orders", style: TextStyle(color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _ordersSection({required String title, required IconData icon, required List<CustomerOrder> orders, required String emptyText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: primaryGreen, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            if (!_showOngoing) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerReviewsScreen()),
                  );
                },
                icon: const Icon(Icons.star_outline, size: 16),
                label: const Text("See Reviews"),
                style: TextButton.styleFrom(
                  foregroundColor: primaryGreen,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          _emptyOrdersCard(emptyText)
        else
          ...orders.map((o) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _orderCard(o))),
      ],
    );
  }

  Widget _emptyOrdersCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
    );
  }

  Widget _orderCard(CustomerOrder order) {
    final statusColor = order.isDelivered ? primaryGreen : Colors.blueAccent;
    final firstItem = order.items.first;

    return GestureDetector(
      onTap: () => _showOrderDetail(order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    firstItem.imagePath, width: 52, height: 52, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(width: 52, height: 52, color: Colors.green.shade50, child: Icon(Icons.shopping_bag, color: primaryGreen)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.id, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      Text(order.retailerName, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                      if (!order.isDelivered && firstItem.tailorStatus != null) ...[
                        const SizedBox(height: 6),
                        _tailorStatusBadge(firstItem.tailorStatus!),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                  child: Text(order.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _orderInfo(Icons.shopping_bag_outlined, "${order.totalQuantity} Items"),
                const SizedBox(width: 10),
                _orderInfo(Icons.calendar_today_outlined, _formatDate(order.orderDate)),
                const Spacer(),
                Text("Tk ${order.amount.toInt()}", style: TextStyle(color: Colors.green.shade900, fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            if (!order.isDelivered && firstItem.tailorStatus != null)
              _buildNoticeableNote(firstItem.tailorStatus!),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeableNote(TailorStatus status) {
    if (status == TailorStatus.notAssigned || status == TailorStatus.cancelled) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade900, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.w600),
                  children: [
                    const TextSpan(text: "If you want to assign tailor "),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BrowseShell(initialIndex: 2)),
                          );
                        },
                        child: Text(
                          "browse tailor",
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (status == TailorStatus.pending) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.blue.shade900, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Tailor will respond within 24 hours. You can cancel manually before that.",
                style: TextStyle(color: Colors.blue.shade900, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _orderInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _showOrderDetail(CustomerOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Order Details", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("ID: ${order.id}", style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  ]),
                  _infoBadge(order.status, order.isDelivered ? primaryGreen.withValues(alpha: 0.1) : Colors.blueAccent.withValues(alpha: 0.1), order.isDelivered ? primaryGreen : Colors.blueAccent),
                ],
              ),
              const SizedBox(height: 25),
              const Text("Products", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...order.items.map((item) => _itemPreviewCard(item)),
              const SizedBox(height: 30),
              const Text("Order Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _detailRow("Retailer", order.retailerName),
              _detailRow("Total Items", "${order.totalQuantity} units"),
              _detailRow("Order Date", _formatDate(order.orderDate)),
              if (order.deliveryDate != null) _detailRow("Delivery Date", _formatDate(order.deliveryDate!)),
              const SizedBox(height: 20),
              const Text("Shipping Address", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.location_on_outlined, size: 16, color: primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.deliveryAddress, style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600))),
                ]),
              ),
              const Divider(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Grand Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text("Tk ${order.amount.toInt()}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                ],
              ),
              if (order.isDelivered && (order.review != null || order.tailorReview != null)) ...[
                const SizedBox(height: 35),
                const Text("Your Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (order.review != null) ...[
                  _reviewCard("Retailer Review", order.review!, order.rating ?? 0.0, Colors.blue),
                  const SizedBox(height: 12),
                ],
                if (order.tailorReview != null) ...[
                  _reviewCard("Tailor Review", order.tailorReview!, order.tailorRating ?? 0.0, Colors.orange),
                ],
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemPreviewCard(OrderItem item) {
    final bool sentToTailor = item.destination == OrderDeliveryDestination.tailor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  item.imagePath, width: 60, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.green.shade50, child: Icon(Icons.shopping_bag, color: primaryGreen)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("Qty: ${item.quantity} | Color: ${item.color}", style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: sentToTailor ? Colors.orange.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sentToTailor ? "Send to Tailor" : "Send to Retailer",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: sentToTailor ? Colors.orange.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                      if (item.tailorStatus != null)
                        _tailorStatusBadge(item.tailorStatus!),
                    ],
                  ),
                ]),
              ),
              Text("Tk ${item.price.toInt()}", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900)),
            ],
          ),
          if (item.tailorStatus != null) ...[
            if (item.tailorStatus == TailorStatus.pending)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, color: Colors.blue.shade900, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Tailor will accept or reject your request within 24 hours. You can manually cancel the request before then.",
                            style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Tailor request cancelled successfully.")),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade800,
                          elevation: 0,
                          side: BorderSide(color: Colors.red.shade100),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Cancel Tailor Request", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              )
            else if (item.tailorStatus == TailorStatus.notAssigned || item.tailorStatus == TailorStatus.cancelled)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade900, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                          children: [
                            const TextSpan(text: "If you want to assign tailor "),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context); // Close modal
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const BrowseShell(initialIndex: 2)),
                                  );
                                },
                                child: Text(
                                  "browse tailor",
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w900,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (sentToTailor) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              "Tailor Customization Details",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.measurementRefImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      item.measurementRefImage!,
                      width: 100,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 120,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Instructions:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.tailorInstructions ?? "No specific instructions provided.",
                        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showMeasurements,
                        icon: const Icon(Icons.straighten, size: 14),
                        label: const Text("View My Measurements", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: primaryGreen,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text("Care Instructions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _careTag(Icons.wash, "Wash", item.canWash),
              _careTag(Icons.biotech, "Bleach", item.canBleach),
              _careTag(Icons.dry_cleaning, "Dry Clean", item.canDryClean),
              _careTag(Icons.iron, "Iron: ${item.ironLevel}", true),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _careTag(IconData icon, String label, bool isOk) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isOk ? Colors.green.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(icon, size: 12, color: isOk ? Colors.green.shade700 : Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOk ? Colors.green.shade800 : Colors.grey)),
      ]),
    );
  }

  Widget _infoBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _reviewCard(String title, String review, double rating, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: themeColor.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w800),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: themeColor.withValues(alpha: 0.8), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    rating.toString(),
                    style: TextStyle(color: themeColor.withValues(alpha: 0.9), fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "\"$review\"",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }
}
