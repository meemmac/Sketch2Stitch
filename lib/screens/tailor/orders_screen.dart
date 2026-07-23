import 'package:flutter/material.dart';
import '../../../models/measurement.dart';
import 'reviews_screen.dart';

enum TailorOrderStatus { pending, confirmed, inProgress, ready, completed, cancelled }

class TailorOrderItem {
  final String name;
  final int quantity;
  final String imagePath;
  final String color;
  final String? measurementRefImage;
  final String? tailorInstructions;
  double servicePrice;
  DateTime? estimatedDeliveryDate;

  TailorOrderItem({
    required this.name,
    required this.quantity,
    required this.imagePath,
    required this.color,
    required this.servicePrice,
    this.measurementRefImage,
    this.tailorInstructions,
    this.estimatedDeliveryDate,
  });
}

class TailorOrder {
  final String id;
  final String customerName;
  final List<TailorOrderItem> items;
  final double totalAmount;
  final DateTime orderDate;
  DateTime? completionDate;
  TailorOrderStatus status;
  bool isCompleted;
  final String? customerReview;
  final double? customerRating;
  final String deliveryAddress;

  TailorOrder({
    required this.id,
    required this.customerName,
    required this.items,
    required this.totalAmount,
    required this.orderDate,
    required this.status,
    required this.isCompleted,
    required this.deliveryAddress,
    this.completionDate,
    this.customerReview,
    this.customerRating,
  });

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}

enum OrderFilterPreset { last3Months, last6Months, custom }

class TailorOrdersScreen extends StatefulWidget {
  const TailorOrdersScreen({super.key});

  @override
  State<TailorOrdersScreen> createState() => _TailorOrdersScreenState();
}

class _TailorOrdersScreenState extends State<TailorOrdersScreen> {
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

  late final List<TailorOrder> _orders = [
    TailorOrder(
      id: "T-ORD-1122",
      customerName: "Maria Doe",
      totalAmount: 1500,
      orderDate: DateTime.now().subtract(const Duration(days: 1)),
      status: TailorOrderStatus.pending,
      isCompleted: false,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      items: [
        TailorOrderItem(
          name: "Premium Linen Kurti",
          quantity: 1,
          imagePath: "assets/images/fabrics_rolled.jpg",
          color: "Cream",
          servicePrice: 1500,
          measurementRefImage: "assets/images/ref1.jpg",
          tailorInstructions: "Please ensure the length is precisely 42 inches. Follow the reference image for sleeve design.",
        ),
      ],
    ),
    TailorOrder(
      id: "T-ORD-1120",
      customerName: "Maria Doe",
      totalAmount: 3200,
      orderDate: DateTime.now().subtract(const Duration(days: 3)),
      status: TailorOrderStatus.inProgress,
      isCompleted: false,
      deliveryAddress: "House 12, Road 5, Dhanmondi, Dhaka",
      items: [
        TailorOrderItem(
          name: "Printed Voile Summer Dress",
          quantity: 2,
          imagePath: "assets/images/gorgeous.jpg",
          color: "Floral Blue",
          servicePrice: 1600,
          measurementRefImage: "assets/images/ref2.jpg",
          tailorInstructions: "Use the printed patterns for the sleeves as shown in the reference picture.",
        ),
      ],
    ),
    TailorOrder(
      id: "T-ORD-1090",
      customerName: "Nishat Tasnim",
      totalAmount: 4000,
      orderDate: DateTime.now().subtract(const Duration(days: 65)),
      completionDate: DateTime.now().subtract(const Duration(days: 60)),
      status: TailorOrderStatus.completed,
      isCompleted: true,
      deliveryAddress: "Banani, Dhaka",
      customerReview: "Best tailor experience ever. The fit is top-notch.",
      customerRating: 5.0,
      items: [
        TailorOrderItem(
          name: "Banarasi Silk Lehenga Blouse",
          quantity: 1,
          imagePath: "assets/images/silk.jpg",
          color: "Magenta",
          servicePrice: 4000,
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

  List<TailorOrder> get _filteredOrders {
    return _orders.where((order) {
      final date = order.orderDate;
      return !date.isBefore(_startDate) && !date.isAfter(_endDate);
    }).toList();
  }

  List<TailorOrder> get _ongoingOrders => _filteredOrders.where((o) => !o.isCompleted).toList();
  List<TailorOrder> get _deliveredOrders => _filteredOrders.where((o) => o.isCompleted).toList();

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
                    "Tailoring Orders",
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
                    label: "Current Work",
                    isSelected: _showOngoing,
                    count: _ongoingOrders.length,
                    onTap: () => setState(() => _showOngoing = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sectionToggle(
                    label: "Completed",
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
                title: "Active Orders",
                icon: Icons.assignment_outlined,
                orders: _ongoingOrders,
                emptyText: "No active tailoring requests",
              )
            else
              _ordersSection(
                title: "Finished Work",
                icon: Icons.task_alt,
                orders: _deliveredOrders,
                emptyText: "No completed orders found",
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
            Center(child: Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const Text("Filter by date", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _filterOptionTile("Last 3 months", _filterPreset == OrderFilterPreset.last3Months, () {
              setState(() => _filterPreset = OrderFilterPreset.last3Months);
              Navigator.pop(context);
            }),
            _filterOptionTile("Last 6 months", _filterPreset == OrderFilterPreset.last6Months, () {
              setState(() => _filterPreset = OrderFilterPreset.last6Months);
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _filterOptionTile(String title, bool selected, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: primaryGreen),
      title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _sectionToggle({required String label, required bool isSelected, required int count, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? primaryGreen : Colors.green.shade100, width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.green.shade900, fontSize: 16, fontWeight: FontWeight.w900)),
            Text("$count orders", style: TextStyle(color: isSelected ? Colors.white70 : Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _ordersSection({required String title, required IconData icon, required List<TailorOrder> orders, required String emptyText}) {
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
                    MaterialPageRoute(builder: (_) => const TailorReviewsScreen()),
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

  Widget _orderCard(TailorOrder order) {
    final statusColor = _getStatusColor(order.status);
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
                    errorBuilder: (context, error, stackTrace) => Container(width: 52, height: 52, color: Colors.green.shade50, child: Icon(Icons.content_cut, color: primaryGreen)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.id, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      Text("Customer: ${order.customerName}", style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                  child: Text(_getStatusText(order.status), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900)),
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
                Text("Tk ${order.totalAmount.toInt()}", style: TextStyle(color: Colors.green.shade900, fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
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

  void _showOrderDetail(TailorOrder order) {
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
                    const Text("Stitching Details", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("ID: ${order.id}", style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  ]),
                  _infoBadge(_getStatusText(order.status), _getStatusColor(order.status).withValues(alpha: 0.1), _getStatusColor(order.status)),
                ],
              ),
              const SizedBox(height: 25),
              if (order.status == TailorOrderStatus.pending)
                _buildActionButtons(order),
              const SizedBox(height: 20),
              const Text("Customer Requirements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...order.items.map((item) => _itemPreviewCard(order, item)),
              const SizedBox(height: 30),
              const Text("Job Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _detailRow("Customer", order.customerName),
              _detailRow("Items to Stitch", "${order.totalQuantity} units"),
              _detailRow("Request Date", _formatDate(order.orderDate)),
              if (order.completionDate != null) _detailRow("Completed On", _formatDate(order.completionDate!)),
              const SizedBox(height: 20),
              const Text("Customer Location", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
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
                  const Text("Service Earnings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text("Tk ${order.totalAmount.toInt()}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                ],
              ),
              if (order.isCompleted && order.customerReview != null) ...[
                const SizedBox(height: 35),
                const Text("Customer Feedback", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _reviewCard(order),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(TailorOrder order) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() => order.status = TailorOrderStatus.confirmed);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Job Accepted Successfully!")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Accept Job", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() => order.status = TailorOrderStatus.cancelled);
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Decline Job", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _itemPreviewCard(TailorOrder order, TailorOrderItem item) {
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
                  errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.green.shade50, child: Icon(Icons.content_cut, color: primaryGreen)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("Qty: ${item.quantity} | Color: ${item.color}", style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              Text("Tk ${item.servicePrice.toInt()}", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900)),
            ],
          ),
          if (order.status == TailorOrderStatus.pending) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text("Set Your Quote", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Stitching Price (Tk)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                      const SizedBox(height: 6),
                      TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "e.g. 1500",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() {
                            item.servicePrice = double.tryParse(val) ?? item.servicePrice;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Est. Delivery Date", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              item.estimatedDeliveryDate = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                item.estimatedDeliveryDate != null ? _formatDate(item.estimatedDeliveryDate!) : "Select Date",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text("Stitching Instructions & Ref", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.measurementRefImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item.measurementRefImage!, width: 100, height: 120, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 100, height: 120, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Client Instructions:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(item.tailorInstructions ?? "No specific instructions provided.", style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showMeasurements,
                      icon: const Icon(Icons.straighten, size: 14),
                      label: const Text("View Customer Measurements", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: primaryGreen, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMeasurements() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const Text("Customer Measurements", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Precision measurements provided by the customer.", style: TextStyle(color: Colors.black54, fontSize: 13)),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)),
            child: Text("$value in", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(TailorOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.blue.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ...List.generate(5, (index) => Icon(index < (order.customerRating ?? 0).floor() ? Icons.star : Icons.star_border, color: Colors.blue.shade800, size: 20)),
          const SizedBox(width: 8),
          Text(order.customerRating?.toString() ?? "0.0", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
        const SizedBox(height: 10),
        Text("\"${order.customerReview}\"", style: TextStyle(color: Colors.blue.shade900, fontSize: 14, fontStyle: FontStyle.italic, height: 1.4, fontWeight: FontWeight.w600)),
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

  String _getStatusText(TailorOrderStatus status) {
    switch (status) {
      case TailorOrderStatus.pending: return "New Request";
      case TailorOrderStatus.confirmed: return "Accepted";
      case TailorOrderStatus.inProgress: return "Stitching";
      case TailorOrderStatus.ready: return "Ready";
      case TailorOrderStatus.completed: return "Finished";
      case TailorOrderStatus.cancelled: return "Declined";
    }
  }

  Color _getStatusColor(TailorOrderStatus status) {
    switch (status) {
      case TailorOrderStatus.pending: return Colors.orange;
      case TailorOrderStatus.confirmed: return Colors.blue;
      case TailorOrderStatus.inProgress: return Colors.purple;
      case TailorOrderStatus.ready: return Colors.teal;
      case TailorOrderStatus.completed: return primaryGreen;
      case TailorOrderStatus.cancelled: return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }
}
